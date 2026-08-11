import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Canon
import Testing

@testable import Institute_Continuous_Integration_Validation

@Suite
struct CIValidationGitignoreTests {
    typealias Gitignore = Institute.ContinuousIntegration.Validation.Gitignore
    typealias Class = Institute.ContinuousIntegration.Canon.Gitignore.Class

    /// The real class canon, found the way the validator finds it. A
    /// hand-written stand-in would test the test.
    static func canon(for class: Class) throws -> String {
        let package = try #require(Gitignore.resolvedCanonPath)
        let path =
            (package as NSString).deletingLastPathComponent
            + "/" + (`class`.canonPath as NSString).lastPathComponent
        return try #require(Gitignore.read(path))
    }

    static func repository() throws -> TemporaryRepository {
        let repository = TemporaryRepository()
        #expect(try repository.git(["init", "-q"]) == 0)
        return repository
    }

    @Suite
    struct Unit {
        @Test func `the validator is registered for all four of its rules`() {
            for rule in ["GH-IGNORE-001", "GH-IGNORE-002", "GH-IGNORE-003", "GH-IGNORE-004"]
                as [GitHub.ContinuousIntegration.Validation.Rule]
            {
                #expect(Institute.ContinuousIntegration.Validation.Registry.validator(for: rule) is Gitignore)
            }
        }

        @Test(arguments: Class.allCases)
        func `each class canon keeps its work, denies junk, and denies the unadmitted`(
            `class`: Class
        ) throws {
            // The gate's three halves in one measurement per class,
            // asked of git rather than of the patterns: reading the
            // patterns and reasoning about them is how the premise of
            // this gate came to be wrong in the first place.
            let work = Gitignore.work(for: `class`)
            let ignored = try Gitignore.ignored(
                under: CIValidationGitignoreTests.canon(for: `class`),
                probes: work + Gitignore.junk + Gitignore.unadmitted)
            for probe in work {
                #expect(!ignored.contains(probe.path), "\(`class`) work denied: \(probe.path)")
            }
            for probe in Gitignore.junk {
                #expect(ignored.contains(probe.path), "\(`class`) junk tracked: \(probe.path)")
            }
            for probe in Gitignore.unadmitted {
                #expect(
                    ignored.contains(probe.path),
                    "\(`class`) admits the unadmitted: \(probe.path)")
            }
        }

        @Test func `a manifest makes a layer repository the package class`() {
            #expect(Class.of(repository: "swift-primitives/swift-byte-primitives", manifest: "// swift-tools-version: 6.3") == .package)
        }

        @Test func `no manifest makes a layer repository the scaffold class`() {
            #expect(Class.of(repository: "swift-standards/swift-yaml-standard", manifest: nil) == .scaffold)
        }

        @Test func `the control plane org is the institute class, manifest or not`() {
            #expect(Class.of(repository: "swift-institute/.github", manifest: nil) == .institute)
            #expect(Class.of(repository: "swift-institute/institute", manifest: "// swift-tools-version: 6.3") == .institute)
        }

        @Test func `a generation target is the generator class`() {
            #expect(Class.of(repository: "swift-standards/x", manifest: #".target(name: "HTML Generation")"#) == .generator)
        }

