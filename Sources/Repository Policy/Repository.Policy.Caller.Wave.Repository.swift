extension Repository.Policy.Caller.Wave {
    public struct Repository: Sendable, Equatable {
        public let visibility: String
        public let archived: Bool
        public let disabled: Bool
        public let defaultBranch: String

        public init(
            visibility: String,
            archived: Bool,
            disabled: Bool,
            defaultBranch: String
        ) {
            self.visibility = visibility
            self.archived = archived
            self.disabled = disabled
            self.defaultBranch = defaultBranch
        }
    }
}
