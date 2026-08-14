extension Repository.Policy.Caller.Wave {
    public struct Capacity: Codable, Sendable, Equatable {
        public let remaining: Int
        public let required: Int
        public let resetAt: Int
        public let accepted: Bool

        public init(remaining: Int, required: Int, resetAt: Int) {
            self.remaining = remaining
            self.required = required
            self.resetAt = resetAt
            self.accepted = remaining >= required
        }
    }
}
