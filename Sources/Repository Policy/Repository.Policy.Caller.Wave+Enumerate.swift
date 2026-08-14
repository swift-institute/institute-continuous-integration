extension Repository.Policy.Caller.Wave {
    public static func enumerate<C: Client>(
        client: C,
        fleet: RepositoryPolicy.Fleet
    ) async throws(Error) -> Population {
        let organizations = fleet.activeOrganizationNames.sorted()
        guard !organizations.isEmpty else {
            throw .population("fleet policy has no active organizations")
        }
        var examined = 0
        var excluded: [String: Int] = [:]
        var seen: Set<String> = []
        var candidates: [RepositoryPolicy.Repository] = []
        for organization in organizations {
            let repositories = try await calling {
                try await client.repositories(organization: organization)
            }
            guard !repositories.isEmpty else {
                throw .population("\(organization): public repository enumeration was empty")
            }
            examined += repositories.count
            for repository in repositories.sorted(by: { $0.fullName < $1.fullName }) {
                guard repository.owner == organization else {
                    throw .population(
                        "\(organization): enumeration returned foreign repository \(repository.fullName)"
                    )
                }
                guard seen.insert(repository.fullName.lowercased()).inserted else {
                    throw .population("duplicate repository \(repository.fullName)")
                }
                if let reason = RepositoryPolicy.staticExclusion(of: repository) {
                    excluded[reason.rawValue, default: 0] += 1
                    continue
                }
                candidates.append(repository)
            }
        }
        let measurements: [Measurement]
        do {
            measurements = try await boundedMeasurements(client: client, candidates: candidates)
        } catch let error as Error {
            throw error
        } catch {
            throw .verification("fleet measurement failed unexpectedly: \(error)")
        }
        var subjects: [Subject] = []
        var missingCallers: [String] = []
        for measurement in measurements {
            switch measurement {
            case .excluded(let reason): excluded[reason, default: 0] += 1
            case .missingCaller(let repository): missingCallers.append(repository)
            case .subject(let subject): subjects.append(subject)
            }
        }
        guard missingCallers.isEmpty else {
            throw .population(
                "eligible repositories missing .github/workflows/ci.yml: "
                    + missingCallers.sorted().joined(separator: ", ")
            )
        }
        guard !subjects.isEmpty else {
            throw .population("active fleet enumeration produced zero eligible callers")
        }
        return Population(
            organizations: organizations,
            examined: examined,
            excluded: excluded,
            subjects: subjects.sorted(by: { $0.repository < $1.repository })
        )
    }

    private static func boundedMeasurements<C: Client>(
        client: C,
        candidates: [RepositoryPolicy.Repository]
    ) async throws -> [Measurement] {
        try await withThrowingTaskGroup(of: Measurement.self) { group in
            var iterator = candidates.makeIterator()
            for _ in 0..<min(16, candidates.count) {
                guard let repository = iterator.next() else { break }
                group.addTask { try await measure(client: client, repository: repository) }
            }
            var result: [Measurement] = []
            while let measurement = try await group.next() {
                result.append(measurement)
                if let repository = iterator.next() {
                    group.addTask { try await measure(client: client, repository: repository) }
                }
            }
            return result
        }
    }

    private static func measure<C: Client>(
        client: C,
        repository: RepositoryPolicy.Repository
    ) async throws(Error) -> Measurement {
        let manifest = try await calling {
            try await client.rootManifestKind(repository.fullName)
        }
        let manifestFact: Repository_Policy.Repository.Policy.Eligibility.Subject.Manifest
        switch manifest {
        case "file": manifestFact = .present
        case nil: manifestFact = .absent
        default:
            throw .population(
                "\(repository.fullName): root Package.swift is not a regular file"
            )
        }
        switch Repository_Policy.Repository.Policy.Eligibility.verdict(
            .init(repository: repository.fullName, rootManifest: manifestFact)
        ) {
        case .noManifest:
            return .excluded("missing-root-manifest")
        case .bespoke:
            return .excluded("bespoke-ci")
        case .eligible:
            break
        }
        let live = try await calling {
            try await client.waveRepository(repository.fullName)
        }
        guard live.defaultBranch == "main" else {
            throw .population(
                "\(repository.fullName): eligible package default branch is not main"
            )
        }
        let head = try await calling { try await client.head(repository.fullName) }
        let caller = try await calling {
            try await client.callerSourceIfPresent(repository.fullName, head: head)
        }
        guard let caller else { return .missingCaller(repository.fullName) }
        return .subject(.init(repository: repository.fullName, head: head, caller: caller))
    }
}
