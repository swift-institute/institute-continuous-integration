// Licensed under the Apache License, Version 2.0.

import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Continuous_Integration_Workflow
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Application
import Institute_Continuous_Integration_Inventory
import Institute_Continuous_Integration_Validation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// The rule-invocation face: one validator, one repository, TSV on
    /// stdout.
    ///
    /// Two ways to name the validator, because two callers ask
    /// differently. A person, a test, or the harness names a **rule**. A
    /// sweep over a foreign checkout may still name a **retired script**,
    /// and needs an answer for a script with no Swift owner: `--script` on
    /// an unowned script is not a failure, it exits `unportedScript` (3),
    /// distinct from both `0` (ran) and `2` (could not run).
    static func validate(_ rest: [String]) {
        typealias Validation = GitHub.ContinuousIntegration.Validation
        let script = value("--script", in: rest)
        // swiftlint:disable:next no_any_protocol_existential - the registry is heterogeneous by construction; see Application.Registry
        var validator: any Validation.Validator
        if script.isEmpty {
            let rule = Validation.Rule(value("--rule", in: rest))
            guard
                let registered = Institute.ContinuousIntegration.Application.Registry
                    .validator(for: rule)
            else {
                fail("validate: no Swift validator is registered for rule '\(rule)'")
            }
            validator = registered
        } else {
            guard
                let registered = Institute.ContinuousIntegration.Application.Registry
                    .validator(replacing: script)
            else {
                exit(unportedScript)
            }
            validator = registered
        }
        // Support-file overrides. Only the validators that read a support
        // file consult these, and they are passed through rather than
        // discovered so a sweep over a foreign checkout can name the
        // manifest and the ledger it means.
        let organizationsFile = value("--orgs-file", in: rest)
        let baselineFile = value("--baseline", in: rest)
        if !organizationsFile.isEmpty || !baselineFile.isEmpty {
            guard validator is Validation.BranchPins else {
                fail("validate: --orgs-file/--baseline are not inputs to this validator")
            }
            validator = Validation.BranchPins(
                organizationsFile: organizationsFile.isEmpty ? nil : organizationsFile,
                baselineFile: baselineFile.isEmpty ? nil : baselineFile)
        }
        // The three-file face GH-REPO-063 inherited from its retired
        // script's positional arguments: the fixture corpus keeps the
        // schema, the sync workflow, and the readme consumer flat in one
        // scenario directory, so its caller names them rather than relying
        // on the subject-root defaults.
        let schemaFile = value("--schema", in: rest)
        let syncWorkflowFile = value("--sync-workflow", in: rest)
        let readmeValidatorFile = value("--readme-validator", in: rest)
        if !schemaFile.isEmpty || !syncWorkflowFile.isEmpty || !readmeValidatorFile.isEmpty {
            guard validator is Institute.ContinuousIntegration.Validation.SchemaCorrespondence
            else {
                fail(
                    "validate: --schema/--sync-workflow/--readme-validator are not "
                        + "inputs to this validator")
            }
            validator = Institute.ContinuousIntegration.Validation.SchemaCorrespondence(
                schemaFile: schemaFile.isEmpty ? nil : schemaFile,
                syncWorkflowFile: syncWorkflowFile.isEmpty ? nil : syncWorkflowFile,
                readmeValidatorFile: readmeValidatorFile.isEmpty ? nil : readmeValidatorFile)
        }
        let subject = Validation.Subject(
            repository: value("--repository", in: rest), root: value("--root", in: rest))
        let run = Validation.Run.validate(validator, of: subject)
        if let defect = run.defect { report(defect.message) }
        for finding in run.findings { print(finding.tsv) }
        exit(run.exitCode)
    }

    /// The harness face: every registered validator run over the fixture
    /// corpus.
    ///
    /// A rule directory no registry owns is named, never silently skipped
    /// — an unowned corpus is indistinguishable from a clean one — and
    /// `--require-complete` turns that residue into a failure.
    static func validateFixtures(_ rest: [String]) {
        let root = value("--corpus", in: rest)
        if root.isEmpty { fail("validate-fixtures requires --corpus <fixtures-dir>") }
        let harness = GitHub.ContinuousIntegration.Validation.Harness(
            corpus: .init(root: root),
            validators: Institute.ContinuousIntegration.Application.Registry.validators)
        let report: GitHub.ContinuousIntegration.Validation.Harness.Report
        do throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) {
            report = try harness.run(matching: value("--rule-prefix", in: rest))
        } catch {
            fail(error.message)
        }
        for outcome in report.outcomes { print("  " + outcome.summary) }

        // Transitional: every rule directory the registries do not own yet
        // is run through its retired script, so the corpus gate does not
        // narrow while the port is in progress. `--scripts` names the
        // directory holding them; omitting it declines the fallback, which
        // is what the end state does.
        //
        // A directory that is neither owned by a registry nor covered by
        // the table is a hard failure, not a skip: an unowned corpus is
        // indistinguishable from a clean one.
        var residue = report.unownedRuleDirectories
        var fallbackFailures = 0
        var fallbackPassed = 0
        let scriptsDirectory = value("--scripts", in: rest)
        if !scriptsDirectory.isEmpty {
            var unresolved: [String] = []
            for directory in residue {
                let corpus = GitHub.ContinuousIntegration.Validation.Corpus(root: root)
                let scenarios: [GitHub.ContinuousIntegration.Validation.Corpus.Scenario]
                do throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) {
                    scenarios = try corpus.scenarios(in: directory)
                } catch {
                    fail(error.message)
                }
                // A directory with no `pass/`, `fail/` or `edge/` scenarios
                // is shared fixture data, not a rule corpus — `fixtures/
                // callers/` and `fixtures/wrappers/` are read by other
                // suites.
                if scenarios.isEmpty { continue }
                guard
                    let script = Institute.ContinuousIntegration.Application
                        .RetiredValidator.scripts[directory]
                else {
                    unresolved.append(directory)
                    continue
                }
                let rule = Institute.ContinuousIntegration.Application.RetiredValidator
                    .rule(forDirectory: directory)
                for scenario in scenarios {
                    let output = Institute.ContinuousIntegration.Application.RetiredValidator
                        .run(
                            script: "\(scriptsDirectory)/\(script)",
                            repository: scenario.repository, root: scenario.root)
                    let found = output.split(separator: "\n").filter { line in
                        line.split(separator: "\t", omittingEmptySubsequences: false)
                            .dropFirst().first == rule[...]
                    }
                    let satisfied =
                        scenario.expectation == .violating ? !found.isEmpty : found.isEmpty
                    if satisfied { fallbackPassed += 1 } else { fallbackFailures += 1 }
                    print(
                        "  \(satisfied ? "PASS" : "FAIL") \(rule) (python3) "
                            + "\(scenario.expectation.rawValue)/\(scenario.name)"
                            + " (\(found.count) finding(s))")
                }
            }
            residue = unresolved
        }

        print("")
        print(
            "Total: \(report.satisfied.count + fallbackPassed) passed, "
                + "\(report.unsatisfied.count + fallbackFailures) failed")
        if !residue.isEmpty {
            // Named, not silently skipped. During the port this residue is
            // expected, so it is reported and gated by --require-complete.
            print(
                "Awaiting a Swift validator (\(residue.count)): "
                    + residue.joined(separator: ", "))
        }
        // With the fallback armed a residue entry means *nothing* ran for
        // that rule — neither engine owns it — which is the condition the
        // retired harness refused to pass. Without it, residue is the
        // ordinary in-progress state and only `--require-complete` gates.
        let unowned =
            scriptsDirectory.isEmpty
            ? (rest.contains("--require-complete") ? !residue.isEmpty : false)
            : !residue.isEmpty
        if !scriptsDirectory.isEmpty && !residue.isEmpty {
            // Qualified: `report` is the harness result in this scope.
            Main.report(
                "no engine owns \(residue.count) rule "
                    + "director(ies): \(residue.joined(separator: ", "))")
        }
        exit(!report.isSatisfied || fallbackFailures > 0 || unowned ? 1 : 0)
    }

    /// Canonical JSON of one workflow document, as the reader sees it.
    /// The face the reader is proved through: comparable against any other
    /// YAML implementation's canonical rendering of the same file, which
    /// is a far wider check than comparing one rule's findings.
    static func workflowJSON(_ rest: [String]) {
        let path = value("--file", in: rest)
        guard let data = FileManager.default.contents(atPath: path) else {
            fail("workflow-json: unreadable file \(path)")
        }
        do throws(GitHub.ContinuousIntegration.Workflow.YAML.Error) {
            let document = try GitHub.ContinuousIntegration.Workflow.Document(
                name: (path as NSString).lastPathComponent,
                text: String(decoding: data, as: UTF8.self))
            print(GitHub.ContinuousIntegration.Workflow.YAML.Canonical.json(document.root))
        } catch {
            report(error.message)
            exit(1)
        }
    }

    /// The structural inventory of the shipped verdict, as canonical JSON.
    /// Regenerates the committed expectation corpus; the drift check
    /// itself is a test, not a mode of this command, so that a stale
    /// corpus fails the package rather than one workflow step.
    static func verdictInventory(_ rest: [String]) {
        let path = value("--universal", in: rest)
        guard let data = FileManager.default.contents(atPath: path) else {
            fail("verdict-inventory: unreadable universal workflow \(path)")
        }
        do throws(Institute.ContinuousIntegration.Inventory.Error) {
            let inventory = try Institute.ContinuousIntegration.Inventory.Document(
                universalWorkflow: String(decoding: data, as: UTF8.self))
            print(inventory.canonicalJSON)
        } catch {
            report(error.message)
            exit(1)
        }
    }
}
