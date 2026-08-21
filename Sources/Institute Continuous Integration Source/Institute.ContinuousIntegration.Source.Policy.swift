extension Institute.ContinuousIntegration.Source {
    public struct Policy: Sendable {
        public static let current = Self(revision: "source-enforcement-v3")

        public let revision: Swift.String
        public let requiredEngines: [SourceDomain.Engine.ID]
        public let swiftFormat: Artifact
        public let bundles: [Bundle]

        public init(revision: Swift.String) {
            self.revision = revision
            self.requiredEngines = [.init("swift-format"), .init("swift-linter")]
            self.swiftFormat = .init(
                path: ".swift-format",
                contents: Self.swiftFormatConfiguration
            )
            self.bundles = Bundle.allCases
        }

        public func linter(
            bundle: Bundle,
            rules: [SourceDomain.Rule.ID]
        ) -> Artifact {
            let document = JSON.object([
                ("revision", JSON(stringLiteral: revision)),
                ("bundle", JSON(stringLiteral: bundle.rawValue)),
                ("rules", rules.sorted(by: { $0.token < $1.token }).json),
            ])
            return .init(path: "source-linter-profile.json", contents: document.serialize(pretty: false) + "\n")
        }

        public func profile(
            swiftFormatExecutable: Swift.String,
            swiftFormatTool: SourceDomain.Profile.Digest,
            swiftFormatConfigurationPath: Swift.String,
            linterExecutable: Swift.String,
            linterTool: SourceDomain.Profile.Digest,
            linterConfigurationPath: Swift.String,
            bundle: Bundle,
            linterRules: [SourceDomain.Rule.ID]
        ) -> SourceDomain.Profile {
            let swiftFormatID = SourceDomain.Engine.ID("swift-format")
            let linterID = SourceDomain.Engine.ID("swift-linter")
            return SourceDomain.Profile(
                revision: revision,
                engines: [
                    .init(
                        id: swiftFormatID,
                        executable: swiftFormatExecutable,
                        tool: swiftFormatTool,
                        configuration: swiftFormat.digest,
                        configurationPath: swiftFormatConfigurationPath,
                        rules: [.init(engine: swiftFormatID, token: "format")]
                    ),
                    .init(
                        id: linterID,
                        executable: linterExecutable,
                        tool: linterTool,
                        configuration: linter(bundle: bundle, rules: linterRules).digest,
                        configurationPath: linterConfigurationPath,
                        environment: ["SWIFT_LINTER_BUNDLE": bundle.rawValue],
                        rules: linterRules
                    ),
                ]
            )
        }
    }
}
