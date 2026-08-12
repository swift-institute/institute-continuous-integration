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

extension Main {
    /// The three Gitignore faces, behind their typed command grammar.
    ///
    /// `render-gitignore` is the propagation face driven by
    /// `sync-gitignore.yml`: it writes the rendered file to stdout with no
    /// terminator of its own, so a caller byte-comparing it against the
    /// target produces no commit for a conformant repository.
    static func gitignore(_ arguments: [String]) {
        do throws(Error) {
            try runGitignore(arguments)
        } catch {
            report(error.message)
            exit(2)
        }
    }

    private static func runGitignore(_ arguments: [String]) throws(Error) {
        let action: Institute.ContinuousIntegration.Command.Gitignore.Action
        do throws(Institute.ContinuousIntegration.Command.Gitignore.Error) {
            action = try Institute.ContinuousIntegration.Command.Gitignore.parse(arguments)
        } catch {
            throw .command(error)
        }
        switch action {
        case .render(let canon, let target):
            guard let canon = read(canon) else { throw .unreadable(canon) }
            let existing = target.flatMap(read)
            let rendered: String
            do throws(Institute.ContinuousIntegration.Command.Gitignore.Error) {
                rendered = try Institute.ContinuousIntegration.Command.Gitignore.render(
                    canon: canon, target: existing)
            } catch {
                throw .command(error)
            }
            print(rendered, terminator: "")

        case .validate(let repository, let root, let canon):
            let findings: [Institute.ContinuousIntegration.Validation.Finding]
            do throws(Institute.ContinuousIntegration.Validation.EnvironmentDefect) {
                findings = try Institute.ContinuousIntegration.Command.Gitignore.findings(
                    repository: repository, root: root, canon: canon)
            } catch {
                throw .environment(error)
            }
            print(
                Institute.ContinuousIntegration.Command.Gitignore.encoded(findings: findings),
                terminator: "")

        case .fixtures(let corpus):
            let report: GitHub.ContinuousIntegration.Validation.Harness.Report
            do throws(Institute.ContinuousIntegration.Validation.EnvironmentDefect) {
                report = try Institute.ContinuousIntegration.Command.Gitignore.fixtures(
                    corpus: corpus)
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
}
