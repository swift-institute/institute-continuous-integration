public import Institute_Continuous_Integration

extension ContinuousIntegration.Source.Policy.Asset {
    public enum Origin: Sendable {
        case release(base: Swift.String)
        case xcode(version: Swift.String, build: Swift.String, relativePath: Swift.String)
    }
}
