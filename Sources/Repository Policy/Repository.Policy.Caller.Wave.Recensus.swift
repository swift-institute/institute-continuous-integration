extension Repository.Policy.Caller.Wave {
    public struct Recensus: Codable, Sendable, Equatable {
        public let organizations: [String]
        public let examined: Int
        public let excluded: [String: Int]
        public let canonicalDigest: String
        public let observations: [Observation]
        public let accepted: Bool

        public init(
            organizations: [String],
            examined: Int,
            excluded: [String: Int],
            canonicalDigest: String,
            observations: [Observation],
            accepted: Bool
        ) {
            self.organizations = organizations
            self.examined = examined
            self.excluded = excluded
            self.canonicalDigest = canonicalDigest
            self.observations = observations
            self.accepted = accepted
        }
    }
}
