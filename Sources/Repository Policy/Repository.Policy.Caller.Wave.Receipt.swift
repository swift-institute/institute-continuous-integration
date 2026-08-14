extension Repository.Policy.Caller.Wave {
    public struct Receipt: Codable, Sendable, Equatable {
        public let repository: String
        public let oldHead: String
        public let newHead: String
        public let oldBlob: String
        public let newBlob: String
        public let changed: Bool
        public let bypassClosed: Bool
    }
}
