import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Canon

extension Institute.ContinuousIntegration.Validation {
    /// `[GH-IGNORE-001]` / `[GH-IGNORE-002]` / `[GH-IGNORE-003]` — the
    /// canonical `.gitignore` for a repository's class, the work it must
    /// not deny, and the deny-by-default shape it must keep.
    ///
    /// **001** is conformance: the file's canonical half must match
    /// `canon/gitignore-<class>.txt` byte-for-byte for the repository's
    /// class — `Canon.Gitignore.Class` decides which — and the file must
    /// have such a half. Content after the terminator is the package's
    /// own and is not compared. A whitelist that admits one path more
    /// than its class canon is a byte away from canon and fires here;
    /// near-conformant is not conformant.
    ///
    /// **002 is the half that matters.** A whitelist inverts the failure
    /// mode. Before it, junk crept in and `git status` showed you; after
    /// it, anything not explicitly allowed is untracked and `git status`
    /// says *nothing* — on 2026-07-29 a research paper in this ecosystem
    /// existed only as an untracked directory, one `git clean` from being
    /// lost. A validator that asks only "is junk denied?" would have
    /// reported that repository clean. This one also asks "is real work
    /// still tracked?", which is what makes work-loss loud. Do not weaken
    /// it to a warning, and when a class whitelist gains a directory, add
    /// a probe for it here in the same change.
    ///
    /// **003** is shape: deny-by-default, proven behaviorally. A path no
    /// class admits must come back ignored; if it survives, the file is
    /// not a whitelist regardless of what its patterns look like. 001
    /// already implies this for a conformant file — 003 exists so a
    /// divergent or pre-canonical file is measured on its own shape, and
    /// so a canon edit that broke deny-by-default would fire the corpus
    /// before it shipped.
    ///
    /// All three evaluate the file **the way git will**: it is copied
    /// into a throwaway `git init` tree with the probe paths
    /// materialised, and `git check-ignore` decides. Reading the patterns
    /// and reasoning about them is how the premise of this gate came to
    /// be wrong in the first place — the absence of a `.swift-lint`
    /// deny-line was read as the absence of denial, when the whitelist
    /// was denying it all along.
    public struct Gitignore: Validator {
        public typealias Class = Institute.ContinuousIntegration.Canon.Gitignore.Class

        /// A path the whitelist is probed with, and whether git must be
        /// told it is a directory.
        ///
        /// The directory bit is carried because a pattern with a trailing
        /// slash — `**/.*/` — never matches a path git does not know to
        /// be one.
        public struct Probe: Sendable, Equatable {
            public let path: String
            public let isDirectory: Bool

            public init(_ path: String, isDirectory: Bool = false) {
                self.path = path
                self.isDirectory = isDirectory
            }
        }

        /// Paths every class must keep: the repository's own floor.
        public static let floor: [Probe] = [
            Probe("README.md"),
            Probe("LICENSE.md"),
            Probe(".github/workflows/ci.yml"),
            Probe(".gitignore"),
        ]

        /// Paths that carry package work. Every package-shaped class
        /// must keep all of them.
        public static let packageWork: [Probe] = [
            Probe("Sources/Core/Type.swift"),
            Probe("Sources/Core/Type.docc/Article.md"),
            Probe("Sources/Core/Type.docc/asset.png"),
            Probe("Tests/Core Tests/Type Tests.swift"),
            Probe("Tests/Core Tests/Fixtures/case.json"),
            Probe("Benchmarks/bench/main.swift"),
            Probe("Research/paper.md"),
            Probe("Experiments/probe/main.swift"),
            Probe("Package.swift"),
            Probe("Lint.swift"),
            Probe(".spi.yml"),
        ]

        /// Paths that carry real work for a class. Every one must
        /// survive that class's whitelist.
        public static func work(for class: Class) -> [Probe] {
            switch `class` {
            case .package:
                floor + packageWork
            case .scaffold:
                floor
            case .institute:
                floor + packageWork + [
                    Probe("canon/gitignore-package.txt"),
                    Probe("Policy/whitelist.json"),
                    Probe("Tools/tool/Package.swift"),
                    Probe("profile/README.md"),
                    Probe("RULINGS.md"),
                ]
            case .application:
                floor + packageWork + [
                    Probe("Public/favicon.ico"),
                    Probe("Resources/Views/page.html"),
                    Probe("Configuration/production.json"),
                    Probe(".env.example"),
                ]
            case .generator:
                floor + packageWork + [
                    Probe("Generation/main.swift")
                ]
            }
        }

