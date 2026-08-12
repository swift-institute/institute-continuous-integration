import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Validation

extension Institute.ContinuousIntegration.Application {
    /// Every validator this control plane runs, from both owning
    /// registries.
    ///
    /// The retired shared registry was partitioned by subject:
    /// GitHub-Actions mechanics went to
    /// `GitHub.ContinuousIntegration.Validation.Registry`, Institute
    /// doctrine to `Institute.ContinuousIntegration.Validation.Registry`.
    /// Neither is authoritative over the other and neither may import the
    /// other, so the union is composed here, in the layer that already
    /// exists to compose. This is the only place the two are named
    /// together; a rule cannot be registered twice because each validator
    /// declares its own rules and both registries derive their index.
    public enum Registry {
        // swiftlint:disable no_any_protocol_existential - heterogeneous registry over the externally owned Validator protocol; deliberate dynamic dispatch, the [API-ERR-006]-extension opt-out class (Wave 2b decision 3)
        public static let validators: [any GitHub.ContinuousIntegration.Validation.Validator] =
            GitHub.ContinuousIntegration.Validation.Registry.validators
            + Institute.ContinuousIntegration.Validation.Registry.validators

        /// The validator authoritative for a rule, or `nil` when no
        /// registry owns it.
        public static func validator(
            for rule: GitHub.ContinuousIntegration.Validation.Rule
        ) -> (any GitHub.ContinuousIntegration.Validation.Validator)? {
            validators.first { $0.rules.contains(rule) }
        }

        /// The validator that replaces a retired script, or `nil` when no
        /// registered validator names it.
        public static func validator(
            replacing script: String
        ) -> (any GitHub.ContinuousIntegration.Validation.Validator)? {
            validators.first { $0.retiredScript == script }
        }
        // swiftlint:enable no_any_protocol_existential

        /// Every registered rule, sorted.
        public static var rules: [GitHub.ContinuousIntegration.Validation.Rule] {
            validators.flatMap(\.rules).sorted()
        }
    }
}
