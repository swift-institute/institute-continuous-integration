import Institute_Continuous_Integration
import Testing

@testable import Institute_Continuous_Integration_Canon

@Suite
struct CICanonGitignoreTests {
    static let terminator = Institute.ContinuousIntegration.Canon.Gitignore.terminator
    static let canon = "# CANONICAL\n/*\n!/Sources/\n\(terminator)\n"

    @Suite
    struct Unit {
        @Test func `the canonical half ends at the terminator`() {
            let file = Institute.ContinuousIntegration.Canon.Gitignore(CICanonGitignoreTests.canon + "own/\n")
            #expect(file.canonical == CICanonGitignoreTests.canon)
            #expect(file.local == "own/\n")
        }

        @Test func `a pre canonical file has neither half`() {
            // Absence, not a decision: it is a [GH-IGNORE-001] finding to
            // the validator and a preserve-verbatim case to the renderer.
            let file = Institute.ContinuousIntegration.Canon.Gitignore(".build/\n")
            #expect(file.canonical == nil)
            #expect(file.local == nil)
        }

        @Test func `rendering over a canonical file replaces only the canonical half`() throws {
            let existing = Institute.ContinuousIntegration.Canon.Gitignore("# OLD\n\(Institute.ContinuousIntegration.Canon.Gitignore.terminator)\nown/\n")
            let rendered = try Institute.ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon))(over: existing)
            #expect(rendered == CICanonGitignoreTests.canon + "own/\n")
        }

        @Test func `rendering over no file emits canon whole`() throws {
            // Canon already carries an empty LOCAL OVERRIDES block, so it
            // is not truncated at the terminator.
            let canon = CICanonGitignoreTests.canon + "# LOCAL\n"
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
        @Test func `a pre canonical file is preserved whole beneath canon`() throws {
            // Replacing it would delete rules a package deliberately
            // added, which is not recoverable from the diff alone.
            let rendered = try Institute.ContinuousIntegration.Canon.Gitignore.Render(
                canon: .init(CICanonGitignoreTests.canon))(over: .init("\n\nlegacy/\n"))
            #expect(rendered.hasPrefix(CICanonGitignoreTests.canon))
            #expect(rendered.hasSuffix("legacy/\n"))
            #expect(rendered.contains("# ========== LOCAL OVERRIDES =========="))
            // The leading blank lines of the old file are dropped, but
            // not a byte of its content.
            #expect(!rendered.contains("\n\n\nlegacy/"))
        }

        @Test func `a file ending at the terminator has an empty local half`() {
            let file = Institute.ContinuousIntegration.Canon.Gitignore("/*\n\(Institute.ContinuousIntegration.Canon.Gitignore.terminator)")
            #expect(file.local?.isEmpty == true)
            #expect(file.canonical?.hasSuffix("\n") == true)
        }

        @Test func `canon without a terminator is refused, not reported`() {
            // An unusable control-plane document is not a verdict about
            // any package.
            #expect(throws: Institute.ContinuousIntegration.Canon.Gitignore.Render.Error.terminatorAbsent) {
                try Institute.ContinuousIntegration.Canon.Gitignore.Render(canon: .init("/*\n"))
            }
        }
    }
}
