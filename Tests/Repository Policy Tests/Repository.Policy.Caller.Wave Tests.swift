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
        #expect(receipt.oldHead == "old-head")
        #expect(receipt.newHead == "new-head")
        #expect(receipt.bypassClosed)
        #expect(recovery?.caller.bytes == Data("old\n".utf8))
        #expect(recovery?.rollbackHead == "old-head")
        #expect(events.map(\.phase) == ["window-opening", "applied"])
        #expect(await client.replacements() == 2)
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
    func noncanonicalRulesetRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let divergent = try ruleset(enforcement: "disabled")
        let client = RepositoryPolicyCallerWaveMockClient(ruleset: divergent)

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

    private func request(canonical: Data) -> Repository.Policy.Caller.Wave.Request {
        .init(
            repository: "swift-institute/example",
            expectedHead: "old-head",
            expectedBlob: "old-blob",
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
