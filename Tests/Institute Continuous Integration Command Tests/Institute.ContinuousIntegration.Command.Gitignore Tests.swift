import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Command
import Testing

extension Institute.ContinuousIntegration.Command.Gitignore {
    @Suite
    struct Test {
        static var root: URL {
            var root = URL(filePath: #filePath)
            root.deleteLastPathComponent()
            root.deleteLastPathComponent()
            root.deleteLastPathComponent()
            return root
        }

        static var canon: String {
            let path = root.appending(path: "canon/gitignore-package.txt")
            return String(decoding: FileManager.default.contents(atPath: path.path)!, as: UTF8.self)
        }

        static var fixtures: String {
            root.appending(path: "Tests/Institute Continuous Integration Validation Tests/Fixtures").path
        }

        @Suite
        struct Unit {
            @Test func `render command parses exact policy inputs`() throws {
                #expect(
                    try Institute.ContinuousIntegration.Command.Gitignore.parse([
                        "render-gitignore", "--canon", "canon.txt", "--target", ".gitignore",
                    ]) == .render(canon: "canon.txt", target: ".gitignore"))
            }

            @Test func `validator command parses repository inputs`() throws {
                #expect(
                    try Institute.ContinuousIntegration.Command.Gitignore.parse([
                        "validate-gitignore", "--repository", "swift-primitives/swift-byte-primitives",
                        "--root", "/tmp/subject", "--canon", "/tmp/canon.txt",
                    ])
                        == .validate(
                            repository: "swift-primitives/swift-byte-primitives", root: "/tmp/subject",
                            canon: "/tmp/canon.txt"))
            }

            @Test func `renderer emits only complete canonical bytes`() throws {
                let rendered = try Institute.ContinuousIntegration.Command.Gitignore.render(
                    canon: Institute.ContinuousIntegration.Command.Gitignore.Test.canon,
                    target: "# tail\n")
                #expect(rendered == Institute.ContinuousIntegration.Command.Gitignore.Test.canon)
                #expect(!rendered.contains("# tail"))
            }
        }

        @Suite
        struct `Edge Case` {
            @Test func `malformed command refuses before evaluation`() {
                #expect(
                    throws: Institute.ContinuousIntegration.Command.Gitignore.Error
                        .missingRequiredArgument("--root")
                ) {
                    _ = try Institute.ContinuousIntegration.Command.Gitignore.parse([
                        "validate-gitignore", "--repository", "swift-primitives/swift-byte-primitives",
                    ])
                }
            }
        }

        @Suite
        struct Integration {
            @Test func `fixture controls self fire through the shared harness`() throws {
                let report = try Institute.ContinuousIntegration.Command.Gitignore.fixtures(
                    corpus: Institute.ContinuousIntegration.Command.Gitignore.Test.fixtures)
                #expect(report.isComplete)
                #expect(!report.outcomes.isEmpty)
                #expect(
                    report.outcomes.contains {
                        $0.scenario.expectation == .violating && !$0.findings.isEmpty
                    })
            }
        }
    }
}