        @Test func `a conformant package repository is clean`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(try CIValidationGitignoreTests.canon(for: .package), to: ".gitignore")
            #expect(try Gitignore().findings(in: repository.subject).isEmpty)
        }

        @Test func `a conformant scaffold repository is clean`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("# reserved", to: "README.md")
            repository.write(try CIValidationGitignoreTests.canon(for: .scaffold), to: ".gitignore")
            #expect(try Gitignore().findings(in: repository.subject).isEmpty)
        }

        @Test func `a scaffold with no gitignore fires conformance`() throws {
            // A repository without a manifest is a subject now: the
            // scaffold class holds it to the scaffold canon.
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("# reserved", to: "README.md")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.map(\.rule) == ["GH-IGNORE-001"])
            #expect(findings.first?.message.contains("scaffold") == true)
        }

        @Test func `a force added ignored stage zero path fires indexed coverage`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(try CIValidationGitignoreTests.canon(for: .package), to: ".gitignore")
            repository.write("evidence", to: ".build/force added.txt")
            #expect(try repository.git(["add", ".gitignore", "Package.swift"]) == 0)
            #expect(try repository.git(["add", "--force", "--", ".build/force added.txt"]) == 0)
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains {
                $0.rule == "GH-IGNORE-004" && $0.message.contains(".build/force added.txt")
            })
        }

        @Test func `no index is load bearing for a force added ignored path`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("/*\n", to: ".gitignore")
            repository.write("evidence", to: "forced path\nwith newline.txt")
            #expect(try repository.git(["add", "--force", "--", "forced path\nwith newline.txt"]) == 0)
            let paths = try Gitignore.indexedPaths(in: repository.root)
            #expect(paths == ["forced path\nwith newline.txt"])
            #expect(try Gitignore.ignoredIndexedPaths(paths, in: repository.root) == paths)
            #expect(try Gitignore.ignoredIndexedPaths(paths, in: repository.root, noIndex: false).isEmpty)
        }

        @Test
        func `an ambient alternate empty index cannot hide the real index`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("/*\n", to: ".gitignore")
            repository.write("evidence", to: "tracked.txt")
            #expect(try repository.git(["add", "--force", "tracked.txt"]) == 0)
            #expect(try repository.git(
                ["read-tree", "--empty"],
                environment: ["GIT_INDEX_FILE": repository.path("alternate-index")]) == 0)

            #expect(try Gitignore.indexedPaths(
                in: repository.root,
                environment: ["GIT_INDEX_FILE": repository.path("alternate-index")]
            ) == ["tracked.txt"])
        }

        @Test func `ignored index transport exceeds pipe capacity without blocking`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("/*\n!/kept.txt\n", to: ".gitignore")
            let paths = (0..<20_000).map { "generated/path-\($0)-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.txt" }
            #expect(try Gitignore.ignoredIndexedPaths(paths, in: repository.root) == paths)
            #expect(try Gitignore.ignoredIndexedPaths(["kept.txt"], in: repository.root).isEmpty)
        }

        @Test func `declared nested packages require exact generated nested policy`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(try CIValidationGitignoreTests.canon(for: .package), to: ".gitignore")
            repository.write("// swift-tools-version: 6.3", to: "Tests/Package.swift")
            var findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains { $0.rule == "GH-IGNORE-001" && $0.message.contains("Tests/.gitignore") })
            repository.write(Institute.ContinuousIntegration.Canon.Gitignore.Nested.text, to: "Tests/.gitignore")
            findings = try Gitignore().findings(in: repository.subject)
            #expect(!findings.contains { $0.rule == "GH-IGNORE-001" })
        }

        @Test func `a handwritten tail fires complete policy conformance`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(
                try CIValidationGitignoreTests.canon(for: .package) + "# local tail\n",
                to: ".gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains {
                $0.rule == "GH-IGNORE-001" && $0.message.contains("handwritten tails")
            })
        }

        @Test func `undeclared nested policy fires complete policy conformance`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(try CIValidationGitignoreTests.canon(for: .package), to: ".gitignore")
            repository.write("*.tmp\n", to: "Sources/Feature/.gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains {
                $0.rule == "GH-IGNORE-001" && $0.message.contains("Sources/Feature/.gitignore")
            })
        }
    }

    @Suite
    struct `Edge Case` {
        @Test func `one extra allow is a near miss and fires conformance`() throws {
            // A whitelist admitting one path more than its class canon
            // is not that canon. Near-conformant must read as divergent,
            // or the whitelist stops being deny-by-default one admitted
            // path at a time.
            let canon = try CIValidationGitignoreTests.canon(for: .package)
            let widened = canon.replacingOccurrences(
                of: "!/Lint/\n", with: "!/Lint/\n!/Extra/\n")
            #expect(widened != canon)
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(widened, to: ".gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains { $0.rule == "GH-IGNORE-001" })
            // And behaviorally: the extra path really would be tracked.
            let ignored = try Gitignore.ignored(
                under: widened, probes: [.init("Extra/leak.txt")])
            #expect(!ignored.contains("Extra/leak.txt"))
        }

        @Test func `a deny-listing file is not deny-by-default and fires shape`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(".build/\n.DS_Store\n", to: ".gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains { $0.rule == "GH-IGNORE-003" })
        }

        @Test func `a conformant file has no shape finding to give`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write(try CIValidationGitignoreTests.canon(for: .package), to: ".gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(!findings.contains { $0.rule == "GH-IGNORE-003" })
        }

        @Test func `the junk control is what makes a clean verdict evidence`() throws {
            // An empty ignore file denies nothing, so every work probe
            // "survives" and every 002 pass would be vacuous. The control
            // is the only thing that catches it.
            let ignored = try Gitignore.ignored(
                under: "", probes: Gitignore.work(for: .package) + Gitignore.junk)
            #expect(ignored.isEmpty)
            let tracked = Gitignore.junk.filter { !ignored.contains($0.path) }
            #expect(tracked.count == Gitignore.junk.count)
        }

        @Test func `the sweep fires on itself when the allow set breaks`() throws {
            // Self-firing control for the whole rule family: a repository
            // whose file is an empty whitelist must produce a junk-control
            // 002 finding AND a 003 finding — a run in which neither can
            // fire is not measuring.
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            repository.write("", to: ".gitignore")
            let findings = try Gitignore().findings(in: repository.subject)
            #expect(findings.contains { $0.rule == "GH-IGNORE-002" && $0.message.contains("probe control failed") })
            #expect(findings.contains { $0.rule == "GH-IGNORE-003" })
        }

        @Test func `the gitignore under test is not truncated by its own probe`() throws {
            // `.gitignore` is itself a work probe. Materialising probes
            // as empty files after writing it would blank the very file
            // under test, and every verdict in the run would reflect an
            // empty whitelist.
            let ignored = try Gitignore.ignored(
                under: "/*\n", probes: Gitignore.work(for: .package))
            #expect(ignored.contains("Sources/Core/Type.swift"))
        }

        @Test func `a nonexistent root is out of scope, not a finding`() throws {
            // The harness only asks about checkouts; a root that is not
            // there is not a repository of any class.
            let validator = Gitignore()
            let findings = try validator.findings(
                in: .init(repository: "swift-institute/Skills", root: "/nonexistent"))
            #expect(findings.isEmpty)
        }

        @Test func `an unreadable canon is a defect, not a finding`() {
            let repository = TemporaryRepository()
            repository.write("// swift-tools-version: 6.3", to: "Package.swift")
            let validator = Gitignore(canon: "/nonexistent/canon/gitignore-package.txt")
            let run = GitHub.ContinuousIntegration.Validation.Run.validate(
                validator, of: repository.subject)
            #expect(run.findings.isEmpty)
            #expect(run.exitCode == GitHub.ContinuousIntegration.Validation.EnvironmentDefect.exitCode)
        }


        @Test func `ambient repository exclude policy is an environment defect`() throws {
            let repository = try CIValidationGitignoreTests.repository()
            repository.write("ignored-by-ambient\n", to: ".git/info/exclude")
            repository.write("tracked", to: "tracked.txt")
            #expect(try repository.git(["add", "--force", "tracked.txt"]) == 0)
            let run = GitHub.ContinuousIntegration.Validation.Run.validate(
                Gitignore(), of: repository.subject)
            #expect(run.findings.isEmpty)
            #expect(run.exitCode == GitHub.ContinuousIntegration.Validation.EnvironmentDefect.exitCode)
        }
    }

    @Suite
    struct Integration {
        @Test func `wider classes contain every package admission`() throws {
            // The exception classes widen the package whitelist; they
            // never narrow it. Every path the package class keeps, the
            // institute, application, and generator classes keep too —
            // measured through git, not read off the patterns.
            let packageWork = Gitignore.work(for: .package)
            for `class`: Class in [.institute, .application, .generator] {
                let ignored = try Gitignore.ignored(
                    under: CIValidationGitignoreTests.canon(for: `class`),
                    probes: packageWork)
                for probe in packageWork {
                    #expect(
                        !ignored.contains(probe.path),
                        "\(`class`) narrows the package class: \(probe.path)")
                }
            }
        }
    }
}
