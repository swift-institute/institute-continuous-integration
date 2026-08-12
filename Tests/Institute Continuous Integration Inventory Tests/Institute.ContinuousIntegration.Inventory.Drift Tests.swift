import ContinuousIntegration
import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Workflow
import GitHub_Standard
import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Inventory

/// The two gates the retired `test-verdict-inventory.py` existed for,
/// re-derived for the current topology.
///
/// **Drift** — the committed corpus must equal what deriving the
/// inventory from *this checkout's* `swift-ci.yml` produces right now,
/// byte for byte. A workflow edit that changes the verdict's shape and
/// leaves the corpus alone is a test failure, not silent staleness.
///
/// **Reality** — the corpus must agree with a real hosted full-tier run.
/// This is the half the retired suite never had: it compared the
/// inventory only against the YAML it was derived from, so an inventory
/// could be perfectly faithful to a workflow that no longer described
/// what GitHub actually ran. The recorded run is
/// `swift-primitives/swift-cache-primitives` **31151036569**
/// (`workflow_dispatch` on `main`, conclusion `success`), read from the
/// run object and its jobs, and vendored here verbatim.
@Suite
struct CIInventoryDriftTests {
    static var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    @Test func `the committed corpus is what the shipped workflow derives to`() throws {
        let derived = try CIInventoryTests.shipped().canonicalJSON + "\n"
        // `verdict-inventory.json` is the same kind of LF-pinned Git blob
        // as `swift-ci.yml` (see `String.normalizedToLF()`); a Windows
        // checkout can materialize its trailing newline as CRLF, which
        // would fail this byte-for-byte comparison on line-ending noise
        // the committed corpus never actually carries.
        let committed = try String(
            contentsOf: Self.fixtures.appendingPathComponent("verdict-inventory.json"),
            encoding: .utf8
        ).normalizedToLF()
        #expect(
            derived == committed,
            """
            verdict-inventory.json is stale relative to \
            .github/workflows/swift-ci.yml. Regenerate it:
              institute-ci verdict-inventory --universal .github/workflows/swift-ci.yml \\
                > 'Tools/institute-ci/Tests/CI Inventory Tests/Fixtures/verdict-inventory.json'
            """)
    }

    // MARK: - The live run

    /// One job of the recorded run.
    struct ObservedJob {
        let name: String
        let conclusion: String

        /// The job's own display name: the run reports every job of the
        /// universal under the caller's `ci / matrix / ` prefix — which
        /// is the one-hop topology, visible in the wire format — and a
        /// job that itself delegates adds a further ` / <step job>`
        /// segment.
        var displayName: String? {
            let prefix = "ci / matrix / "
            guard name.hasPrefix(prefix) else { return nil }
            return name.dropFirst(prefix.count).components(separatedBy: " / ").first
        }
    }

    static func recordedRun() throws -> [String: Any] {
        let data = try Data(
            contentsOf: fixtures.appendingPathComponent("run-31151036569.json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    static func observedJobs() throws -> [ObservedJob] {
        let jobs = try #require(try recordedRun()["jobs"] as? [[String: Any]])
        return jobs.map {
            ObservedJob(
                name: $0["name"] as? String ?? "",
                conclusion: $0["conclusion"] as? String ?? "")
        }
    }

    /// Whether a rendered display name could have come from a job's
    /// `name:` template. `${{ … }}` expansions are unknowable outside a
    /// run, so each becomes a hole and the surrounding literals must
    /// appear in order.
    static func rendered(_ candidate: String, matches template: String) -> Bool {
        var literals: [String] = []
        var current = ""
        var rest = Substring(template)
        while let start = rest.range(of: "${{") {
            current += rest[rest.startIndex..<start.lowerBound]
            literals.append(current)
            current = ""
            guard let end = rest.range(of: "}}", range: start.upperBound..<rest.endIndex) else {
                return false
            }
            rest = rest[end.upperBound...]
        }
        literals.append(current + rest)

        guard candidate.hasPrefix(literals.first ?? "") else { return false }
        guard candidate.hasSuffix(literals.last ?? "") else { return false }
        var cursor = candidate.index(candidate.startIndex, offsetBy: (literals.first ?? "").count)
        for literal in literals.dropFirst() where !literal.isEmpty {
            guard let found = candidate.range(of: literal, range: cursor..<candidate.endIndex)
            else { return false }
            cursor = found.upperBound
        }
        return true
    }

    /// Which declared job produced a rendered display name.
    ///
    /// Most-specific-wins, and it is needed. Three of the shipped
    /// templates overlap: `linux-release` is
    /// `Ubuntu (Swift ${{ inputs.swift-version }}, release)`, whose hole
    /// also swallows the *literal* names of `linux-nightly`
    /// (`Ubuntu (Swift main nightly, release)`) and `linux-6-4`
    /// (`Ubuntu (Swift 6.4.x nightly, release)`). A name carrying no
    /// hole is the more specific pattern and takes the match; the
    /// wildcard only claims what no literal did.
    ///
    /// This is a real property of the shipped workflow, not an artefact
    /// of the matcher: a reader of a run — human or machine — cannot
    /// resolve those three job names from the wire format alone either.
    static func resolve(
        _ displayName: String, in universal: Institute.ContinuousIntegration.Inventory.Universal
    ) -> [Institute.ContinuousIntegration.Inventory.Job] {
        let candidates = universal.jobs.filter {
            rendered(displayName, matches: $0.displayName ?? $0.id)
        }
        let literal = candidates.filter { !($0.displayName ?? $0.id).contains("${{") }
        return literal.isEmpty ? candidates : literal
    }

    @Test func `every job the live run reported resolves to exactly one declared job`() throws {
        let universal = try CIInventoryTests.shipped().universal
        for observed in try Self.observedJobs() {
            let displayName = try #require(
                observed.displayName,
                "'\(observed.name)' is not under the one-hop 'ci / matrix / ' prefix")
            let matches = Self.resolve(displayName, in: universal)
            #expect(matches.count == 1, "'\(displayName)' resolved to \(matches.map(\.id))")
        }
    }

    @Test func `every job the inventory declares appeared in the live full-tier run`() throws {
        let universal = try CIInventoryTests.shipped().universal
        let resolved = Set(
            try Self.observedJobs()
                .compactMap(\.displayName)
                .flatMap { Self.resolve($0, in: universal).map(\.id) })
        for job in universal.jobs {
            #expect(
                resolved.contains(job.id),
                "declared job '\(job.id)' produced no job in run 31151036569")
        }
    }

    @Test func `every gating job the inventory names succeeded in the live run`() throws {
        let universal = try CIInventoryTests.shipped().universal
        let observed = try Self.observedJobs()
        for id in universal.aggregate.gatingJobs {
            let reported = observed.filter { job in
                job.displayName.map { Self.resolve($0, in: universal).map(\.id) == [id] } ?? false
            }
            #expect(!reported.isEmpty, "gating job '\(id)' did not report")
            #expect(
                reported.allSatisfy { $0.conclusion == "success" },
                "gating job '\(id)' reported \(reported.map(\.conclusion))")
        }
    }

    @Test func `the recorded run is a green full-tier run on main`() throws {
        let run = try Self.recordedRun()
        #expect(run["conclusion"] as? String == "success")
        #expect(run["event"] as? String == "workflow_dispatch")
    }

    @Test func `the aggregate itself reported success under the one-hop context`() throws {
        let observed = try Self.observedJobs()
        let aggregate = observed.filter { $0.name == Institute.ContinuousIntegration.Inventory.Aggregate.checkContext }
        #expect(aggregate.count == 1, "the required check context did not appear exactly once")
        #expect(aggregate.first?.conclusion == "success")
    }

    @Test func `a matrix job is the only place one declared job reports more than once`() throws {
        let universal = try CIInventoryTests.shipped().universal
        let observed = try Self.observedJobs().compactMap(\.displayName)
        for job in universal.jobs where !job.hasMatrix {
            let count = observed.filter { Self.resolve($0, in: universal).map(\.id) == [job.id] }
                .count
            #expect(count <= 1, "non-matrix job '\(job.id)' reported \(count) times")
        }
    }
}

