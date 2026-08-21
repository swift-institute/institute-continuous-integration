public import Institute_Continuous_Integration

extension ContinuousIntegration.Source {
    public enum Bundle: Swift.String, CaseIterable, Sendable {
        case primitives
        case standards
        case institute
    }
}

extension ContinuousIntegration.Source.Bundle {
    public var token: Swift.String { rawValue }
}
