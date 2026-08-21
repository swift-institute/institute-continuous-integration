public import Institute_Continuous_Integration
public import Source_Profile

extension ContinuousIntegration.Source.Policy {
    public struct Configuration: Sendable {
        public let engine: Source_Profile.Source.Engine.ID
        public let predicate: Source_Profile.Source.Rule.ID

        public init(
            engine: Source_Profile.Source.Engine.ID,
            predicate: Source_Profile.Source.Rule.ID
        ) {
            self.engine = engine
            self.predicate = predicate
        }
    }
}
