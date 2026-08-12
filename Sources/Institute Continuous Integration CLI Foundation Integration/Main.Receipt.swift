// Licensed under the Apache License, Version 2.0.

import Byte_Primitives
import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Receipt

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// The pure base canonicalizer (TX7 §8.9; P19/P20). Reads the run
    /// object and jobs collection the aggregate fetched for its OWN run;
    /// it never calls GitHub and never claims a terminal conclusion.
    static func runtimeReceipt(_ rest: [String]) {
        typealias Receipt = Institute.ContinuousIntegration.Receipt
        let output = value("--output", in: rest)
        guard let runData = FileManager.default.contents(atPath: value("--run-json", in: rest)),
            let jobsData = FileManager.default.contents(atPath: value("--jobs-json", in: rest))
        else { fail("runtime-receipt: --run-json and --jobs-json must both be readable") }
        let attestation: Receipt.Attestation
        do throws(Receipt.Capture.Error) {
            attestation = try Receipt.Capture.attestation(
                runJSON: [UInt8](runData).map(Byte.init),
                jobsJSON: [UInt8](jobsData).map(Byte.init),
                plannedGating: value("--planned-gating", in: rest)
                    .split(separator: ",").map(String.init),
                subjectRepository: value("--subject-repository", in: rest),
                subjectSha: value("--subject-sha", in: rest),
                subjectVisibility: value("--subject-visibility", in: rest))
        } catch {
            FileHandle.standardError.write(Data("::error::\(error)\n".utf8))
            exit(1)
        }
        let payload = Receipt.Canonical.bytes(of: attestation)
        let digest = Receipt.Canonical.digest(of: payload)
        let bytes = Data(payload.map(\.underlying))
        guard FileManager.default.createFile(atPath: output, contents: bytes),
            FileManager.default.createFile(
                atPath: output + ".sha256", contents: Data((digest + "\n").utf8))
        else { fail("runtime-receipt: could not write \(output)") }
        print("effective-runtime-receipt-base-digest=\(digest)")
        print("effective-runtime-receipt-stage=\(attestation.stage.rawValue)")
        if attestation.verdict == .unmeasured {
            FileHandle.standardError.write(
                Data(
                    ("::error::referenced_workflows is empty/unavailable — the "
                        + "reusable-workflow chain is UNMEASURED and this aggregate "
                        + "must fail (P20).\n").utf8))
            exit(1)
        }
    }

    /// The weekly probe's predicate. Input is a runs payload on a path or
    /// on stdin; exit 1 means at least one run never started.
    static func startupFailures(_ rest: [String]) {
        typealias Receipt = Institute.ContinuousIntegration.Receipt
        let path = rest.first { !$0.hasPrefix("-") } ?? "-"
        let data: Data
        if path == "-" {
            data = FileHandle.standardInput.readDataToEndOfFile()
        } else if let contents = FileManager.default.contents(atPath: path) {
            data = contents
        } else {
            FileHandle.standardError.write(Data("# error: cannot read \(path)\n".utf8))
            exit(2)
        }
        let probe: Receipt.Run.Startup
        do throws(Receipt.Run.Summary.Error) {
            probe = .init(
                scanning: try Receipt.Run.Summary.collection([UInt8](data).map(Byte.init)))
        } catch {
            FileHandle.standardError.write(Data("# error: \(error)\n".utf8))
            exit(2)
        }
        if probe.isClean {
            print("clean: 0 startup_failure runs in \(probe.inspected.count) recent run(s).")
            exit(0)
        }
        print(
            "FLAGGED: \(probe.flagged.count) startup_failure run(s) in "
                + "\(probe.inspected.count) recent run(s):")
        for run in probe.flagged {
            let line =
                "  - \(run.name ?? "?") (run \(run.id.map(String.init) ?? "?")) "
                + (run.htmlURL ?? "")
            print(String(line.reversed().drop { $0 == " " }.reversed()))
        }
        exit(1)
    }

    /// The post-completion collector. Credentialed by construction: it
    /// reads the completed run and its complete paginated jobs collection,
    /// so unlike every other face here it cannot be measured against a
    /// static corpus — its predicate is `Augmentation.outcome`, which is
    /// measured, and this face is the transport around it.
    static func runtimeReceiptAugment(_ rest: [String]) {
        typealias Receipt = Institute.ContinuousIntegration.Receipt
        let repository = value("--repo", in: rest)
        let runIdentifier = value("--run-id", in: rest)
        guard let attempt = Int(value("--attempt", in: rest)) else {
            fail("runtime-receipt-augment: --attempt must be an integer")
        }

        // The base artifact: exactly one, by name. A sweep run carries one
        // receipt per swept subject, so "more than one" is ambiguity, not a
        // convenience to resolve by picking the first.
        let artifactName = value("--base-artifact", in: rest)
        let artifacts = object(
            api("repos/\(repository)/actions/runs/\(runIdentifier)/artifacts?per_page=100"))
        let matches = (artifacts["artifacts"] as? [[String: Any]] ?? [])
            .filter { $0["name"] as? String == artifactName }
        guard matches.count == 1, let artifactIdentifier = matches[0]["id"] as? Int else {
            fail("expected exactly one artifact named \(artifactName), found \(matches.count)")
        }
        let archive = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-\(artifactIdentifier).zip")
        // swift-linter:disable:next try optional
        // REASON: Data.write(to:) throws untyped; a failed write surfaces as the empty-extraction refusal below.
        // swiftlint:disable:next no_try_optional
        try? api("repos/\(repository)/actions/artifacts/\(artifactIdentifier)/zip")
            .write(to: archive)
        let extraction = Process()
        extraction.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        extraction.arguments = ["unzip", "-p", archive.path, "*.base.json"]
        let extracted = Pipe()
        extraction.standardOutput = extracted
        // swift-linter:disable:next try optional
        // REASON: Process.run() throws untyped; the only recovery is to report unzip unavailable.
        // swiftlint:disable:next no_try_optional
        guard (try? extraction.run()) != nil else { fail("unzip is not available") }
        let baseData = extracted.fileHandleForReading.readDataToEndOfFile()
        extraction.waitUntilExit()
        guard extraction.terminationStatus == 0, !baseData.isEmpty else {
            fail("the base artifact carries no .base.json")
        }

        let basePayload = [UInt8](baseData).map(Byte.init)
        let baseDigest = Receipt.Canonical.digest(of: basePayload)
        let base: Receipt.Attestation
        do throws(Receipt.Canonical.Error) {
            base = try Receipt.Canonical.attestation(from: basePayload)
        } catch {
            FileHandle.standardError.write(Data("::error::\(error)\n".utf8))
            exit(1)
        }

        let liveRun = object(api("repos/\(repository)/actions/runs/\(runIdentifier)"))
        var conclusions: [Int: Receipt.Conclusion?] = [:]
        var page = 1
        while true {
            let document = object(
                api(
                    "repos/\(repository)/actions/runs/\(runIdentifier)/jobs"
                        + "?per_page=100&page=\(page)"))
            let rows = document["jobs"] as? [[String: Any]] ?? []
            for row in rows {
                guard let identifier = row["id"] as? Int else { continue }
                conclusions[identifier] =
                    (row["conclusion"] as? String).map { Receipt.Conclusion($0) }
            }
            if rows.count < 100 { break }
            page += 1
        }

        let outcome: Receipt.Augmentation.Outcome
        do throws(Receipt.Augmentation.Refusal) {
            outcome = try Receipt.Augmentation.outcome(
                base: base,
                baseReceiptDigest: baseDigest,
                run: .init(
                    id: liveRun["id"] as? Int,
                    attempt: liveRun["run_attempt"] as? Int,
                    headSha: liveRun["head_sha"] as? String,
                    event: liveRun["event"] as? String,
                    conclusion: (liveRun["conclusion"] as? String).map { Receipt.Conclusion($0) },
                    repository: (liveRun["repository"] as? [String: Any])?["full_name"] as? String,
                    workflowPath: liveRun["path"] as? String),
                status: liveRun["status"] as? String ?? "",
                attempt: attempt,
                conclusions: conclusions)
        } catch {
            FileHandle.standardError.write(Data("::error::\(error)\n".utf8))
            exit(1)
        }

        let output = value("--output", in: rest)
        // swift-linter:disable:next try optional
        // REASON: FileManager.createDirectory throws untyped; an existing directory is the common case and a real failure surfaces as the createFile refusal below.
        // swiftlint:disable:next no_try_optional
        try? FileManager.default.createDirectory(
            atPath: (output as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        let terminalPayload = Receipt.Canonical.bytes(of: outcome.attestation)
        guard FileManager.default.createFile(
            atPath: output, contents: Data(terminalPayload.map(\.underlying)))
        else { fail("runtime-receipt-augment: could not write \(output)") }
        for job in outcome.mandatoryFailures {
            FileHandle.standardError.write(
                Data(
                    ("::warning::mandatory selected job '\(job.name)' concluded "
                        + "'\(job.conclusion?.rawValue ?? "null")'\n").utf8))
        }
        print("terminal-receipt-digest=\(Receipt.Canonical.digest(of: terminalPayload))")
        print("terminal-verdict=\(outcome.attestation.verdict.rawValue)")
        exit(outcome.attestation.verdict == .met ? 0 : 1)
    }

    private static func api(_ path: String) -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        // swift-linter:disable:next try optional
        // REASON: Process.run() throws untyped; the only recovery is to report gh unavailable, which is what this does.
        // swiftlint:disable:next no_try_optional
        guard (try? process.run()) != nil else { fail("gh is not available") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 { fail("gh api \(path) failed") }
        return data
    }

    private static func object(_ data: Data) -> [String: Any] {
        // swift-linter:disable:next try optional
        // REASON: JSONSerialization.jsonObject throws untyped; an unreadable response and an empty one are refused identically downstream, by Augmentation.
        // swiftlint:disable:next no_try_optional
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
