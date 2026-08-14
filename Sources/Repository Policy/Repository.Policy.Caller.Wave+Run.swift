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
        if oldBlob == newBlob {
            let receipt = Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: oldHead,
                oldBlob: oldBlob,
                newBlob: oldBlob,
                changed: false,
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
                    bypassClosed: true
                ),
                through: record
            )
            return receipt
        }

        let references = try await calling { try await client.rulesets(request.repository) }
            .filter { $0.name == "Institute protected main" }
        guard references.count == 1, let reference = references.first else {
            throw .ruleset(
                "\(request.repository): expected one Institute protected main ruleset, found \(references.count)"
            )
        }
        let liveRuleset = try await calling {
            try await client.ruleset(request.repository, id: reference.id)
        }
        let snapshot = try RulesetSnapshot(
            repository: request.repository,
            id: reference.id,
            live: liveRuleset,
            canonical: request.canonicalRuleset,
            integrationID: request.integrationID
        )
        do {
            try preserve(
                Recovery(
                    repository: request.repository,
                    rollbackHead: oldHead,
                    caller: oldCaller,
                    ruleset: snapshot
                )
            )
        } catch {
            throw .journal("\(request.repository): could not preserve recovery payload: \(error)")
        }
        try recording(
            Event(
                phase: "window-opening",
                repository: request.repository,
                oldHead: oldHead,
                oldBlob: oldBlob,
                ruleset: reference.id
            ),
            through: record
        )

        try await calling {
            try await client.replaceRuleset(
                request.repository,
                id: reference.id,
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
                    ruleset: reference.id,
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
                changed: true,
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