        /// Paths that must be denied. Not a rule of its own — a positive
        /// control on the probe harness. If these come back tracked,
        /// `git check-ignore` is not being reached and every 002 pass in
        /// the run is vacuous, which is exactly the shape of green this
        /// ecosystem has been burned by.
        public static let junk: [Probe] = [
            Probe(".swift-lint/eval/Package.swift"),
            Probe("Sources/.swift-lint/manifest.json"),
            Probe(".build/debug/thing.o"),
        ]

        /// Paths no class admits. Each must come back ignored, or the
        /// file is not deny-by-default and `[GH-IGNORE-003]` fires. The
        /// spelling is deliberately unguessable so no class canon — nor
        /// any plausible local override — ever admits it.
        public static let unadmitted: [Probe] = [
            Probe("Unadmitted-GH-IGNORE-003/probe.txt"),
            Probe("unadmitted-gh-ignore-003.txt"),
        ]

        public let rules: [Rule] = ["GH-IGNORE-001", "GH-IGNORE-002", "GH-IGNORE-003"]
        public let retiredScript: String? = ".github/scripts/validate-gitignore.py"

        /// The package-class canon's path within the control-plane
        /// checkout. The other classes' documents are its siblings.
        public static let canonPath = "canon/gitignore-package.txt"

        /// Where the package-class canon lives. `nil` means *find it*:
        /// the working directory and each of its ancestors are searched
        /// for `canonPath`.
        ///
        /// The retired script resolved canon from its own location
        /// (`__file__/../../canon/…`), which a Swift executable cannot
        /// reproduce — a built binary is not in the checkout it validates,
        /// and under `swift test` it is not in one at all. Searching
        /// upward from the working directory answers the same question
        /// the same way for the harness, for `validate-gitignore.yml`, and
        /// for a developer running from anywhere inside the checkout.
        public let canon: String?

        public init(canon: String? = nil) {
            self.canon = canon
        }

        public func findings(in subject: Subject) throws(EnvironmentDefect) -> [Finding] {
            // A root that is not there is not a repository of any class.
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: subject.root, isDirectory: &isDirectory),
                isDirectory.boolValue
            else { return [] }

            let `class` = Class.of(
                repository: subject.repository,
                manifest: Self.read(subject.path("Package.swift")))
            let path = canon ?? Self.resolvedCanonPath ?? Self.canonPath
            let classPath = (path as NSString).deletingLastPathComponent
                + "/" + (`class`.canonPath as NSString).lastPathComponent
            guard let canonText = Self.read(classPath) else {
                throw .missingSupportFile(path: classPath)
            }
            guard let canonical = Institute.ContinuousIntegration.Canon.Gitignore(canonText).canonical else {
                throw .missingSupportFile(path: classPath)
            }

            let conformance = rules[0]
            let workLoss = rules[1]
            let shape = rules[2]
            guard let text = Self.read(subject.path(".gitignore")) else {
                return [
                    Finding(
                        repository: subject.repository, rule: conformance,
                        message: "no .gitignore; the canonical \(`class`.rawValue)-class "
                            + "whitelist is absent")
                ]
            }

            var findings: [Finding] = []
            switch Institute.ContinuousIntegration.Canon.Gitignore(text).canonical {
            case .none:
                findings.append(
                    Finding(
                        repository: subject.repository, rule: conformance,
                        message: "no CANONICAL section; file predates the canonical whitelist"))

            case .some(let section) where section != canonical:
                findings.append(
                    Finding(
                        repository: subject.repository, rule: conformance,
                        message: "CANONICAL section diverges from \(`class`.canonPath) "
                            + "(class: \(`class`.rawValue))"))

            case .some:
                break
            }

            // 002 and 003 evaluate the repository's ACTUAL file,
            // canonical or not — a divergent file that loses real work or
            // admits the unadmitted should say so on its own terms, not
            // only via 001.
            let work = Self.work(for: `class`)
            let ignored = try Self.ignored(
                under: text, probes: work + Self.junk + Self.unadmitted)
            for probe in work where ignored.contains(probe.path) {
                findings.append(
                    Finding(
                        repository: subject.repository, rule: workLoss,
                        message: "whitelist denies real work: `\(probe.path)` "
                            + "would be silently untracked"))
            }
            let tracked = Self.junk.filter { !ignored.contains($0.path) }
            if !tracked.isEmpty {
                // The control failed. Reported as a finding rather than
                // passed: a harness that cannot detect denial makes every
                // clean 002 above vacuous.
                findings.append(
                    Finding(
                        repository: subject.repository, rule: workLoss,
                        message: "probe control failed — tool state not denied ("
                            + tracked.map { "`\($0.path)`" }.joined(separator: ", ")
                            + "); this run's whitelist verdicts are not evidence"))
            }
            for probe in Self.unadmitted where !ignored.contains(probe.path) {
                findings.append(
                    Finding(
                        repository: subject.repository, rule: shape,
                        message: "not deny-by-default: unadmitted path `\(probe.path)` "
                            + "would be tracked"))
            }
            return findings
        }
    }
}

