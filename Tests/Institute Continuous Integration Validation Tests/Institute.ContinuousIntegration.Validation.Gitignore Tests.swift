import Institute_Continuous_Integration_Canon
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Validation

@Suite
struct CIValidationGitignoreTests {
    /// The real `canon/gitignore-package.txt`, found the way the
    /// validator finds it. A hand-written stand-in would test the test.
    static var canon: String {
        get throws {
            let path = try #require(Institute.ContinuousIntegration.Validation.Gitignore.resolvedCanonPath)
            return try #require(Institute.ContinuousIntegration.Validation.Gitignore.read(path))
        }
    }

    @Suite
    struct Unit {
        @Test func `the validator is registered for both of its rules`() {
            for rule in ["GH-IGNORE-001", "GH-IGNORE-002"] as [GitHub.ContinuousIntegration.Validation.Rule] {
                #expect(Institute.ContinuousIntegration.Validation.Registry.validator(for: rule) is Institute.ContinuousIntegration.Validation.Gitignore)
            }
        }

        @Test func `the canonical whitelist keeps every work probe and denies every junk probe`()
            throws
        {
            // The gate's two halves in one measurement, asked of git
            // rather than of the patterns: reading the patterns and
            // reasoning about them is how the premise of this gate came
            // to be wrong in the first place.
            let ignored = try Institute.ContinuousIntegration.Validation.Gitignore.ignored(
                under: CIValidationGitignoreTests.canon,
                probes: Institute.ContinuousIntegration.Validation.Gitignore.work + Institute.ContinuousIntegration.Validation.Gitignore.junk)
            for probe in Institute.ContinuousIntegration.Validation.Gitignore.work {
                #expect(!ignored.contains(probe.path), "work denied: \(probe.path)")
            }
            for probe in Institute.ContinuousIntegration.Validation.Gitignore.junk {
                #expect(ignored.contains(probe.path), "junk tracked: \(probe.path)")
            }
        }

        @Test func `a repository with no manifest is not a subject`() throws {
            // This canon describes packages. A repository without one is
            // out of scope, which is not the same as clean.
            let validator = Institute.ContinuousIntegration.Validation.Gitignore()
            let findings = try validator.findings(
                in: .init(repository: "swift-institute/Skills", root: "/nonexistent"))
            #expect(findings.isEmpty)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `the junk control is what makes a clean verdict evidence`() throws {
            // An empty ignore file denies nothing, so every work probe
            // "survives" and every 002 pass would be vacuous. The control
            // is the only thing that catches it.
            let ignored = try Institute.ContinuousIntegration.Validation.Gitignore.ignored(
                under: "", probes: Institute.ContinuousIntegration.Validation.Gitignore.work + Institute.ContinuousIntegration.Validation.Gitignore.junk)
            #expect(ignored.isEmpty)
            let tracked = Institute.ContinuousIntegration.Validation.Gitignore.junk.filter { !ignored.contains($0.path) }
            #expect(tracked.count == Institute.ContinuousIntegration.Validation.Gitignore.junk.count)
        }

        @Test func `the gitignore under test is not truncated by its own probe`() throws {
            // `.gitignore` is itself a work probe. Materialising probes
            // as empty files after writing it would blank the very file
            // under test, and every verdict in the run would reflect an
            // empty whitelist.
            let ignored = try Institute.ContinuousIntegration.Validation.Gitignore.ignored(
                under: "/*\n", probes: Institute.ContinuousIntegration.Validation.Gitignore.work)
            #expect(ignored.contains("Sources/Core/Type.swift"))
        }

        @Test func `an unreadable canon is a defect, not a finding`() {
            let validator = Institute.ContinuousIntegration.Validation.Gitignore(canon: "/nonexistent/canon.txt")
            let run = GitHub.ContinuousIntegration.Validation.Run.validate(
                validator, of: .init(repository: "r", root: "/nonexistent"))
            #expect(run.findings.isEmpty)
            #expect(run.exitCode == GitHub.ContinuousIntegration.Validation.EnvironmentDefect.exitCode)
        }
    }
}
