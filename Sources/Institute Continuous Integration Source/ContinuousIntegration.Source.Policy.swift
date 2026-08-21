public import Institute_Continuous_Integration
public import Source_Profile

extension ContinuousIntegration.Source {
    public struct Policy: Sendable {
        public static let current = Self(revision: "source-enforcement-v3")

        public let revision: Swift.String
        public let requiredEngines: [Source_Profile.Source.Engine.ID]
        public let swiftFormat: Artifact
        public let bundles: [Bundle]
        public let commitment: Commitment
        public let configuration: Configuration

        public init(revision: Swift.String) {
            self.revision = revision
            self.requiredEngines = [.init("swift-format"), .init("swift-linter")]
            self.swiftFormat = .init(
                path: ".swift-format",
                contents: Self.swiftFormatConfiguration,
                schema: "swift-format:1"
            )
            self.bundles = Bundle.allCases
            self.commitment = .init(
                repositories: [
                    "swift-foundations/swift-linter",
                    "swift-foundations/swift-linter-rules",
                    "swift-foundations/swift-institute-linter-rules",
                    "swift-foundations/swift-source",
                    "swift-primitives/swift-linter-primitives",
                    "swift-primitives/swift-primitives-linter-rules",
                    "swift-primitives/swift-source-primitives",
                    "swift-standards/swift-standards-linter-rules",
                ],
                controls: ["application", "institute", "continuous-integration"],
                rule: .init(suffix: "-linter-rules")
            )
            let engine = Source_Profile.Source.Engine.ID("source-policy")
            self.configuration = .init(
                engine: engine,
                predicate: .init(engine: engine, token: "exact-configuration")
            )
        }

        public func linter(
            bundle: Bundle,
            rules: [Source_Profile.Source.Rule.ID]
        ) -> Artifact {
            let document = JSON.object([
                ("schema", 1),
                ("revision", JSON(stringLiteral: revision)),
                ("bundle", JSON(stringLiteral: bundle.token)),
                ("rules", rules.sorted(by: { $0.token < $1.token }).json),
            ])
            return .init(
                path: "source-linter-profile.json",
                contents: document.serialize(pretty: false) + "\n",
                schema: "swift-linter-profile:1"
            )
        }

        public func profile(
            swiftFormatExecutable: Swift.String,
            swiftFormatTool: Source_Profile.Source.Profile.Digest,
            swiftFormatConfigurationPath: Swift.String,
            linterExecutable: Swift.String,
            linterTool: Source_Profile.Source.Profile.Digest,
            linterConfigurationPath: Swift.String,
            bundle: Bundle,
            linterRules: [Source_Profile.Source.Rule.ID]
        ) -> Source_Profile.Source.Profile {
            let swiftFormatID = Source_Profile.Source.Engine.ID("swift-format")
            let linterID = Source_Profile.Source.Engine.ID("swift-linter")
            return Source_Profile.Source.Profile(
                revision: revision,
                engines: [
                    .init(
                        id: swiftFormatID,
                        executable: swiftFormatExecutable,
                        tool: swiftFormatTool,
                        configuration: swiftFormat.digest,
                        configurationPath: swiftFormatConfigurationPath,
                        artifactKinds: [.swift],
                        rules: [.init(engine: swiftFormatID, token: "format")]
                    ),
                    .init(
                        id: linterID,
                        executable: linterExecutable,
                        tool: linterTool,
                        configuration: linter(bundle: bundle, rules: linterRules).digest,
                        configurationPath: linterConfigurationPath,
                        environment: ["SWIFT_LINTER_BUNDLE": bundle.token],
                        artifactKinds: [.swift],
                        rules: linterRules
                    ),
                ]
            )
        }
    }
}
