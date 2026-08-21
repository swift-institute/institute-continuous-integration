public import Institute_Continuous_Integration

extension ContinuousIntegration.Source.Policy {
    public enum Platform: Sendable {
        case linuxX86_64
        case macOSARM64
    }
}

extension ContinuousIntegration.Source.Policy.Platform {
    public var token: Swift.String {
        switch self {
        case .linuxX86_64: "linux-x86_64"
        case .macOSARM64: "macos-arm64"
        }
    }
}
