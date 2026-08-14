extension Repository.Policy.Caller.Wave {
    public struct Population: Codable, Sendable, Equatable {
        public let organizations: [String]
        public let examined: Int
        public let excluded: [String: Int]
        public let subjects: [Subject]

        public init(
            organizations: [String],
            examined: Int,
            excluded: [String: Int],
            subjects: [Subject]
        ) {
            self.organizations = organizations
            self.examined = examined
            self.excluded = excluded
            self.subjects = subjects
        }
    }
}
