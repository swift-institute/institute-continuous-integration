import Foundation

extension Repository.Policy.Caller.Wave {
    public struct Request: Sendable {
        public let repository: String
        public let expectedHead: String
        public let expectedBlob: String
        public let caller: Data
        public let canonicalRuleset: Data
        public let integrationID: Int64
        public let commitMessage: String

        public init(
            repository: String,
            expectedHead: String,
            expectedBlob: String,
            caller: Data,
            canonicalRuleset: Data,
            integrationID: Int64,
            commitMessage: String
        ) {
            self.repository = repository
            self.expectedHead = expectedHead
            self.expectedBlob = expectedBlob
            self.caller = caller
            self.canonicalRuleset = canonicalRuleset
            self.integrationID = integrationID
            self.commitMessage = commitMessage
        }
    }
}
