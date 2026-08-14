import Foundation
import Repository_Policy
import Testing

@Suite
struct RepositoryPolicyCallerWaveTests {
    @Test
    func enumeratesEveryActiveOrganizationIntoOneSortedPopulation() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        let population = try await Repository.Policy.Caller.Wave.enumerate(
            client: client,
            fleet: try fleet(organizations: ["swift-standards", "swift-primitives"])
        )

        #expect(population.organizations == ["swift-primitives", "swift-standards"])
        #expect(population.examined == 2)
        #expect(
            population.subjects.map(\.repository)
                == ["swift-primitives/example", "swift-standards/example"]
        )
    }

    @Test
    func emptyOrganizationEnumerationRefusesThePopulation() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(
            ruleset: canonical,
            emptyRepositories: true
        )

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    @Test
    func missingCallerRefusesThePopulation() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(
            ruleset: canonical,
            callerAbsent: true
        )

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    @Test
    func recensusAcceptsOnlyByteIdenticalCallers() {
        let population = Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            excluded: [:],
            subjects: [
                .init(
                    repository: "swift-primitives/a",
                    head: "head-a",
                    caller: .init(blob: "blob-a", bytes: Data("terminal\n".utf8))
                ),
                .init(
                    repository: "swift-primitives/b",
                    head: "head-b",
                    caller: .init(blob: "blob-b", bytes: Data("terminal\n".utf8))
                ),
            ]
        )

        let receipt = Repository.Policy.Caller.Wave.recensus(
            population: population,
            caller: Data("terminal\n".utf8)
        )
        let matches = receipt.observations.map(\.matches)

        #expect(receipt.accepted)
        #expect(receipt.observations.count == 2)
        #expect(matches == [true, true])
        #expect(receipt.observations.map(\.digest) == [receipt.canonicalDigest, receipt.canonicalDigest])
    }

    @Test
    func recensusRecordsAndRefusesEveryDivergentCaller() {
        let population = Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            excluded: [:],
            subjects: [
                .init(
                    repository: "swift-primitives/a",
                    head: "head-a",
                    caller: .init(blob: "blob-a", bytes: Data("terminal\n".utf8))
                ),
                .init(
                    repository: "swift-primitives/b",
                    head: "head-b",
                    caller: .init(blob: "blob-b", bytes: Data("legacy\n".utf8))
                ),
            ]
        )

        let receipt = Repository.Policy.Caller.Wave.recensus(
            population: population,
            caller: Data("terminal\n".utf8)
        )

        #expect(!receipt.accepted)
        #expect(receipt.observations.filter { !$0.matches }.map(\.repository) == ["swift-primitives/b"])
        #expect(receipt.observations[1].digest != receipt.canonicalDigest)
    }

    @Test
    func recensusRefusesAnEmptyPopulation() {
        let population = Repository.Policy.Caller.Wave.Population(
            organizations: [],
            examined: 0,
            excluded: [:],
            subjects: []
        )

        let receipt = Repository.Policy.Caller.Wave.recensus(
            population: population,
            caller: Data("terminal\n".utf8)
        )

        #expect(!receipt.accepted)
        #expect(receipt.observations.isEmpty)
    }

    @Test
    func appliesForwardCommitAndRestoresRuleset() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        var recovery: Repository.Policy.Caller.Wave.Recovery?
        var events: [Repository.Policy.Caller.Wave.Event] = []
        let receipt = try await Repository.Policy.Caller.Wave.run(
            client: client,
            request: request(canonical: canonical),
            preserve: { recovery = $0 },
            record: { events.append($0) }
        )

        #expect(receipt.changed)
        #expect(receipt.callerChanged)
        #expect(!receipt.rulesetChanged)
        #expect(receipt.oldHead == "old-head")
        #expect(receipt.newHead == "new-head")
        #expect(receipt.bypassClosed)
        #expect(recovery?.caller.bytes == Data("old\n".utf8))
        #expect(recovery?.rollbackHead == "old-head")
        #expect(recovery?.ruleset?.id == 7)
        #expect(events.map(\.phase) == ["window-opening", "applied"])
        #expect(await client.replacements() == 2)
    }

    @Test
    func createsMissingRulesetEvenWhenCallerIsAlreadyTerminal() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(
            ruleset: canonical,
            rulesetAbsent: true
        )
        await client.setCaller(bytes: Data("new\n".utf8), blob: "new-blob")
        var recovery: Repository.Policy.Caller.Wave.Recovery?
        var events: [Repository.Policy.Caller.Wave.Event] = []

        let receipt = try await Repository.Policy.Caller.Wave.run(
            client: client,
            request: request(canonical: canonical, expectedBlob: "new-blob"),
            preserve: { recovery = $0 },
            record: { events.append($0) }
        )

        #expect(receipt.changed)
        #expect(!receipt.callerChanged)
        #expect(receipt.rulesetChanged)
        #expect(receipt.newHead == "old-head")
        #expect(recovery?.priorRuleset == nil)
        #expect(recovery?.ruleset?.id == 7)
        #expect(events.map(\.phase) == ["ruleset-converged", "already-terminal"])
        #expect(await client.creations() == 1)
        #expect(await client.replacements() == 0)
    }

    @Test
    func movedHeadRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        await client.setHead("other-head")

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func movedBlobRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        await client.setBlob("other-blob")

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func noncanonicalRulesetConvergesBeforeWindow() async throws {
        let canonical = try ruleset()
        let divergent = try ruleset(enforcement: "disabled")
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: divergent)
        var recovery: Repository.Policy.Caller.Wave.Recovery?
        var events: [Repository.Policy.Caller.Wave.Event] = []

        let receipt = try await Repository.Policy.Caller.Wave.run(
            client: client,
            request: request(canonical: canonical),
            preserve: { recovery = $0 },
            record: { events.append($0) }
        )
        let divergentNormalized = try Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            divergent
        )
        let canonicalNormalized = try Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            canonical
        )

        #expect(receipt.callerChanged)
        #expect(receipt.rulesetChanged)
        #expect(recovery?.priorRuleset?.restore == divergentNormalized)
        #expect(recovery?.ruleset?.restore == canonicalNormalized)
        #expect(events.map(\.phase) == ["ruleset-converged", "window-opening", "applied"])
        #expect(await client.replacements() == 3)
    }

    @Test
    func failedRulesetConvergenceRestoresThePriorContract() async throws {
        let canonical = try ruleset()
        let divergent = try ruleset(enforcement: "disabled")
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: divergent)
        await client.setConvergenceFailure()

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }

        let restored = try await client.ruleset("swift-institute/example", id: 7)
        let restoredNormalized = try Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            restored
        )
        let divergentNormalized = try Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            divergent
        )
        #expect(await client.replacements() == 1)
        #expect(restoredNormalized == divergentNormalized)
    }

    @Test
    func failedMoveRestoresRuleset() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        await client.setMoveFailure()

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 2)
    }

    @Test
    func concurrentHeadMovementInsideWindowRefusesAndRestores() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        await client.setMoveHeadOnOpen()

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 2)
    }

    @Test
    func failedRestorationSurfacesCombinedFailure() async throws {
        let canonical = try ruleset()
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: canonical)
        await client.setMoveFailure()
        await client.setRestorationFailure()

        await #expect(throws: Repository.Policy.Caller.Wave.Error.self) {
            try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: request(canonical: canonical),
                preserve: { _ in },
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 1)
    }

    private func request(
        canonical: Data,
        expectedBlob: String = "old-blob"
    ) -> Repository.Policy.Caller.Wave.Request {
        .init(
            repository: "swift-institute/example",
            expectedHead: "old-head",
            expectedBlob: expectedBlob,
            caller: Data("new\n".utf8),
            canonicalRuleset: canonical,
            integrationID: 3_543_256,
            commitMessage: "Adopt terminal caller [skip ci]"
        )
    }

    private func ruleset(enforcement: String = "active") throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "name": "Institute protected main",
                "target": "branch",
                "enforcement": enforcement,
                "bypass_actors": [],
                "conditions": [
                    "ref_name": ["include": ["refs/heads/main"], "exclude": []]
                ],
                "rules": [
                    ["type": "deletion"],
                    ["type": "non_fast_forward"],
                    ["type": "pull_request", "parameters": ["required_approving_review_count": 1]],
                    [
                        "type": "required_status_checks",
                        "parameters": [
                            "required_status_checks": [["context": "ci / matrix / ci-ok"]]
                        ],
                    ],
                ],
            ],
            options: [.sortedKeys]
        )
    }

    private func fleet(organizations: [String]) throws -> RepositoryPolicy.Fleet {
        let values = organizations.map {
            ["name": $0, "layer": "L1", "status": "active"]
        }
        return try JSONDecoder().decode(
            RepositoryPolicy.Fleet.self,
            from: JSONSerialization.data(
                withJSONObject: ["schemaVersion": 1, "organizations": values]
            )
        )
    }
}
