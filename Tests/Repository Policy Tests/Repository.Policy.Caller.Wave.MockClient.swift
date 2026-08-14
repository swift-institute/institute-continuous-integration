import Foundation
import Repository_Policy

actor RepositoryPolicyCallerWaveMockClient: Repository.Policy.Caller.Wave.Client {
    var repository = Repository.Policy.Caller.Wave.Repository(
        visibility: "public",
        archived: false,
        disabled: false,
        defaultBranch: "main"
    )
    var currentHead = "old-head"
    var oldCaller = Data("old\n".utf8)
    var newCaller = Data("new\n".utf8)
    var oldBlob = "old-blob"
    var newBlob = "new-blob"
    var rulesetData: Data
    var rulesetID: Int64?
    var replacementCount = 0
    var creationCount = 0
    var moveFailure = false
    var restorationFailure = false
    var convergenceFailure = false
    var moveHeadOnOpen = false
    let emptyRepositories: Bool
    let callerAbsent: Bool

    init(
        ruleset: Data,
        emptyRepositories: Bool = false,
        callerAbsent: Bool = false,
        rulesetAbsent: Bool = false
    ) {
        rulesetData = ruleset
        rulesetID = rulesetAbsent ? nil : 7
        self.emptyRepositories = emptyRepositories
        self.callerAbsent = callerAbsent
    }

    func repositories(
        organization: String
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> [RepositoryPolicy.Repository] {
        if emptyRepositories { return [] }
        return [
            .init(
                id: 1,
                name: "example",
                fullName: "\(organization)/example",
                visibility: "public",
                archived: false,
                disabled: false,
                fork: false,
                size: 1
            )
        ]
    }

    func rootManifestKind(
        _: String
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> String? {
        "file"
    }

    func waveRepository(
        _: String
    ) async throws(RepositoryPolicy.GitHubClient.Error)
        -> Repository.Policy.Caller.Wave.Repository
    {
        repository
    }

    func head(_: String) async throws(RepositoryPolicy.GitHubClient.Error) -> String {
        currentHead
    }

    func callerSource(
        _: String,
        head: String
    ) async throws(RepositoryPolicy.GitHubClient.Error)
        -> Repository.Policy.Caller.Wave.CallerSource
    {
        head == "new-head"
            ? .init(blob: newBlob, bytes: newCaller)
            : .init(blob: oldBlob, bytes: oldCaller)
    }

    func callerSourceIfPresent(
        _ repository: String,
        head: String
    ) async throws(RepositoryPolicy.GitHubClient.Error)
        -> Repository.Policy.Caller.Wave.CallerSource?
    {
        if callerAbsent { return nil }
        return try await callerSource(repository, head: head)
    }

    func rulesets(
        _: String
    ) async throws(RepositoryPolicy.GitHubClient.Error)
        -> [Repository.Policy.Caller.Wave.RulesetReference]
    {
        rulesetID.map { [.init(id: $0, name: "Institute protected main")] } ?? []
    }

    func ruleset(
        _: String,
        id _: Int64
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> Data {
        rulesetData
    }

    func replaceRuleset(
        _: String,
        id _: Int64,
        payload: Data
    ) async throws(RepositoryPolicy.GitHubClient.Error) {
        let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        let bypass = object?["bypass_actors"] as? [Any] ?? []
        if bypass.isEmpty, convergenceFailure {
            convergenceFailure = false
            throw .precondition("convergence failed")
        }
        if bypass.isEmpty, restorationFailure {
            throw .precondition("restore failed")
        }
        if !bypass.isEmpty, moveHeadOnOpen {
            currentHead = "concurrent-head"
        }
        rulesetData = payload
        replacementCount += 1
    }

    func createRuleset(
        _: String,
        payload: Data
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> Int64 {
        guard rulesetID == nil else {
            throw .precondition("ruleset already exists")
        }
        rulesetID = 7
        rulesetData = payload
        creationCount += 1
        return 7
    }

    func createBlob(
        _: String,
        content: Data
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> String {
        newCaller = content
        return newBlob
    }

    func createCommit(
        _: String,
        parent _: String,
        blob _: String,
        message _: String
    ) async throws(RepositoryPolicy.GitHubClient.Error) -> String {
        "new-head"
    }

    func moveMain(
        _: String,
        to head: String
    ) async throws(RepositoryPolicy.GitHubClient.Error) {
        if moveFailure {
            throw .precondition("move failed")
        }
        currentHead = head
    }

    func setHead(_ value: String) {
        currentHead = value
    }

    func setBlob(_ value: String) {
        oldBlob = value
    }

    func setCaller(bytes: Data, blob: String) {
        oldCaller = bytes
        oldBlob = blob
    }

    func setMoveFailure() {
        moveFailure = true
    }

    func setRestorationFailure() {
        restorationFailure = true
    }

    func setConvergenceFailure() {
        convergenceFailure = true
    }

    func setMoveHeadOnOpen() {
        moveHeadOnOpen = true
    }

    func replacements() -> Int {
        replacementCount
    }

    func creations() -> Int {
        creationCount
    }
}
