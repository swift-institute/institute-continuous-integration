import Institute_Continuous_Integration

// Nest.Name namespace shell. The Application layer orchestrates use
// cases and owns no predicate: the predicates live in
// `ContinuousIntegration` (vendor-neutral),
// `GitHub.ContinuousIntegration` (the GitHub half), and the Institute
// nests of this package. What is here is composition — which policy
// applies to which mechanism for one run — plus the process boundaries
// (event payloads, the GitHub API client) a predicate may not hold.
extension Institute.ContinuousIntegration {
    public enum Application {}
}