extension CIInventoryDriftTests {
    /// The real `swift-ci.yml` fixture, converted to CRLF exactly as a
    /// Windows checkout of the same LF-pinned blob would (`core.autocrlf`),
    /// still derives the same canonical JSON as the LF original — once
    /// read through `String.normalizedToLF()`. Without that
    /// normalization the folded `if:` block scalars (`docs`, among
    /// others) bake a `\r` into their parsed continuation lines, which a
    /// JSON encoder then escapes as `\r\n` rather than `\n` — a real
    /// content difference from `verdict-inventory.json`, not merely a
    /// trailing-newline artifact.
    ///
    /// The fixture is LF-pinned in the git *object*, not on disk: there
    /// is no `.gitattributes` forcing `Fixtures/swift-ci.yml` to
    /// `eol=lf`, so a real Windows checkout's `core.autocrlf` already
    /// materializes it as CRLF on disk before this test ever reads it.
    /// Reading the raw working-tree bytes as `lfText` and then
    /// substituting `\n` → `\r\n` to build `crlfText` would
    /// double-convert on that platform (`\r\n` → `\r\r\n`) — a corrupted
    /// simulation, not a reproduction of a real checkout. `\r\r\n` does
    /// not round-trip through `normalizedToLF()` either: its first pass
    /// (`\r\n` → `\n`) only consumes the *trailing* `\r\n` of the triple,
    /// leaving a leading `\r` followed by the freshly-inserted `\n`;
    /// its second pass (`\r` → `\n`) then turns that pair into `\n\n` —
    /// a genuine doubled-newline corruption, not merely the CRLF-vs-LF
    /// difference under test. Normalizing the raw read *before* deriving
    /// the CRLF simulation closes that gap: the substitution then always
    /// starts from guaranteed-pure LF, regardless of whether the
    /// working-tree file itself is LF or already autocrlf-converted CRLF.
    @Test func `a simulated Windows CRLF checkout of swift-ci-yml still derives the committed corpus`()
        throws
    {
        let lfText = try String(contentsOfFile: CIInventoryTests.universalPath, encoding: .utf8)
            .normalizedToLF()
        let crlfText = lfText.replacingOccurrences(of: "\n", with: "\r\n")
        let lfDerived = try Institute.ContinuousIntegration.Inventory.Document(
            universalWorkflow: lfText.normalizedToLF()
        ).canonicalJSON
        let crlfDerived = try Institute.ContinuousIntegration.Inventory.Document(
            universalWorkflow: crlfText.normalizedToLF()
        ).canonicalJSON
        #expect(lfDerived == crlfDerived)
    }
}
