import Foundation

extension Repository.Policy.Caller.Wave {
    public static func run<C: Client>(
        client: C,
        request: Request,
        preserve: (Recovery) throws -> Void,
        record: (Event) throws -> Void
    ) async throws(Error) -> Receipt {
        let repository = try await calling { try await client.waveRepository(request.repository) }
        guard repository.visibility == "public", !repository.archived, !repository.disabled,
            repository.defaultBranch == "main"
        else {
            throw .invalidRepository("\(request.repository): not an active public main repository")
        }

        let oldHead = try await guardedHead(client: client, request: request)
        let oldCaller = try await guardedCaller(client: client, request: request, head: oldHead)
        let oldBlob = oldCaller.blob
        let newBlob = try await calling {
            try await client.createBlob(request.repository, content: request.caller)
        }
        let prepared = try await prepareRuleset(
            client: client,
            request: request,
            oldHead: oldHead,
            oldCaller: oldCaller,
            preserve: preserve
        )
        if prepared.changed {
            try recording(
                Event(
                    phase: "ruleset-converged",
                    repository: request.repository,
                    oldHead: oldHead,
                    oldBlob: oldBlob,
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
        }
        if oldBlob == newBlob {
            let receipt = Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: oldHead,
                oldBlob: oldBlob,
                newBlob: oldBlob,
                ruleset: prepared.snapshot.id,
                callerChanged: false,
                rulesetChanged: prepared.changed,
                bypassClosed: true
            )
            try recording(
                Event(
                    phase: "already-terminal",
                    repository: request.repository,
                    oldHead: oldHead,
                    newHead: oldHead,
                    oldBlob: oldBlob,
                    newBlob: oldBlob,
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return receipt
        }

        let snapshot = prepared.snapshot
        try recording(
            Event(
                phase: "window-opening",
                repository: request.repository,
                oldHead: oldHead,
                oldBlob: oldBlob,
                ruleset: snapshot.id
            ),
            through: record
        )

        try await calling {
            try await client.replaceRuleset(
                request.repository,
                id: snapshot.id,
                payload: snapshot.opened
            )
        }
        do {
            try await verifyRuleset(client: client, snapshot: snapshot, opened: true)
            _ = try await guardedHead(client: client, request: request)
            _ = try await guardedCaller(client: client, request: request, head: oldHead)
            let candidateHead = try await calling {
                try await client.createCommit(
                    request.repository,
                    parent: oldHead,
                    blob: newBlob,
                    message: request.commitMessage
                )
            }
            _ = try await guardedHead(client: client, request: request)
            try await calling {
                try await client.moveMain(request.repository, to: candidateHead)
            }
            let verifiedHead = try await calling { try await client.head(request.repository) }
            guard verifiedHead == candidateHead else {
                throw Error.verification(
                    "\(request.repository): main did not move to created commit \(candidateHead)"
                )
            }
            let verifiedCaller = try await calling {
                try await client.callerSource(request.repository, head: verifiedHead)
            }
            guard verifiedCaller.blob == newBlob, verifiedCaller.bytes == request.caller else {
                throw Error.verification(
                    "\(request.repository): terminal caller bytes did not verify after commit"
                )
            }
            try await restore(client: client, snapshot: snapshot)
            try recording(
                Event(
                    phase: "applied",
                    repository: request.repository,
                    oldHead: oldHead,
                    newHead: verifiedHead,
                    oldBlob: oldBlob,
                    newBlob: verifiedCaller.blob,
                    ruleset: snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: verifiedHead,
                oldBlob: oldBlob,
                newBlob: verifiedCaller.blob,
                ruleset: snapshot.id,
                callerChanged: true,
                rulesetChanged: prepared.changed,
                bypassClosed: true
            )
        } catch let primary as Error {
            do {
                try await restore(client: client, snapshot: snapshot)
            } catch let restoreError {
                throw .restoration(
                    primary: primary.description,
                    restore: restoreError.description
                )
            }
            throw primary
        } catch {
            do {
                try await restore(client: client, snapshot: snapshot)
            } catch let restoreError {
                throw .restoration(
                    primary: String(describing: error),
                    restore: restoreError.description
                )
            }
            throw .verification(String(describing: error))
        }
    }

    public static func restore<C: Client>(
        client: C,
        snapshot: RulesetSnapshot
    ) async throws(Error) {
        try await calling {
            try await client.replaceRuleset(
                snapshot.repository,
                id: snapshot.id,
                payload: snapshot.restore
            )
        }
        try await verifyRuleset(client: client, snapshot: snapshot, opened: false)
    }

    private static func prepareRuleset<C: Client>(
        client: C,
        request: Request,
        oldHead: String,
        oldCaller: CallerSource,
        preserve: (Recovery) throws -> Void
    ) async throws(Error) -> PreparedRuleset {
        let references = try await calling { try await client.rulesets(request.repository) }
            .filter { $0.name == "Institute protected main" }
        guard references.count <= 1 else {
            throw .ruleset(
                "\(request.repository): found \(references.count) Institute protected main rulesets"
            )
        }
        guard let reference = references.first else {
            try preserving(
                Recovery(
                    repository: request.repository,
                    rollbackHead: oldHead,
                    caller: oldCaller,
                    priorRuleset: nil,
                    ruleset: nil
                ),
                through: preserve
            )
            let id = try await calling {
                try await client.createRuleset(
                    request.repository,
                    payload: request.canonicalRuleset
                )
            }
            let live = try await calling {
                try await client.ruleset(request.repository, id: id)
            }
            let snapshot = try RulesetSnapshot(
                repository: request.repository,
                id: id,
                live: live,
                canonical: request.canonicalRuleset,
                integrationID: request.integrationID
            )
            try preserving(
                Recovery(
                    repository: request.repository,
                    rollbackHead: oldHead,
                    caller: oldCaller,
                    priorRuleset: nil,
                    ruleset: snapshot
                ),
                through: preserve
            )
            return PreparedRuleset(snapshot: snapshot, changed: true)
        }

        let live = try await calling {
            try await client.ruleset(request.repository, id: reference.id)
        }
        let prior = try RulesetSnapshot(
            repository: request.repository,
            id: reference.id,
            live: live,
            canonical: live,
            integrationID: request.integrationID
        )
        try preserving(
            Recovery(
                repository: request.repository,
                rollbackHead: oldHead,
                caller: oldCaller,
                priorRuleset: prior,
                ruleset: prior
            ),
            through: preserve
        )
        let canonical = try RulesetSnapshot.normalized(request.canonicalRuleset)
        guard prior.restore != canonical else {
            return PreparedRuleset(snapshot: prior, changed: false)
        }

        do {
            try await calling {
                try await client.replaceRuleset(
                    request.repository,
                    id: reference.id,
                    payload: request.canonicalRuleset
                )
            }
            let readback = try await calling {
                try await client.ruleset(request.repository, id: reference.id)
            }
            let snapshot = try RulesetSnapshot(
                repository: request.repository,
                id: reference.id,
                live: readback,
                canonical: request.canonicalRuleset,
                integrationID: request.integrationID
            )
            try preserving(
                Recovery(
                    repository: request.repository,
                    rollbackHead: oldHead,
                    caller: oldCaller,
                    priorRuleset: prior,
                    ruleset: snapshot
                ),
                through: preserve
            )
            return PreparedRuleset(snapshot: snapshot, changed: true)
        } catch let primary {
            do {
                try await restore(client: client, snapshot: prior)
            } catch let restoreError {
                throw .restoration(
                    primary: primary.description,
                    restore: restoreError.description
                )
            }
            throw primary
        }
    }

    private static func verifyRuleset<C: Client>(
        client: C,
        snapshot: RulesetSnapshot,
        opened: Bool
    ) async throws(Error) {
        let readback = try await calling {
            try await client.ruleset(snapshot.repository, id: snapshot.id)
        }
        let valid = opened ? snapshot.verifiesOpened(readback) : snapshot.verifiesClosed(readback)
        guard valid else {
            throw .ruleset(
                "\(snapshot.repository): ruleset \(opened ? "window" : "restoration") did not verify"
            )
        }
    }

    private static func guardedHead<C: Client>(
        client: C,
        request: Request
    ) async throws(Error) -> String {
        let actual = try await calling { try await client.head(request.repository) }
        guard actual == request.expectedHead else {
            throw .movedHead(
                repository: request.repository,
                expected: request.expectedHead,
                actual: actual
            )
        }
        return actual
    }

    private static func guardedCaller<C: Client>(
        client: C,
        request: Request,
        head: String
    ) async throws(Error) -> CallerSource {
        let actual = try await calling {
            try await client.callerSource(request.repository, head: head)
        }
        guard actual.blob == request.expectedBlob else {
            throw .movedBlob(
                repository: request.repository,
                expected: request.expectedBlob,
                actual: actual.blob
            )
        }
        return actual
    }

    private static func recording(
        _ event: Event,
        through record: (Event) throws -> Void
    ) throws(Error) {
        do {
            try record(event)
        } catch {
            throw .journal("\(event.repository): could not append \(event.phase): \(error)")
        }
    }

    private static func preserving(
        _ recovery: Recovery,
        through preserve: (Recovery) throws -> Void
    ) throws(Error) {
        do {
            try preserve(recovery)
        } catch {
            throw .journal("\(recovery.repository): could not preserve recovery payload: \(error)")
        }
    }

    static func calling<T>(
        _ body: () async throws -> T
    ) async throws(Error) -> T {
        do {
            return try await body()
        } catch let error as RepositoryPolicy.GitHubClient.Error {
            throw .client(error)
        } catch {
            throw .verification("unexpected client refusal: \(error)")
        }
    }
}
