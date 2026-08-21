// Licensed under the Apache License, Version 2.0.

import Foundation
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Command
import Institute_Continuous_Integration_Validation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

@main
enum Main {}

extension Main {
    static func main() {
        do throws(Error) {
            try run()
        } catch {
            FileHandle.standardError.write(
                Data("institute-continuous-integration: \(error.message)\n".utf8)
            )
            exit(2)
        }
    }

    private static func run() throws(Error) {
        // The workflow verbs dispatch first and exit on their own verdict;
        // everything else is the gitignore command's argument grammar.
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let first = arguments.first, let verb = Verb(rawValue: first) {
            run(verb, Array(arguments.dropFirst()))
            return
        }
        let action: ContinuousIntegration.Command.Gitignore.Action
        do throws(ContinuousIntegration.Command.Gitignore.Error) {
            action = try ContinuousIntegration.Command.Gitignore.parse(
                Array(CommandLine.arguments.dropFirst())
            )
        } catch {
            throw .command(error)
        }
        switch action {
        case .render(let canon, let target):
            guard let canon = read(canon) else { throw .unreadable(canon) }
            let existing = target.flatMap(read)
            let rendered: String
            do throws(ContinuousIntegration.Command.Gitignore.Error) {
                rendered = try ContinuousIntegration.Command.Gitignore.render(
                    canon: canon,
                    target: existing
                )
            } catch {
                throw .command(error)
            }
            print(rendered, terminator: "")

        case .validate(let repository, let root, let canon):
            let findings: [ContinuousIntegration.Validation.Finding]
            do throws(ContinuousIntegration.Validation.EnvironmentDefect) {
                findings = try ContinuousIntegration.Command.Gitignore.findings(
                    repository: repository,
                    root: root,
                    canon: canon
                )
            } catch {
                throw .environment(error)
            }
            print(
                ContinuousIntegration.Command.Gitignore.encoded(findings: findings),
                terminator: ""
            )

        case .fixtures(let corpus):
            let report: GitHub.ContinuousIntegration.Validation.Harness.Report
            do throws(ContinuousIntegration.Validation.EnvironmentDefect) {
                report = try ContinuousIntegration.Command.Gitignore.fixtures(
                    corpus: corpus
                )
            } catch {
                throw .environment(error)
            }
            for outcome in report.outcomes { print(outcome.summary) }
            guard report.unownedRuleDirectories.isEmpty else {
                throw .unowned(report.unownedRuleDirectories)
            }
            guard report.isSatisfied else { exit(1) }
        }
    }

    private static func read(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