extension Institute.ContinuousIntegration.Validation.Gitignore {
    /// `canonPath` found by walking up from the working directory, or
    /// `nil` when no ancestor carries it.
    static var resolvedCanonPath: String? {
        resolvedCanonPath(startingAt: FileManager.default.currentDirectoryPath)
            // The canon rides its owner: this package carries the
            // authoritative `canon/gitignore-package.txt` at its own
            // root, so a caller whose working directory is elsewhere —
            // a test runner, a consumer package — still resolves the
            // document this validator was built against.
            ?? resolvedCanonPath(startingAt: (#filePath as NSString).deletingLastPathComponent)
    }

    /// `canonPath` found by walking up from `directory`, or `nil` when
    /// no ancestor carries it.
    static func resolvedCanonPath(startingAt start: String) -> String? {
        var directory = start
        while !directory.isEmpty, directory != "/" {
            let candidate = "\(directory)/\(canonPath)"
            if read(candidate) != nil { return candidate }
            directory = (directory as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// The text of a file, or `nil` when it is absent or is not a file.
    static func read(_ path: String) -> String? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            !isDirectory.boolValue,
            let data = FileManager.default.contents(atPath: path)
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Which probes the given `.gitignore` ignores, asked of git itself
    /// in a throwaway tree.
    ///
    /// - Throws: `EnvironmentDefect.missingSupportFile` when git cannot
    ///   be run or answers with neither of its two verdicts. The retired
    ///   script reported that as a `[GH-IGNORE-002]` *finding*, which
    ///   said a repository was defective when the machine was; under this
    ///   contract an unanswerable question is the exit-2 class. This is a
    ///   deliberate difference and it is unreachable on a working runner.
    static func ignored(
        under gitignore: String, probes: [Probe]
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> Set<String> {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "ci-validation-gitignore-\(UUID().uuidString)")
        // `FileManager.removeItem(at:)` throws untyped, and a scratch
        // tree that outlives the probe is not a verdict about anything.
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                // Nothing depends on the scratch tree after this probe.
            }
        }

        for probe in probes {
            let target = root.appending(path: probe.path)
            let directory = probe.isDirectory ? target : target.deletingLastPathComponent()
            // `FileManager.createDirectory` throws untyped; its failure
            // here is exactly the defect raised in the catch.
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true)
            } catch {
                throw .unreadableSubject(root: root.path)
            }
            if !probe.isDirectory {
                FileManager.default.createFile(atPath: target.path, contents: Data())
            }
        }
        // LAST, and deliberately so: `.gitignore` is itself a probe —
        // the file must not ignore itself — and materialising probes
        // as empty files would otherwise truncate the very file under
        // test. Every verdict in the run would then reflect an empty
        // ignore file, so all junk reads as tracked and all work
        // reads as kept. The junk control caught exactly this.
        // `Data.write(to:options:)` throws untyped; its failure here is
        // exactly the defect raised in the catch.
        do {
            try Data(gitignore.utf8).write(
                to: root.appending(path: ".gitignore"), options: .atomic)
        } catch {
            throw .unreadableSubject(root: root.path)
        }

        guard try git(["init", "-q", "."], in: root) == 0 else {
            throw .missingSupportFile(path: "git init")
        }
        var ignored: Set<String> = []
        for probe in probes {
            // 0 = ignored, 1 = not ignored, >1 = git itself failed.
            let status = try git(["check-ignore", "-q", "--", probe.path], in: root)
            guard status <= 1 else {
                throw .missingSupportFile(path: "git check-ignore \(probe.path)")
            }
            if status == 0 { ignored.insert(probe.path) }
        }
        return ignored
    }

    /// One `git` invocation in the throwaway tree, returning its status.
    private static func git(
        _ arguments: [String], in root: URL
    ) throws(GitHub.ContinuousIntegration.Validation.EnvironmentDefect) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = root
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // `Process.run()` is an untyped cross-module throw; its only
        // failure here is "git is not on this machine", which is the
        // defect raised in the catch.
        do {
            try process.run()
        } catch {
            throw .missingSupportFile(path: "git")
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
