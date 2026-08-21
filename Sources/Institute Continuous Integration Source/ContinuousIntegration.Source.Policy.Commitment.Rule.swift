public import Institute_Continuous_Integration

extension ContinuousIntegration.Source.Policy.Commitment {
    public struct Rule: Sendable {
        public let suffix: Swift.String

        public init(suffix: Swift.String) {
            self.suffix = suffix
        }
    }
}
