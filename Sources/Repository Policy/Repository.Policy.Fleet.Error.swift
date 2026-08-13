extension RepositoryPolicy.Fleet {
    public enum Error: Swift.Error, Swift.Sendable, Swift.Equatable {
        case unreadable
        case invalid
    }
}
