// Licensed under the Apache License, Version 2.0.

import ContinuousIntegration
import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Application
import Institute_Continuous_Integration_Contract

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// The plan face: one run's tier, legs, gating, and the two typed
    /// image exceptions, as the JSON the plan job's outputs are read from.
    static func plan(_ rest: [String]) {
        do {
            let nightlyException = Institute.ContinuousIntegration.NightlyException(
                image: value("--nightly-main-image", in: rest),
                upstreamIssue: value("--nightly-main-upstream-issue", in: rest),
                recheck: value("--nightly-main-recheck", in: rest))
            let today = value("--today", in: rest)
            // Class-aware expiry (ruled 2026-08-10, .github#488): malformed
            // fields refuse everywhere; a well-formed expired exception
            // refuses only on the owner repository and deschedules the
            // classified leg on every other subject.
            let nightlyDisposition = try nightlyException.disposition(
                today: today,
                subjectRepository: value("--subject-repository", in: rest))
            // The release-floor exception is OPTIONAL by construction: an
            // absent `--release-floor-image` is the terminal state, resolving
            // to the official `swift:<floor>` image. Present, it must
            // validate before any leg is emitted
            // (swift-institute/.github#491).
            let releaseFloorImage = value("--release-floor-image", in: rest)
            let swiftVersion = value("--swift-version", in: rest)
            let linuxImage = try Institute.ContinuousIntegration.ReleaseFloorException.resolve(
                swiftVersion: swiftVersion,
                exception: releaseFloorImage.isEmpty
                    ? nil
                    : Institute.ContinuousIntegration.ReleaseFloorException(
                        swiftVersion: swiftVersion,
                        image: releaseFloorImage,
                        upstreamRelease: value("--release-floor-upstream-release", in: rest),
                        recheck: value("--release-floor-recheck", in: rest)),
                today: today)
            let plan = try Institute.ContinuousIntegration.Application.Plan.run(
                forcedTier: value("--tier", in: rest),
                ref: value("--ref", in: rest),
                headMessage: value("--head-message", in: rest),
                event: value("--event", in: rest),
                platformSupport: value("--platform-support", in: rest),
                lintBundle: value("--lint-bundle", in: rest),
                packageContentChanged: Institute.ContinuousIntegration.Application.PackageDiff
                    .packageContentChanged(
                        event: value("--event", in: rest),
                        eventPath: value("--event-path", in: rest),
                        repository: value("--workflow-repository", in: rest),
                        workspace: value("--workspace", in: rest)),
                nightlyDisposition: nightlyDisposition)
            let payload: [String: Any] = [
                "tier": plan.tier.rawValue,
                "legs": plan.legs.map(\.id).joined(separator: ","),
                "gating": plan.gating.map(\.id).joined(separator: ","),
                "package-content-changed": plan.packageContentChanged,
                "linux-image": linuxImage,
                // `leg=reason` records; empty when nothing was descheduled.
                "descheduled": plan.descheduled
                    .map { "\($0.leg.id)=\($0.reason.rawValue)" }
                    .joined(separator: ","),
            ]
            let data = try JSONSerialization.data(
                withJSONObject: payload, options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        } catch {
            report("plan refused: \(error)")
            exit(1)
        }
    }

    /// The ci-ok face: the single aggregate over every participating job's
    /// result. Exit 1 is a failed verdict, not a broken machine.
    static func aggregate(_ rest: [String]) {
        let needsJSON = value("--needs-json", in: rest)
        guard let needsData = needsJSON.data(using: .utf8),
            // swift-linter:disable:next try optional
            // REASON: JSONSerialization throws untyped; a needs payload that does not decode is refused by the guard as a malformed argument.
            // swiftlint:disable:next no_try_optional
            let needs = (try? JSONSerialization.jsonObject(with: needsData))
                as? [String: [String: Any]]
        else {
            fail("aggregate requires --needs-json '{job: {result: ...}}'")
        }
        var results: [String: String] = [:]
        for (job, object) in needs where job != "plan" {
            results[job] = object["result"] as? String ?? ""
        }
        let verdict = ContinuousIntegration.AggregateVerdict(
            planResult: needs["plan"]?["result"] as? String ?? "",
            results: results,
            gating: value("--gating", in: rest).split(separator: ",").map(String.init),
            subjectRepository: value("--subject-repository", in: rest),
            subjectSha: value("--subject-sha", in: rest),
            tier: value("--tier", in: rest),
            requireFullTier: rest.contains("--require-full-tier"),
            packageContentChanged: value("--package-content-changed", in: rest) != "false",
            // `leg=reason` records from the plan; the audit keys on leg ids.
            descheduled: value("--descheduled", in: rest)
                .split(separator: ",")
                .map { String($0.split(separator: "=")[0]) })
        for finding in verdict.findings {
            report("\(finding)")
        }
        print(verdict.pass ? "pass" : "fail")
        exit(verdict.pass ? 0 : 1)
    }
}
