extension Repository.Policy.Caller.Wave {
    public struct Repository: Sendable, Equatable {
        public let id: Int64
        public let visibility: String
        public let archived: Bool
        public let disabled: Bool
        public let defaultBranch: String
        public let canPush: Bool
        public let canAdminister: Bool

        public init(
            id: Int64,
            visibility: String,
            archived: Bool,
            disabled: Bool,
            defaultBranch: String,
            canPush: Bool,
            canAdminister: Bool
        ) {
            self.id = id
            self.visibility = visibility
            self.archived = archived
            self.disabled = disabled
            self.defaultBranch = defaultBranch
            self.canPush = canPush
            self.canAdminister = canAdminister
        }
    }
}
