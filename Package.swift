// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "institute-continuous-integration",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "Institute Continuous Integration",
            targets: ["Institute Continuous Integration"]
        ),
        .library(
            name: "Institute Continuous Integration Canon",
            targets: ["Institute Continuous Integration Canon"]
        ),
        .library(
            name: "Institute Continuous Integration Validation",
            targets: ["Institute Continuous Integration Validation"]
        ),
        .library(
            name: "Institute Continuous Integration Inventory",
            targets: ["Institute Continuous Integration Inventory"]
        ),
        .library(
            name: "Institute Continuous Integration Contract",
            targets: ["Institute Continuous Integration Contract"]
        ),
        .library(
            name: "Institute Continuous Integration Receipt",
            targets: ["Institute Continuous Integration Receipt"]
        ),
        .library(
            name: "Institute Continuous Integration Symbol Graph",
            targets: ["Institute Continuous Integration Symbol Graph"]
        ),
        .library(
            name: "Institute Continuous Integration Rulebook",
            targets: ["Institute Continuous Integration Rulebook"]
        ),
        .library(
            name: "Institute Continuous Integration Application",
            targets: ["Institute Continuous Integration Application"]
        ),
        .library(
            name: "Repository Policy",
            targets: ["Repository Policy"]
        ),
        .executable(
            name: "repository-policy",
            targets: ["Repository Policy CLI"]
        ),
        .executable(
            name: "institute-continuous-integration",
            targets: ["Institute Continuous Integration CLI Foundation Integration"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-foundations/swift-ascii.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-foundations/swift-continuous-integration.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-foundations/swift-github-continuous-integration.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-standards/swift-github-standard.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-byte-primitives",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-standards/swift-fips-180-4",
            branch: "main"
        ),
    ],
    targets: [
        // The Institute-policy namespace shell: `Institute` and
        // `Institute.ContinuousIntegration`, the owner of the relation
        // between continuous-integration semantics and Institute
        // doctrine.
        .target(
            name: "Institute Continuous Integration"
        ),
        // The documents this control plane distributes into every
        // package, and how they are spliced. One owner for the renderer
        // (`sync-gitignore.yml`) and the gate (`validate-gitignore.yml`),
        // which must never disagree about where canon ends.
        .target(
            name: "Institute Continuous Integration Canon",
            dependencies: [
                "Institute Continuous Integration",
                .product(name: "ASCII", package: "swift-ascii"),
            ]
        ),
        // The Institute-policy validators — skill hygiene, gitignore
        // canon, README conventions, schema correspondence, manifest
        // binding — running against the validation engine owned by
        // swift-github-continuous-integration, registered in this
        // package's own registry.
        .target(
            name: "Institute Continuous Integration Validation",
            dependencies: [
                "Institute Continuous Integration",
                "Institute Continuous Integration Canon",
                // CI-ANCHOR-001 regenerates the trust-anchor block from
                // its recorded inputs and compares. The emitter is the
                // relation's owner (Q3, swift-institute/.github#461); a
                // second copy of it here is the drift the rule exists to
                // catch.
                "Institute Continuous Integration Inventory",
                .product(name: "ASCII", package: "swift-ascii"),
                .product(
                    name: "GitHub Continuous Integration",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Workflow",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Validation",
                    package: "swift-github-continuous-integration"),
            ]
        ),
        // Describes the shipped verdict: the universal workflow's jobs,
        // postures, waves, token boundary, and single aggregate. Models
        // the terminal one-hop topology; there are no layer wrappers.
        .target(
            name: "Institute Continuous Integration Inventory",
            dependencies: [
                "Institute Continuous Integration",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Workflow",
                    package: "swift-github-continuous-integration"),
            ]
        ),
        // Copy-extracted from swift-institute/.github Tools/repository-policy
        // at closure SHA fa258c9d4038fc7014988816f3decf97e7394bed (amendment
        // 4 clause 4, .github#85 comment 5214913853). GitHub repository-level
        // policy (rulesets, action-grant surfaces, eligibility, census, and
        // the metadata-draft renderer); an independent domain from the
        // Institute-policy CI relation above, kept in its own namespace and
        // registry. Consumer rewiring in .github rides TX-APP2Z.
        .target(
            name: "Repository Policy",
            dependencies: [
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
            ]
        ),
        .executableTarget(
            name: "Repository Policy CLI",
            dependencies: ["Repository Policy"]
        ),
        // The Institute's own CI contract residue: the two typed image
        // exceptions (nightly, release floor), the calendar-date shape
        // they both bound themselves with, and the package-content
        // classifier. The vendor-neutral half of the contract — tier, leg,
        // plan, requirement, aggregate verdict — is owned by
        // swift-foundations/swift-continuous-integration; what is here is
        // the part that encodes Institute policy about which toolchains
        // this fleet tolerates and when an exception lapses.
        .target(
            name: "Institute Continuous Integration Contract",
            dependencies: [
                "Institute Continuous Integration",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
            ]
        ),
        // Canonical evidence: the bootstrap identity that binds a built
        // binary to the sources and toolchain it claims, the manifest a
        // producing run writes, and the run attestation the aggregate
        // canonicalizes and a later collector augments to a terminal
        // verdict.
        .target(
            name: "Institute Continuous Integration Receipt",
            dependencies: [
                "Institute Continuous Integration",
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
            ]
        ),
        // Umbrella symbol-graph preparation for the DocC pipeline.
        .target(
            name: "Institute Continuous Integration Symbol Graph",
            dependencies: ["Institute Continuous Integration"]
        ),
        // The rulebook checking itself: referential integrity of the
        // markdown skill corpus. Not `Institute.ContinuousIntegration
        // .Canon`, which owns the canonical documents this control plane
        // distributes — a different domain that happens to share the
        // retired script's word. No dependency on the CI contract: the
        // subject is prose, not workflows, so it keeps its own top-level
        // nest.
        .target(
            name: "Institute Continuous Integration Rulebook"
        ),
        // The layer that composes and owns no predicate: which policy
        // applies to which mechanism for one run, the union of the two
        // validator registries, and the process boundaries (event
        // payloads, the GitHub API client) a predicate may not hold.
        .target(
            name: "Institute Continuous Integration Application",
            dependencies: [
                "Institute Continuous Integration",
                "Institute Continuous Integration Contract",
                "Institute Continuous Integration Validation",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Validation",
                    package: "swift-github-continuous-integration"),
                .product(name: "GitHub Standard", package: "swift-github-standard"),
            ]
        ),
        // The narrow process boundary for the portable Gitignore canon and
        // validator. Fleet enumeration and mutation stay in .github.
        .target(
            name: "Institute Continuous Integration Command",
            dependencies: [
                .target(name: "Institute Continuous Integration"),
                .target(name: "Institute Continuous Integration Canon"),
                .target(name: "Institute Continuous Integration Validation"),
                .product(
                    name: "GitHub Continuous Integration",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Standard",
                    package: "swift-github-standard"),
                .product(
                    name: "GitHub Continuous Integration Validation",
                    package: "swift-github-continuous-integration"),
            ]
        ),
        .executableTarget(
            name: "Institute Continuous Integration CLI Foundation Integration",
            dependencies: [
                .target(name: "Institute Continuous Integration"),
                .target(name: "Institute Continuous Integration Application"),
                .target(name: "Institute Continuous Integration Command"),
                .target(name: "Institute Continuous Integration Contract"),
                .target(name: "Institute Continuous Integration Inventory"),
                .target(name: "Institute Continuous Integration Receipt"),
                .target(name: "Institute Continuous Integration Rulebook"),
                .target(name: "Institute Continuous Integration Symbol Graph"),
                .target(name: "Institute Continuous Integration Validation"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
                .product(
                    name: "GitHub Standard",
                    package: "swift-github-standard"),
                .product(
                    name: "GitHub Continuous Integration",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Validation",
                    package: "swift-github-continuous-integration"),
                .product(
                    name: "GitHub Continuous Integration Workflow",
                    package: "swift-github-continuous-integration"),
            ]
        ),
        .testTarget(
            name: "Repository Policy Tests",
            dependencies: ["Repository Policy"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "Institute Continuous Integration Canon Tests",
            dependencies: ["Institute Continuous Integration Canon"]
        ),
        .testTarget(
            name: "Institute Continuous Integration Validation Tests",
            dependencies: [
                "Institute Continuous Integration Validation",
                "Institute Continuous Integration Inventory",
            ],
            // Read from source through `#filePath`, not bundled: the
            // corpus is data the suite reads, unmodified.
            exclude: ["Fixtures"]
        ),
        .testTarget(
            name: "Institute Continuous Integration Inventory Tests",
            dependencies: ["Institute Continuous Integration Inventory"],
            // Read from source through `#filePath`, not bundled: the
            // recorded run and regenerated expectation are evidence, not
            // resources.
            exclude: ["Fixtures"]
        ),
        .testTarget(
            name: "Institute Continuous Integration Contract Tests",
            dependencies: [
                "Institute Continuous Integration Contract",
                "Institute Continuous Integration Application",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
            ]
        ),
        .testTarget(
            name: "Institute Continuous Integration Receipt Tests",
            dependencies: [
                "Institute Continuous Integration Receipt",
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
            ]
        ),
        .testTarget(
            name: "Institute Continuous Integration Rulebook Tests",
            dependencies: ["Institute Continuous Integration Rulebook"]
        ),
        .testTarget(
            name: "Institute Continuous Integration Symbol Graph Tests",
            dependencies: ["Institute Continuous Integration Symbol Graph"]
        ),
        .testTarget(
            name: "Institute Continuous Integration Application Tests",
            dependencies: [
                "Institute Continuous Integration Application",
                "Institute Continuous Integration Contract",
            ]
        ),
        .testTarget(
            name: "Institute Continuous Integration Command Tests",
            dependencies: [
                .target(name: "Institute Continuous Integration"),
                .target(name: "Institute Continuous Integration Command"),
                .target(name: "Institute Continuous Integration Validation"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
