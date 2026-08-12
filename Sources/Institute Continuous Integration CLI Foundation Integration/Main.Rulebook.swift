// Licensed under the Apache License, Version 2.0.

import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Rulebook

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// The canon guard. One semantic, one command: the retired wrapper's
    /// contribution was the sanctioned root set and the developer-root
    /// derivation, and that is argument defaulting, which lives here.
    static func checkCanon(_ rest: [String]) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let developerRoot =
            value("--dev-root", in: rest).isEmpty
            ? "\(home)/Developer" : value("--dev-root", in: rest)
        // The three unified gate roots plus Workspace/CLAUDE.md, per the
        // 2026-07-05 gate-root unification ruling.
        let declaredRoots = values("--root", in: rest).compactMap(aliased)
        let roots =
            declaredRoots.isEmpty
            ? [
                (alias: "institute", path: "\(developerRoot)/swift-institute/Skills"),
                (alias: "engagement", path: "\(developerRoot)/swift-institute/Engagement/Skills"),
                (alias: "rule", path: "\(developerRoot)/rule-institute/Skills"),
            ]
            : declaredRoots
        let declaredFiles = values("--file", in: rest).compactMap(aliased)
        let files =
            declaredRoots.isEmpty && declaredFiles.isEmpty
            ? [
                (
                    alias: "workspace:CLAUDE.md",
                    path: "\(developerRoot)/swift-institute/Workspace/CLAUDE.md"
                )
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
            : declaredFiles
        let corpus = Rulebook.Corpus.read(roots: roots, files: files)
        guard !corpus.documents.isEmpty else {
            // Exit 2, not a clean report. A run that found no corpus has
            // measured nothing, and reporting zero findings would be the
            // silent no-op every gate in this repository exists to prevent.
            FileHandle.standardError.write(
                Data("::error::check-canon: no corpus files found\n".utf8))
            exit(2)
        }
        let configuration =
            value("--configuration", in: rest).isEmpty
            ? ".github/scripts" : value("--configuration", in: rest)
        let audit = Rulebook.Audit(
            corpus: corpus,
            baseline: .read(at: "\(configuration)/.check-canon-baseline"),
            allowlist: .read(at: "\(configuration)/.check-canon-allowlist"),
            developerRoot: developerRoot)
        let selected = values("--check", in: rest).compactMap(Rulebook.Check.init(rawValue:))
        let report = audit.run(selected.isEmpty ? nil : selected)
        if rest.contains("--emit-baseline") {
            for entry in report.baselineEntries { print(entry) }
            exit(0)
        }
        let enforcing = rest.contains("--enforce")
        for line in report.lines(enforcing: enforcing) { print(line) }
        // `--enforce` keeps exit 1 on a non-baselined finding. The 0/2
        // normalisation the port adopted applies to validators aggregated
        // by the base sweep; this is a standalone gate whose caller aborts
        // a corpus sync on that 1, and normalising it away would silently
        // disarm the gate.
        exit(enforcing && !report.isClean ? 1 : 0)
    }

    /// The rule-count face. Counts; does not judge.
    static func canonRuleCount(_ rest: [String]) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let declared = values("--root", in: rest)
        let roots =
            (declared.isEmpty
            ? [
                "\(home)/Developer/swift-institute/Skills",
                "\(home)/Developer/swift-primitives/Skills",
                "\(home)/Developer/swift-primitives/swift-memory-primitives/Skills",
                "\(home)/Developer/swift-primitives/swift-index-primitives/Skills",
            ]
            : declared)
            .filter { path in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
            }
        do throws(Rulebook.Census.Error) {
            let census = try Rulebook.Census.taken(over: roots)
            print("Skill rule count across \(roots.count) root(s):")
            print("  heading-form (### [ID]): \(census.headingForm)")
            print("  table-row form  (| [ID] |): \(census.tableForm)")
            print("  union (per [SKILL-CREATE-005c]): \(census.union)")
        } catch {
            FileHandle.standardError.write(Data("::error::no skill roots found\n".utf8))
            exit(2)
        }
    }
}
