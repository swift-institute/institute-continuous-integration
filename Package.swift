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
        // Institute policy over the generic plan: the two typed toolchain
        // exceptions and the package-content classifier. The generic owner
        // decides which legs a tier selects; this target decides what
        // Institute policy makes unschedulable, and why.
        .target(
            name: "Institute Continuous Integration Contract",
            dependencies: [
                "Institute Continuous Integration",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
            ]
        ),
        // The process-boundary half: GitHub event-diff retrieval and the
        // bootstrap provenance record. Foundation and the network live
        // here, never in the contract above.
        .target(
            name: "Institute Continuous Integration Application",
            dependencies: [
                "Institute Continuous Integration",
                "Institute Continuous Integration Contract",
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "FIPS 180-4", package: "swift-fips-180-4"),
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
                .target(name: "Institute Continuous Integration Validation"),
                .product(
                    name: "Continuous Integration",
                    package: "swift-continuous-integration"),
                .product(
                    name: "GitHub Standard",
                    package: "swift-github-standard"),
                .product(
                    name: "GitHub Continuous Integration Validation",
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
