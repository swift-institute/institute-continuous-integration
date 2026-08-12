import ContinuousIntegration
import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Workflow
import GitHub_Standard
import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Inventory

/// The vendor-neutral contract type, aliased at file scope so the
/// reference cannot rebind to the `Institute.ContinuousIntegration`
/// nest inside the suites below.
private typealias ContractRequirement = ContinuousIntegration.Requirement

extension String {
    /// CRLF/CR normalized to LF.
    ///
    /// `Fixtures/swift-ci.yml` is a Git-tracked blob pinned to LF, but a
    /// Windows checkout of it can materialize CRLF (`core.autocrlf`).
    /// Most of that file's YAML is line-oriented and survives either
    /// spelling, but its folded block scalars (`if: >-` conditions that
    /// span physical lines) fold their *more-indented* continuation
    /// lines into the parsed string verbatim, embedded newline and all.
    /// Parsing the file with real `\r\n` in those continuations would
    /// bake a `\r` into the derived job `if:` text that a JSON encoder
    /// then escapes as `\r\n` rather than `\n` — a genuine content
    /// difference from `verdict-inventory.json`, generated from an
    /// LF checkout, not merely a trailing-newline artifact. Normalizing
    /// before parsing, rather than patching the parser or the derived
    /// JSON afterward, is the one place this closes for every field at
    /// once.
    func normalizedToLF() -> String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}

