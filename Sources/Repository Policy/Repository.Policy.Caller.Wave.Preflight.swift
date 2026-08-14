extension Repository.Policy.Caller.Wave {
    public struct Preflight: Codable, Sendable, Equatable {
        public let organization: String
        public let repository: String
        public let population: Commitment
        public let recoveryDigest: String
        public let canPush: Bool
        public let canAdminister: Bool
        public let accepted: Bool

        public init(
            organization: String,
            repository: String,
            population: Commitment,
            recoveryDigest: String,
            canPush: Bool,
            canAdminister: Bool,
            accepted: Bool
        ) {
            self.organization = organization
            self.repository = repository
            self.population = population
            self.recoveryDigest = recoveryDigest
            self.canPush = canPush
            self.canAdminister = canAdminister
            self.accepted = accepted
        }
    }
}
