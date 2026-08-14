extension Repository.Policy.Caller.Wave {
    public struct Recovery: Codable, Sendable, Equatable {
        public let repository: String
        public let rollbackHead: String
        public let caller: CallerSource
        public let ruleset: RulesetSnapshot

        public init(
            repository: String,
            rollbackHead: String,
            caller: CallerSource,
            ruleset: RulesetSnapshot
        ) {
            self.repository = repository
            self.rollbackHead = rollbackHead
            self.caller = caller
            self.ruleset = ruleset
        }
    }
}