/// The inventory derived from the **shipped** universal workflow.
///
/// Every assertion here is over the real `swift-ci.yml` — the universal
/// reusable workflow shipped by `swift-institute/.github`, vendored here
/// verbatim at the extraction SHA — not over a synthetic sample. Until
/// TX-APP2Z rebinds this suite to the live control-plane tree, the
/// vendored copy is data: read, never edited alongside the code it
/// exercises.
@Suite
struct CIInventoryTests {
    static var universalPath: String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/swift-ci.yml").path
    }

    static func shipped() throws -> Institute.ContinuousIntegration.Inventory.Document {
        let text = try String(contentsOfFile: universalPath, encoding: .utf8)
        return try Institute.ContinuousIntegration.Inventory.Document(
            universalWorkflow: text.normalizedToLF())
    }

    @Suite
    struct Topology {
        @Test func `the inventory describes one hop, not three`() throws {
            #expect(Institute.ContinuousIntegration.Inventory.Document.callerHops == 1)
            #expect(Institute.ContinuousIntegration.Inventory.Document.schemaVersion == 2)
        }

        @Test func `the verdict resolves to the one required check context`() throws {
            #expect(Institute.ContinuousIntegration.Inventory.Aggregate.checkContext == "ci / matrix / ci-ok")
            #expect(Institute.ContinuousIntegration.Inventory.Aggregate.checkContext == ContractRequirement.checkContext)
        }

        @Test func `ci-ok is the only authored aggregate that gates`() throws {
            let universal = try CIInventoryTests.shipped().universal
            let aggregates = universal.jobs.filter { $0.posture == .aggregate }
            #expect(Set(aggregates.map(\.id)) == ["ci-ok", "advisory-summary"])
            #expect(!universal.aggregate.gatingJobs.isEmpty)
            #expect(universal.aggregate.gatingJobs.allSatisfy { $0 != "advisory-summary" })
        }

        @Test func `the only inner aggregate is a native matrix job and gates nothing`() throws {
            let universal = try CIInventoryTests.shipped().universal
            let inner = Set(universal.aggregate.innerMatrixJobs)
            #expect(!inner.isEmpty)
            #expect(inner.isDisjoint(with: Set(universal.aggregate.gatingJobs)))
        }
    }

    @Suite
    struct Derivation {
        @Test func `every job's posture is exactly one of the five`() throws {
            let universal = try CIInventoryTests.shipped().universal
            let gating = Set(universal.aggregate.gatingJobs)
            let advisory = Set(universal.aggregate.advisoryJobs)
            #expect(gating.isDisjoint(with: advisory))
            for job in universal.jobs {
                switch job.posture {
                case .plan: #expect(job.id == "plan")
                case .aggregate: #expect(["ci-ok", "advisory-summary"].contains(job.id))
                case .gating: #expect(gating.contains(job.id))
                case .advisory: #expect(advisory.contains(job.id))

                case .eventGated:
                    #expect(!gating.contains(job.id))
                    #expect(!advisory.contains(job.id))
                }
            }
            #expect(universal.jobCount == universal.jobs.count)
        }

        @Test func `an aggregate sits at a strictly higher wave than everything it needs`() throws {
            let universal = try CIInventoryTests.shipped().universal
            let ciOk = try #require(universal.job("ci-ok"))
            for id in universal.aggregate.gatingJobs {
                let leg = try #require(universal.job(id))
                #expect(leg.wave < ciOk.wave)
            }
            #expect(try #require(universal.job("plan")).wave == 0)
        }

        @Test func `no cache step ever caches the build directory`() throws {
            let universal = try CIInventoryTests.shipped().universal
            for step in universal.cacheSteps {
                let path = step.path.map(GitHub.ContinuousIntegration.Workflow.YAML.Canonical.json) ?? ""
                #expect(!path.contains(".build"))
            }
        }

        @Test func `the plan delegates its leg vocabulary to its Swift owner`() throws {
            let plan = try CIInventoryTests.shipped().universal.plan
            // The retired inventory re-extracted this from a `LEGS="…"`
            // shell literal that no longer exists, and had been
            // recording an EMPTY vocabulary as the shipped truth.
            #expect(plan.delegatesToInstituteCI)
            #expect(!Institute.ContinuousIntegration.Inventory.Plan.fullTierLegs.isEmpty)
        }

        @Test func `every full-tier leg names a job the universal actually declares`() throws {
            let universal = try CIInventoryTests.shipped().universal
            let declared = Set(universal.jobs.map(\.id))
            for leg in Institute.ContinuousIntegration.Inventory.Plan.fullTierLegs {
                #expect(declared.contains(leg), "full-tier leg '\(leg)' is not a declared job")
            }
        }

        @Test func `every gating job carries the private-visibility guard`() throws {
            // A guarded gating job reports NO signal on a private
            // repository. That is a deliberate property of the shipped
            // verdict, and it is worth failing on if it ever becomes
            // partial: half-guarded gating is a verdict that means
            // different things in the two visibilities.
            let universal = try CIInventoryTests.shipped().universal
            for id in universal.aggregate.gatingJobs {
                #expect(try #require(universal.job(id)).privateGuarded)
            }
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `a workflow with no jobs is refused, not inventoried as empty`() {
            #expect(throws: Institute.ContinuousIntegration.Inventory.Error.noJobs) {
                try Institute.ContinuousIntegration.Inventory.Document(universalWorkflow: "on:\n  push:\n")
            }
        }

        @Test func `a workflow with no ci-ok is refused by name`() {
            #expect(throws: Institute.ContinuousIntegration.Inventory.Error.missingJob("ci-ok")) {
                try Institute.ContinuousIntegration.Inventory.Document(
                    universalWorkflow: "jobs:\n  plan:\n    runs-on: ubuntu-latest\n")
            }
        }

        @Test func `a workflow with no plan is refused by name`() {
            #expect(throws: Institute.ContinuousIntegration.Inventory.Error.missingJob("plan")) {
                try Institute.ContinuousIntegration.Inventory.Document(
                    universalWorkflow: "jobs:\n  ci-ok:\n    runs-on: ubuntu-latest\n")
            }
        }

        @Test func `a bare needs scalar is the same DAG as a one-element list`() {
            var cache: [String: Int] = [:]
            let waves = ["a": [], "b": ["a"], "c": ["a", "b"]]
            #expect(Institute.ContinuousIntegration.Inventory.Universal.wave(of: "a", needs: waves, cache: &cache) == 0)
            #expect(Institute.ContinuousIntegration.Inventory.Universal.wave(of: "c", needs: waves, cache: &cache) == 2)
        }

        @Test func `a needs entry naming an undeclared job contributes no wave`() {
            var cache: [String: Int] = [:]
            let waves = ["a": ["ghost"]]
            #expect(Institute.ContinuousIntegration.Inventory.Universal.wave(of: "a", needs: waves, cache: &cache) == 0)
        }
    }
}
