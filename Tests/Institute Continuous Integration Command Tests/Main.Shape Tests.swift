import Foundation
import Repository_Policy
import Testing

@testable import Institute_Continuous_Integration_CLI_Foundation_Integration

extension Main.Shape {
    @Suite
    struct Test {
        static let repository = "swift-primitives/swift-byte-primitives"
        static let gitignore = Repository.Policy.Uniformity.Wave.Payload.bytes
        static let caller = Data(Repository.Policy.Caller.Render.terminal.utf8)

        @Suite
        struct Unit {
            @Test func `ratified bytes and admitted paths are clean`() {
                #expect(
                    Main.Shape.findings(
                        repository: Test.repository,
                        gitignore: Test.gitignore,
                        ignoredIndexedPaths: [],
                        caller: Test.caller
                    ).isEmpty
                )
            }

            @Test func `a tracked path outside policy fires shape one`() {
                let findings = Main.Shape.findings(
                    repository: Test.repository,
                    gitignore: Test.gitignore,
                    ignoredIndexedPaths: ["Policy/rules.json"],
                    caller: Test.caller
                )
                #expect(findings.count == 1)
                #expect(findings.first?.contains("\tPACKAGE-SHAPE-001\t") == true)
                #expect(findings.first?.contains("Policy/rules.json") == true)
            }

            @Test func `drifted gitignore fires shape two without path claims`() {
                let findings = Main.Shape.findings(
                    repository: Test.repository,
                    gitignore: Data("*.tmp\n".utf8),
                    ignoredIndexedPaths: ["Policy/rules.json"],
                    caller: Test.caller
                )
                #expect(findings.count == 1)
                #expect(findings.first?.contains("\tPACKAGE-SHAPE-002\t") == true)
                #expect(findings.first?.contains("Policy/rules.json") == false)
            }

            @Test func `drifted terminal caller fires shape three`() {
                let findings = Main.Shape.findings(
                    repository: Test.repository,
                    gitignore: Test.gitignore,
                    ignoredIndexedPaths: [],
                    caller: Data("name: local CI\n".utf8)
                )
                #expect(findings.count == 1)
                #expect(findings.first?.contains("\tPACKAGE-SHAPE-003\t") == true)
            }
        }
    }
}
