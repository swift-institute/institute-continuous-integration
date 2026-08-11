import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Canon

@Suite
struct CICanonGitignoreTests {
    static let terminator = Institute.ContinuousIntegration.Canon.Gitignore.terminator
    static let canon =
        "# CANONICAL\n/*\n!/Sources/\n"
        + Institute.ContinuousIntegration.Canon.Gitignore.Capability.block
        + "\(terminator)\n"

    @Suite
    struct Unit {
        @Test func `the generated marker is recognized`() {
            let file = Institute.ContinuousIntegration.Canon.Gitignore(CICanonGitignoreTests.canon)
            #expect(file.isGenerated)
            #expect(file.generatedPrefix == CICanonGitignoreTests.canon)
        }

        @Test func `a pre canonical file has no generated marker`() {
            // Absence is a [GH-IGNORE-001] finding to the validator and
            // replacement input to the complete-policy renderer.
            let file = Institute.ContinuousIntegration.Canon.Gitignore(".build/\n")
            #expect(!file.isGenerated)
            #expect(file.generatedPrefix == nil)
        }

        @Test func `rendering over a canonical file replaces the complete policy`() throws {
            let existing = Institute.ContinuousIntegration.Canon.Gitignore("# OLD\n\(Institute.ContinuousIntegration.Canon.Gitignore.terminator)\nown/\n")
            let rendered = try Institute.ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon))(over: existing)
            #expect(rendered == CICanonGitignoreTests.canon)
        }

        @Test func `rendering over no file emits canon whole`() throws {
            let canon = CICanonGitignoreTests.canon
            let rendered = try Institute.ContinuousIntegration.Canon.Gitignore.Render(canon: .init(canon))(over: nil)
            #expect(rendered == canon)
        }

        @Test func `rendering is idempotent`() throws {
            // The caller byte-compares before committing, so a second
            // render of a conformant file must produce no change.
            let render = try Institute.ContinuousIntegration.Canon.Gitignore.Render(canon: .init(CICanonGitignoreTests.canon))
            let once = render(over: nil)
            let twice = render(over: .init(once))
            #expect(once == twice)
        }
    }

    @Suite
    struct Class {
        typealias Class = Institute.ContinuousIntegration.Canon.Gitignore.Class

        @Test func `every class names its own canon document`() {
            #expect(Class.package.canonPath == "canon/gitignore-package.txt")
            for `class` in Class.allCases {
                #expect(`class`.canonPath == "canon/gitignore-\(`class`.rawValue).txt")
            }
        }

        @Test func `classification authority order is assignment, org, manifest`() {
            // Assignments are empty today; the derivations carry the
            // fleet. The control-plane org outranks manifest facts, and
            // the manifest's generator fact outranks the package default.
            #expect(Class.of(repository: "swift-institute/Research", manifest: nil) == .institute)
            #expect(
                Class.of(
                    repository: "swift-institute/institute-continuous-integration",
                    manifest: "// swift-tools-version: 6.3") == .institute)
            #expect(Class.of(repository: "swift-primitives/x", manifest: "…") == .package)
            #expect(Class.of(repository: "swift-primitives/x", manifest: nil) == .scaffold)
            #expect(
                Class.of(
                    repository: "swift-standards/x",
                    manifest: #".executableTarget(name: "SVG Generator")"#) == .generator)
        }

        @Test func `no repository is assigned before the convergence ruling`() {
            // The typed exception list is admitted by ruling, not by
            // drift; an entry appearing here must arrive with the ruling
            // that admits it.
            #expect(Class.assignments.isEmpty)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `a pre canonical file is replaced rather than preserved as a tail`() throws {
            let rendered = try Institute.ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon))(over: .init("\n\nlegacy/\n"))
            #expect(rendered == CICanonGitignoreTests.canon)
        }

        @Test func `a file ending at the terminator is generated`() {
            let file = Institute.ContinuousIntegration.Canon.Gitignore("/*\n\(Institute.ContinuousIntegration.Canon.Gitignore.terminator)")
            #expect(file.isGenerated)
            #expect(file.generatedPrefix?.hasSuffix("\n") == true)
        }

        @Test func `canon without a terminator is refused, not reported`() {
            // An unusable control-plane document is not a verdict about
            // any package.
            #expect(throws: Institute.ContinuousIntegration.Canon.Gitignore.Render.Error.terminatorAbsent) {
                try Institute.ContinuousIntegration.Canon.Gitignore.Render(canon: .init("/*\n"))
            }
        }
    }

    @Test func `the policy vocabulary is closed at six capabilities`() {
        typealias Capability = Institute.ContinuousIntegration.Canon.Gitignore.Capability
        #expect(
            Capability.allCases.map(\.rawValue) == [
                "benchmark baseline", "snapshot baseline", "environment example",
                "repository policy corpus", "fixture provenance manifest", "editor configuration",
            ])
        #expect(
            Capability.allCases.map(\.admission) == [
                "!**/.benchmarks/", "!**/.snapshots/", "!/.env.example", "!/canon/",
                "!**/Fixtures/MANIFEST.md", "!/.editorconfig",
            ])
    }

    @Test func `nested package policy is exact`() {
        #expect(Institute.ContinuousIntegration.Canon.Gitignore.Nested.roots == ["Tests", "Benchmarks"])
        #expect(Institute.ContinuousIntegration.Canon.Gitignore.Nested.text == ".build/\n.swiftpm/\n.benchmarks/\n")
        #expect(
            Institute.ContinuousIntegration.Canon.Gitignore.Nested.policies(
                declarations: ["Tests/Package.swift"]
            ) == ["Tests/.gitignore": ".build/\n.swiftpm/\n.benchmarks/\n"])
    }
}

@Suite
struct CICanonConfigurationTests {
    typealias Configuration = Institute.ContinuousIntegration.Canon.Configuration

    static let declaration = Configuration.Declaration(repositoryClass: .package)

    static func profile(_ baseline: Configuration.Baseline, _ text: String = "policy\n") throws -> Configuration.Profile {
        try .init(baseline: baseline, declaration: declaration, text: text)
    }

    @Test func `rendering selects one complete profile per tool deterministically`() throws {
        let render = try Configuration.Render(profiles: [
            try profile(.swiftLintV1, "lint\n"), try profile(.swiftFormatV1, "format\n"),
        ], declaration: declaration)
        #expect(try render.text(for: .swiftFormat) == "format\n")
        #expect(try render.text(for: .swiftLint) == "lint\n")
        #expect(Configuration.Render.outputDirectory == ".institute/configuration")
        #expect(Configuration.Tool.swiftFormat.invocation == "swift format --configuration .institute/configuration/.swift-format")
        #expect(Configuration.Tool.swiftLint.invocation == "swiftlint --config .institute/configuration/.swiftlint.yml")
    }

    @Test func `missing profile fails closed`() throws {
        #expect(throws: Configuration.Error.missingProfile(.swiftLint)) {
            _ = try Configuration.Render(profiles: [try profile(.swiftFormatV1)], declaration: declaration)
        }
    }

    @Test func `unratified typed delta fails closed rather than becoming a local escape hatch`() throws {
        let withDelta = Configuration.Declaration(repositoryClass: .package, deltas: [.frozenEvidence])
        #expect(throws: Configuration.Error.unratifiedDeltas([.frozenEvidence])) {
            _ = try Configuration.Render(profiles: [], declaration: withDelta)
        }
    }
}
