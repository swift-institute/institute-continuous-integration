import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Testing

/// The mandatory self-firing sweep for `[CI-118]`.
///
/// `PinnedActionSchema`'s predicate is unit-tested against synthetic
/// repositories in the package that owns it. This is the other half: the
/// assertion that the real control plane, at head, has ZERO mismatched
/// call sites — that a caller of a same-repo pinned composite action
/// passes only inputs, and gates only on outputs, that the pinned
/// revision actually declares.
///
/// It lives here rather than with the rule because a sweep is only
/// evidence over a population. The owning package carries no
/// self-referential composite actions, so the same sweep there would
/// report zero over nothing at all — the shape of green that
/// `swift-institute/.github#501` was found by human review precisely
/// because no gate modelled it.
@Suite(
    .enabled(
        if: EmbeddedShell.isAvailable,
        "no control-plane checkout named by \(EmbeddedShell.rootVariable)"))
struct PinnedActionSchemaRealTreeTests {
    @Test func everyCommittedCallSiteMatchesItsPinnedActionSchema() throws {
        let subject = GitHub.ContinuousIntegration.Validation.Subject(
            repository: "swift-institute/.github",
            root: EmbeddedShell.repositoryRoot)
        let findings = try GitHub.ContinuousIntegration.Validation.PinnedActionSchema()
            .findings(in: subject)
        #expect(!findings.contains { $0.rule == "CI-118" })
    }
}
