import ContinuousIntegration
import Institute_Continuous_Integration

// Bound at file scope: inside `extension Institute.ContinuousIntegration…`
// the bare name `ContinuousIntegration` resolves to the enclosing nested
// namespace, not the module.
private typealias ContractPlan = ContinuousIntegration.Plan

extension ContinuousIntegration.Plan.Descheduled.Reason {
    /// The Institute's advisory-class expiry vocabulary. The mechanism —
    /// that a leg may be withdrawn with a recorded reason — is owned by
    /// `ContinuousIntegration.Plan`; the policy that withdraws it, and
    /// therefore this spelling, is Institute doctrine and belongs here.
    /// `ci-ok` reads the raw value, so it is wire contract.
    public static let nightlyExceptionExpired = Self(
        rawValue: "nightly-exception-expired")
}

extension Institute.ContinuousIntegration.Application {
    /// The plan use case: classify one run's tier/legs/gating from event
    /// facts, with the Institute's typed exceptions applied.
    ///
    /// A thin composition. `ContinuousIntegration.Plan` owns tier
    /// classification, leg selection, the platform filter, and the
    /// descheduling mechanism; this layer owns only the translation from
    /// an Institute exception's disposition into the plan's input.
    public enum Plan {
        public static func run(
            forcedTier: String = "",
            ref: String,
            headMessage: String = "",
            event: String,
            platformSupport: String = "",
            lintBundle: String,
            packageContentChanged: Bool = true,
            nightlyDisposition: Institute.ContinuousIntegration.NightlyException.Disposition =
                .active
        ) throws(ContractPlan.Error) -> ContractPlan {
            try ContractPlan(
                forcedTier: forcedTier,
                ref: ref,
                headMessage: headMessage,
                event: event,
                platformSupport: platformSupport,
                lintBundle: lintBundle,
                packageContentChanged: packageContentChanged,
                descheduling: descheduling(for: nightlyDisposition))
        }

        /// An expired advisory-class exception withdraws exactly its
        /// classified leg. `.active` withdraws nothing — the plan then
        /// schedules the leg as it always did.
        static func descheduling(
            for disposition: Institute.ContinuousIntegration.NightlyException.Disposition
        ) -> [ContractPlan.Descheduled] {
            guard case .expired = disposition else { return [] }
            return [
                .init(
                    leg: Institute.ContinuousIntegration.NightlyException.classifiedLeg,
                    reason: .nightlyExceptionExpired)
            ]
        }
    }
}
