// Thin CLI mapping only; owns no predicate.
import Byte_Primitives
import ContinuousIntegration
import Foundation
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Application
import Institute_Continuous_Integration_Contract

extension Main {
    /// The verbs the universal reusable workflow invokes. Each maps
    /// arguments onto an owner and prints its result; the decisions are
    /// the owners', and the exit status is the verdict.
    enum Verb: String {
        case packageCommand = "package"
        case validate = "validate"
        case validateFixtures = "validate-fixtures"
        case control
        case bootstrapManifest = "bootstrap-manifest"
        case bootstrapVerify = "bootstrap-verify"
        case bootstrapIdentity = "bootstrap-identity"
    }

    static func value(_ flag: String, in arguments: [String]) -> String {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count
        else { return "" }
        return arguments[index + 1]
    }

    static func refuse(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("institute-continuous-integration: \(message)\n".utf8))
        exit(1)
    }

    static func emit(_ payload: [String: Any]) {
        let data: Data
        do {
            data = try JSONSerialization.data(
                withJSONObject: payload, options: [.sortedKeys])
        } catch {
            refuse("could not serialize payload: \(error)")
        }
        print(String(decoding: data, as: UTF8.self))
    }

    /// The decoded root object of a JSON document, or a refusal naming
    /// what could not be read. One reader for both callers below, so a
    /// malformed document reports the same way wherever it arrives.
    static func decoded(_ data: Data, _ subject: String) -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            refuse("\(subject): malformed JSON: \(error)")
        }
        guard let root = object as? [String: Any] else {
            refuse("\(subject): expected a JSON object at the root")
        }
        return root
    }

    static func run(_ verb: Verb, _ rest: [String]) {
        switch verb {
        case .packageCommand: package(rest)
        case .control: control(rest)

        case .validate: validate(rest)

        case .validateFixtures: validateFixtures(rest)

        case .bootstrapIdentity, .bootstrapManifest, .bootstrapVerify:
            bootstrap(verb, rest)
        }
    }

    // MARK: - temporary validator compatibility

    /// TEMPORARY COMPATIBILITY
    /// consumer: current validator-fixture workflow on .github/main
    /// deletion event: trusted control validate owns the positive-control
    /// corpus and the old fixture workflow has no remaining caller.
    static func validateFixtures(_ arguments: [String]) {
        let root = value("--corpus", in: arguments)
        guard !root.isEmpty else {
            unmeasured("validate-fixtures requires --corpus <fixtures-dir>")
        }
        // CI-010/CI-099's historical static-matrix corpus encodes the model
        // this change replaces. Its focused planner-driven controls live at
        // the canonical owner and are not reinterpreted as compatibility
        // evidence. The old directories are reported outside this bounded
        // scope until the host fixture workflow is retired.
        let explicitSupportRoot = value("--support-root", in: arguments)
        let legacyScripts = value("--scripts", in: arguments)
        let supportRoot: String
        if !explicitSupportRoot.isEmpty {
            supportRoot = explicitSupportRoot
        } else if !legacyScripts.isEmpty {
            // TEMPORARY COMPATIBILITY: the incumbent host passes its
            // `.github/scripts` path. Delete this branch with that caller.
            supportRoot =
                URL(fileURLWithPath: legacyScripts)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
        } else {
            unmeasured("validate-fixtures requires --support-root <support-root>")
        }
        let institute =
            Institute.ContinuousIntegration.Validation.Registry.validators.filter {
                !($0 is Institute.ContinuousIntegration.Validation.UniversalWorkflow)
                    && !($0 is Institute.ContinuousIntegration.Validation.Gitignore)
            } + [
                Institute.ContinuousIntegration.Validation.Gitignore(
                    canon: supportRoot + "/canon/gitignore-package.txt")
            ]
        let instituteRules = Set(institute.flatMap(\.rules))
        let generic = GitHub.ContinuousIntegration.Validation.Registry.validators.filter {
            instituteRules.isDisjoint(with: $0.rules)
                && !($0 is GitHub.ContinuousIntegration.Validation.CIMatrix)
        }
        let report: GitHub.ContinuousIntegration.Validation.Harness.Report
        do throws(Institute.ContinuousIntegration.Validation.EnvironmentDefect) {
            report = try GitHub.ContinuousIntegration.Validation.Harness(
                corpus: .init(root: root), validators: institute + generic
            ).run(matching: value("--rule-prefix", in: arguments))
        } catch {
            unmeasured(error.message)
        }
        guard !report.outcomes.isEmpty else {
            unmeasured("validate-fixtures selected no Swift-owned fixture scenarios")
        }
        guard
            report.outcomes.contains(where: {
                $0.scenario.expectation == .violating && !$0.findings.isEmpty
            })
        else {
            unmeasured("validate-fixtures observed no firing positive control")
        }
        for outcome in report.outcomes { print("  " + outcome.summary) }
        print("")
        print("Total: \(report.satisfied.count) passed, \(report.unsatisfied.count) failed")
        if !report.unownedRuleDirectories.isEmpty {
            print(
                "Outside the Swift compatibility scope (\(report.unownedRuleDirectories.count)): "
                    + report.unownedRuleDirectories.joined(separator: ", "))
        }
        exit(report.isSatisfied ? 0 : 1)
    }

    /// The existing validate-base route. Exit 3 means the named retired
    /// script has no Swift owner yet; the host then uses its incumbent path.
    static func validate(_ arguments: [String]) {
        let script = value("--script", in: arguments)
        let rule = Institute.ContinuousIntegration.Validation.Rule(
            value("--rule", in: arguments))
        // swiftlint:disable:next no_any_protocol_existential - registry-selected validator requires deliberate dynamic dispatch; same [API-ERR-006]-extension opt-out as the owning registry
        let validator: (any Institute.ContinuousIntegration.Validation.Validator)? =
            script.isEmpty
            ? Institute.ContinuousIntegration.Validation.Registry.validator(for: rule)
            : Institute.ContinuousIntegration.Validation.Registry.validator(replacing: script)
        guard let validator else { exit(3) }
        let subject = Institute.ContinuousIntegration.Validation.Subject(
            repository: value("--repository", in: arguments),
            root: value("--root", in: arguments))
        let findings: [Institute.ContinuousIntegration.Validation.Finding]
        do throws(Institute.ContinuousIntegration.Validation.EnvironmentDefect) {
            findings = try validator.findings(in: subject)
        } catch {
            unmeasured(error.message)
        }
        for finding in findings { print(finding.tsv) }
    }

    static func unmeasured(_ message: String) -> Never {
        FileHandle.standardError.write(
            Data("institute-continuous-integration: \(message)\n".utf8))
        exit(Institute.ContinuousIntegration.Validation.EnvironmentDefect.exitCode)
    }

    // MARK: - plan

    static func plan(_ rest: [String]) {
        let today = value("--today", in: rest)
        var deschedule: [String: String] = [:]
        // Optional by construction, like the release-floor exception below:
        // the leg it classifies is opt-in, so a run that never schedules it
        // has no exception to validate. Present, it must validate — an
        // exception cannot be half-supplied into silence.
        let nightlyImage = value("--nightly-main-image", in: rest)
        if !nightlyImage.isEmpty {
            do {
                // Class-aware expiry: malformed fields refuse everywhere; a
                // well-formed expired exception refuses only on the owner
                // repository and deschedules its classified leg elsewhere.
                let nightly = Institute.ContinuousIntegration.NightlyException(
                    image: nightlyImage,
                    upstreamIssue: value("--nightly-main-upstream-issue", in: rest),
                    recheck: value("--nightly-main-recheck", in: rest))
                if case .expired = try nightly.disposition(
                    today: today,
                    subjectRepository: value("--subject-repository", in: rest))
                {
                    deschedule[
                        Institute.ContinuousIntegration.NightlyException
                            .classifiedLeg.id] = "nightly-exception-expired"
                }
            } catch {
                refuse("plan refused: \(error)")
            }
        }

        let swiftVersion = value("--swift-version", in: rest)
        let floorImage = value("--release-floor-image", in: rest)
        let linuxImage: String
        do {
            // Optional by construction: an absent image is the terminal
            // state, resolving to the official `swift:<floor>`.
            linuxImage = try Institute.ContinuousIntegration.ReleaseFloorException.resolve(
                swiftVersion: swiftVersion,
                exception: floorImage.isEmpty
                    ? nil
                    : Institute.ContinuousIntegration.ReleaseFloorException(
                        swiftVersion: swiftVersion,
                        image: floorImage,
                        upstreamRelease: value("--release-floor-upstream-release", in: rest),
                        recheck: value("--release-floor-recheck", in: rest)),
                today: today)
        } catch {
            refuse("plan refused: \(error)")
        }

        let event = value("--event", in: rest)
        let plan: ContinuousIntegration.Plan
        do {
            plan = try ContinuousIntegration.Plan(
                forcedTier: value("--tier", in: rest),
                ref: value("--ref", in: rest),
                headMessage: value("--head-message", in: rest),
                event: event,
                platformSupport: value("--platform-support", in: rest),
                lintBundle: value("--lint-bundle", in: rest),
                packageContentChanged: Institute.ContinuousIntegration.PackageDiff
                    .packageContentChanged(
                        event: event,
                        eventPath: value("--event-path", in: rest),
                        repository: value("--workflow-repository", in: rest),
                        workspace: value("--workspace", in: rest)),
                deschedule: deschedule)
        } catch {
            refuse("plan refused: \(error)")
        }

        emit([
            "tier": plan.tier.rawValue,
            "legs": plan.legs.map(\.id).joined(separator: ","),
            "gating": plan.gating.map(\.id).joined(separator: ","),
            "package-content-changed": plan.packageContentChanged,
            "linux-image": linuxImage,
            // `leg=reason` records; empty when nothing was descheduled.
            "descheduled": plan.descheduled
                .map { "\($0.leg.id)=\($0.reason)" }
                .joined(separator: ","),
        ])
    }

    // MARK: - aggregate

    static func aggregate(_ rest: [String]) {
        guard let data = value("--needs-json", in: rest).data(using: .utf8) else {
            refuse("aggregate requires --needs-json '{job: {result: ...}}'")
        }
        let needs = decoded(data, "aggregate --needs-json")
        func result(of job: String) -> String {
            (needs[job] as? [String: Any])?["result"] as? String ?? ""
        }
        var results: [String: String] = [:]
        for job in needs.keys where job != "plan" {
            results[job] = result(of: job)
        }
        let verdict = ContinuousIntegration.AggregateVerdict(
            planResult: result(of: "plan"),
            results: results,
            gating: value("--gating", in: rest).split(separator: ",").map(String.init),
            subjectRepository: value("--subject-repository", in: rest),
            subjectSha: value("--subject-sha", in: rest),
            tier: value("--tier", in: rest),
            requireFullTier: rest.contains("--require-full-tier"),
            packageContentChanged: value("--package-content-changed", in: rest) != "false",
            // `leg=reason` records from the plan; the audit keys on ids.
            descheduled: value("--descheduled", in: rest)
                .split(separator: ",")
                .map { String($0.split(separator: "=")[0]) })
        for finding in verdict.findings {
            FileHandle.standardError.write(
                Data("institute-continuous-integration: \(finding)\n".utf8))
        }
        print(verdict.pass ? "pass" : "fail")
        exit(verdict.pass ? 0 : 1)
    }

    // MARK: - bootstrap

    static func identityJSON(
        _ identity: Institute.ContinuousIntegration.Bootstrap.Identity
    ) -> [String: Any] {
        [
            "workspaceRevision": identity.workspaceRevision,
            "sourcesRevision": identity.sourcesRevision,
            "toolchain": identity.toolchain,
            "operatingSystem": identity.operatingSystem,
            "architecture": identity.architecture,
            "provisioning": identity.provisioning.sorted(),
        ]
    }

    static func bootstrap(_ verb: Verb, _ rest: [String]) {
        let identity = Institute.ContinuousIntegration.Bootstrap.Identity(
            workspaceRevision: value("--workspace-revision", in: rest),
            sourcesRevision: value("--sources-revision", in: rest),
            toolchain: value("--toolchain", in: rest),
            operatingSystem: value("--os", in: rest),
            architecture: value("--arch", in: rest),
            provisioning: value("--provisioning", in: rest)
                .split(separator: ",").map(String.init))
        do {
            try identity.validate()
        } catch {
            refuse("bootstrap identity refused: \(error)")
        }

        switch verb {
        case .bootstrapIdentity:
            var payload = identityJSON(identity)
            payload["key"] = identity.digest
            emit(payload)

        case .bootstrapManifest:
            let root = value("--root", in: rest)
            var executables: [[String: Any]] = []
            for path in value("--executables", in: rest).split(separator: ",").map(String.init) {
                guard let data = FileManager.default.contents(atPath: root + "/" + path)
                else { refuse("bootstrap-manifest: unreadable executable \(path)") }
                let executable = Institute.ContinuousIntegration.Bootstrap.Manifest.Executable(
                    path: path, bytes: [UInt8](data).map(Byte.init))
                executables.append(["path": executable.path, "digest": executable.digest])
            }
            if executables.isEmpty { refuse("bootstrap-manifest: no executables") }
            emit([
                "identity": identityJSON(identity),
                "key": identity.digest,
                "executables": executables,
                "producerRun": value("--producer-run", in: rest),
            ])

        case .bootstrapVerify:
            let root = value("--root", in: rest)
            guard
                let data = FileManager.default.contents(
                    atPath: value("--manifest", in: rest))
            else { refuse("bootstrap-verify: unreadable manifest") }
            let object = decoded(data, "bootstrap-verify manifest")
            guard
                let identityObject = object["identity"] as? [String: Any],
                let key = object["key"] as? String,
                let executableObjects = object["executables"] as? [[String: Any]],
                let producerRun = object["producerRun"] as? String
            else { refuse("bootstrap-verify: malformed manifest") }

            let recorded = Institute.ContinuousIntegration.Bootstrap.Identity(
                workspaceRevision: identityObject["workspaceRevision"] as? String ?? "",
                sourcesRevision: identityObject["sourcesRevision"] as? String ?? "",
                toolchain: identityObject["toolchain"] as? String ?? "",
                operatingSystem: identityObject["operatingSystem"] as? String ?? "",
                architecture: identityObject["architecture"] as? String ?? "",
                provisioning: identityObject["provisioning"] as? [String] ?? [])
            let manifest = Institute.ContinuousIntegration.Bootstrap.Manifest(
                identity: recorded,
                key: key,
                executables: executableObjects.map {
                    .init(
                        path: $0["path"] as? String ?? "",
                        digest: $0["digest"] as? String ?? "")
                },
                producerRun: producerRun)
            do {
                try manifest.verify(against: identity) { path in
                    FileManager.default.contents(atPath: root + "/" + path)
                        .map { [UInt8]($0).map(Byte.init) }
                }
            } catch {
                refuse("bootstrap cache entry refused (fail closed): \(error)")
            }
            print(
                """
                verified: key \(identity.digest), \
                \(executableObjects.count) executable(s), producer run \(producerRun)
                """)

        case .control, .packageCommand, .validate, .validateFixtures:
            refuse("unreachable")
        }
    }
}
