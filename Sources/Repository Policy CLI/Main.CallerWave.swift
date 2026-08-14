import Foundation
import Repository_Policy

extension Main {
    static func callerWave(_ arguments: [String]) async throws(Error) {
        guard let operation = arguments.first else {
            throw .configuration(
                RepositoryPolicy.ConfigurationError("caller-wave requires apply or restore")
            )
        }
        let values = try callerWaveValues(Array(arguments.dropFirst()))
        let client = try callerWaveClient()
        switch operation {
        case "census":
            guard values.count == 2,
                let fleetPath = values["--fleet"],
                let output = values["--output"]
            else {
                throw .configuration(
                    RepositoryPolicy.ConfigurationError(
                        "caller-wave census requires --fleet <policy> --output <path>"
                    )
                )
            }
            let fleet: RepositoryPolicy.Fleet
            do {
                fleet = try RepositoryPolicy.Fleet.read(at: fleetPath)
            } catch {
                throw .io("could not read caller-wave fleet policy at \(fleetPath): \(error)")
            }
            let population: Repository.Policy.Caller.Wave.Population
            do throws(Repository.Policy.Caller.Wave.Error) {
                population = try await Repository.Policy.Caller.Wave.enumerate(
                    client: client,
                    fleet: fleet
                )
            } catch {
                throw .wave(error)
            }
            do {
                try encode(population, to: URL(filePath: output))
            } catch {
                throw .io("could not write caller-wave census at \(output): \(error)")
            }
            print(
                "repository-policy: caller-wave census examined=\(population.examined) "
                    + "eligible=\(population.subjects.count)"
            )

        case "apply":
            try await applyCallerWave(values, client: client)

        case "restore":
            guard values.count == 1, let recovery = values["--recovery"] else {
                throw .configuration(
                    RepositoryPolicy.ConfigurationError(
                        "caller-wave restore requires only --recovery <path>"
                    )
                )
            }
            let snapshot: Repository.Policy.Caller.Wave.Recovery = try decode(
                at: recovery,
                label: "caller-wave recovery"
            )
            do throws(Repository.Policy.Caller.Wave.Error) {
                try await Repository.Policy.Caller.Wave.restore(
                    client: client,
                    snapshot: snapshot.ruleset
                )
            } catch {
                throw .wave(error)
            }
            print("repository-policy: caller-wave restored \(snapshot.repository)")

        default:
            throw .configuration(
                RepositoryPolicy.ConfigurationError(
                    "caller-wave operation must be apply or restore"
                )
            )
        }
    }

    private static func applyCallerWave(
        _ values: [String: String],
        client: RepositoryPolicy.GitHubClient
    ) async throws(Error) {
        let required = [
            "--repository", "--expected-head", "--expected-blob", "--caller", "--policy",
            "--integration-id", "--events", "--recovery", "--receipt",
        ]
        guard values.count == required.count,
            required.allSatisfy({ values[$0] != nil })
        else {
            throw .configuration(
                RepositoryPolicy.ConfigurationError(
                    "caller-wave apply requires \(required.joined(separator: ", "))"
                )
            )
        }
        let repository = values["--repository"]!
        let expectedHead = values["--expected-head"]!
        let expectedBlob = values["--expected-blob"]!
        guard expectedHead.count == 40, expectedBlob.count == 40 else {
            throw .configuration(
                RepositoryPolicy.ConfigurationError(
                    "caller-wave expected head and blob must be full 40-character SHAs"
                )
            )
        }
        guard let integrationID = Int64(values["--integration-id"]!), integrationID > 0 else {
            throw .configuration(
                RepositoryPolicy.ConfigurationError(
                    "caller-wave --integration-id must be a positive integer"
                )
            )
        }
        let caller = try data(at: values["--caller"]!, label: "terminal caller")
        let canonicalRuleset: Data
        do throws(RepositoryPolicy.ConfigurationError) {
            canonicalRuleset = try RepositoryPolicy.Ruleset.protectedMainPayload(
                from: URL(filePath: values["--policy"]!)
            )
        } catch {
            throw .configuration(error)
        }
        let recoveryURL = URL(filePath: values["--recovery"]!)
        let eventsURL = URL(filePath: values["--events"]!)
        let receiptURL = URL(filePath: values["--receipt"]!)
        let receipt: Repository.Policy.Caller.Wave.Receipt
        do throws(Repository.Policy.Caller.Wave.Error) {
            receipt = try await Repository.Policy.Caller.Wave.run(
                client: client,
                request: .init(
                    repository: repository,
                    expectedHead: expectedHead,
                    expectedBlob: expectedBlob,
                    caller: caller,
                    canonicalRuleset: canonicalRuleset,
                    integrationID: integrationID,
                    commitMessage: """
                        Adopt the terminal package CI caller [skip ci]

                        Refs swift-institute/institute-continuous-integration#35
                        """
                ),
                preserve: { try encode($0, to: recoveryURL) },
                record: { try append($0, to: eventsURL) }
            )
        } catch {
            throw .wave(error)
        }
        do {
            try encode(receipt, to: receiptURL)
        } catch {
            throw .io("could not write caller-wave receipt at \(receiptURL.path): \(error)")
        }
        print(
            "repository-policy: caller-wave \(receipt.changed ? "applied" : "converged") "
                + "\(receipt.repository) head=\(receipt.newHead) blob=\(receipt.newBlob) "
                + "bypass-closed=\(receipt.bypassClosed)"
        )
    }

    private static func callerWaveClient() throws(Error) -> RepositoryPolicy.GitHubClient {
        guard let token = ProcessInfo.processInfo.environment["GH_TOKEN"], !token.isEmpty else {
            throw .configuration(RepositoryPolicy.ConfigurationError("GH_TOKEN is required"))
        }
        let api = ProcessInfo.processInfo.environment["GITHUB_API_URL"] ?? "https://api.github.com"
        guard let baseURL = URL(string: api) else {
            throw .configuration(RepositoryPolicy.ConfigurationError("GITHUB_API_URL is invalid"))
        }
        return RepositoryPolicy.GitHubClient(token: token, baseURL: baseURL)
    }

    private static func callerWaveValues(_ arguments: [String]) throws(Error) -> [String: String] {
        guard arguments.count.isMultiple(of: 2) else {
            throw .configuration(
                RepositoryPolicy.ConfigurationError("caller-wave arguments require values")
            )
        }
        var values: [String: String] = [:]
        var iterator = arguments.makeIterator()
        while let key = iterator.next(), let value = iterator.next() {
            guard key.hasPrefix("--"), values.updateValue(value, forKey: key) == nil else {
                throw .configuration(
                    RepositoryPolicy.ConfigurationError(
                        "caller-wave argument is invalid or repeated: \(key)"
                    )
                )
            }
        }
        return values
    }

    private static func data(at path: String, label: String) throws(Error) -> Data {
        do {
            return try Data(contentsOf: URL(filePath: path))
        } catch {
            throw .io("could not read \(label) at \(path): \(error)")
        }
    }

    private static func decode<T: Decodable>(at path: String, label: String) throws(Error) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: URL(filePath: path)))
        } catch {
            throw .io("could not decode \(label) at \(path): \(error)")
        }
    }

    private static func encode<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func append<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url, options: .atomic)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }
}
