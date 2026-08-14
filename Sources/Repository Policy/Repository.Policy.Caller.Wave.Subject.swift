extension Repository.Policy.Caller.Wave {
    public struct Subject: Codable, Sendable, Equatable {
        public let repository: String
        public let head: String
        public let caller: CallerSource

        public init(repository: String, head: String, caller: CallerSource) {
            self.repository = repository
            self.head = head
            self.caller = caller
        }
    }
}
