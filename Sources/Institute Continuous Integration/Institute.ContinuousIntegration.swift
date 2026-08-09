// Nest.Name namespace shells. `Institute` is the Swift Institute's own
// policy namespace; `Institute.ContinuousIntegration` is the sole owner
// of the relation between continuous-integration semantics and Institute
// doctrine — the policy validators, the canonical documents the control
// plane distributes, and the structural inventory of the shipped
// verdict. The vendor-neutral CI domain is owned by
// swift-foundations/swift-continuous-integration, and the GitHub half of
// the relation by swift-foundations/swift-github-continuous-integration;
// this package owns only what is Institute policy.
public enum Institute {}

extension Institute {
    public enum ContinuousIntegration {}
}
