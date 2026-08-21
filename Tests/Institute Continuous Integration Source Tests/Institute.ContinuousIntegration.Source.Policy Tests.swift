import Institute_Continuous_Integration_Source
import Testing

@Suite
struct `Institute source policy` {
    @Test
    func `terminal policy requires only formatter and linter`() {
        let policy = Institute.ContinuousIntegration.Source.Policy.current
        #expect(policy.requiredEngines.map(\.token) == ["swift-format", "swift-linter"])
        #expect(!policy.swiftFormat.contents.isEmpty)
        #expect(policy.swiftFormat.path == ".swift-format")
        #expect(policy.bundles == [.primitives, .standards, .institute])
    }

    @Test
    func `profile binds tool configuration and exact rules`() {
        let policy = Institute.ContinuousIntegration.Source.Policy.current
        let linter = Source.Engine.ID("swift-linter")
        let rules = [Source.Rule.ID(engine: linter, token: "rule")]
        let profile = policy.profile(
            swiftFormatExecutable: "/swift-format",
            swiftFormatTool: .init("format-tool"),
            linterExecutable: "/swift-linter",
            linterTool: .init("linter-tool"),
            bundle: .institute,
            linterRules: rules
        )
        #expect(profile.engines.map(\.id.token) == ["swift-format", "swift-linter"])
        #expect(profile.engines[0].rules.map(\.token) == ["format"])
        #expect(profile.engines[1].rules == rules)
        #expect(
            profile.digest
                == policy.profile(
                    swiftFormatExecutable: "/swift-format",
                    swiftFormatTool: .init("format-tool"),
                    linterExecutable: "/swift-linter",
                    linterTool: .init("linter-tool"),
                    bundle: .institute,
                    linterRules: rules
                ).digest
        )
    }
}
