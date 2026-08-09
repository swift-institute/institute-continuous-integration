import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Validation

/// The Institute-policy half of what `.github/scripts/tests/run.sh` ran:
/// every validator registered in
/// `Institute.ContinuousIntegration.Validation.Registry` runs against the
/// real fixture corpus — the same files, unmodified — and each scenario
/// must meet the expectation its directory declares.
///
/// The corpus here is the *non-owned* remainder of the retired shared
/// corpus: the nineteen GitHub-mechanics rule directories moved to
/// swift-foundations/swift-github-continuous-integration with their
/// validators; everything else — the Institute-policy directories this
/// registry owns plus the port residue with no Swift owner yet — moved
/// here. The residue is counted and named, never silently skipped.
@Suite
struct InstituteValidationCorpusTests {
    typealias Validation = GitHub.ContinuousIntegration.Validation

    /// The corpus, located from this file rather than from a working
    /// directory, so the suite behaves the same under SwiftPM, Xcode,
    /// and CI.
    static var corpus: Validation.Corpus {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()  // → the test target directory
        return .init(root: url.appendingPathComponent("Fixtures").path)
    }

    /// One corpus run over the Institute registry. The engine's
    /// `Harness` is hardwired to the GitHub-mechanics registry, so this
    /// suite carries its own loop with the identical semantics: only
    /// findings for the directory's own rule count, `fail/` scenarios
    /// expect at least one, `pass/` and `edge/` expect none.
    struct Outcome {
        let rule: Validation.Rule
        let scenario: Validation.Corpus.Scenario
        let findings: [Validation.Finding]

        var isSatisfied: Bool {
            scenario.expectation == .violating ? !findings.isEmpty : findings.isEmpty
        }

        var summary: String {
            let verdict = isSatisfied ? "PASS" : "FAIL"
            return "\(verdict) \(rule) \(scenario.expectation.rawValue)/\(scenario.name)"
                + " (\(findings.count) finding(s))"
        }
    }

    static func run() throws -> (outcomes: [Outcome], unowned: [String]) {
        var outcomes: [Outcome] = []
        var unowned: [String] = []
        for directory in try corpus.ruleDirectories() {
            guard
                let rule = Institute.ContinuousIntegration.Validation.Registry
                    .rule(forCorpusDirectory: directory),
                let validator = Institute.ContinuousIntegration.Validation.Registry
                    .validator(for: rule)
            else {
                unowned.append(directory)
                continue
            }
            for scenario in try corpus.scenarios(in: directory) {
                let findings = try validator.findings(in: scenario.subject)
                    .filter { $0.rule == rule }
                outcomes.append(Outcome(rule: rule, scenario: scenario, findings: findings))
            }
        }
        return (outcomes, unowned)
    }

    @Test func `no two validators claim the same rule`() {
        var seen: Set<Validation.Rule> = []
        for validator in Institute.ContinuousIntegration.Validation.Registry.validators {
            for rule in validator.rules {
                #expect(!seen.contains(rule), "rule \(rule) is claimed twice")
                seen.insert(rule)
            }
        }
    }

    @Test func `every registered rule resolves back to its validator`() {
        for rule in Institute.ContinuousIntegration.Validation.Registry.rules {
            #expect(
                Institute.ContinuousIntegration.Validation.Registry.validator(for: rule) != nil)
        }
    }

    @Test func `the fixture corpus is where the suite expects it`() throws {
        let directories = try Self.corpus.ruleDirectories()
        // 48 rule directories plus `schema-correspondence`, the flat
        // scenario tree GH-REPO-063's own suite runs directly.
        #expect(
            directories.count == 49,
            "expected the 49-directory Institute-side corpus, found \(directories.count)")
    }

    @Test func `every owned scenario meets its expectation`() throws {
        let (outcomes, unowned) = try Self.run()
        for outcome in outcomes where !outcome.isSatisfied {
            Issue.record("\(outcome.summary)")
        }
        let allSatisfied = outcomes.allSatisfy { $0.isSatisfied }
        #expect(allSatisfied)
        // Guard against a silently empty run: a harness that checks
        // nothing passes everything.
        #expect(!outcomes.isEmpty)
        #expect(outcomes.contains { $0.scenario.expectation == .violating && !$0.findings.isEmpty })
        // Port residue is named, not silently skipped: every directory is
        // either owned by this registry or listed as residue.
        let directories = try Self.corpus.ruleDirectories()
        let owned = Set(
            directories.filter {
                Institute.ContinuousIntegration.Validation.Registry
                    .rule(forCorpusDirectory: $0) != nil
            })
        #expect(owned.isDisjoint(with: Set(unowned)))
        #expect(owned.count + unowned.count == directories.count)
    }
}
