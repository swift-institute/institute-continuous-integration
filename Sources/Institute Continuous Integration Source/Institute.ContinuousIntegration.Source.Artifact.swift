internal import Byte_Primitives
internal import FIPS_180_4
internal import Institute_Continuous_Integration

extension Institute.ContinuousIntegration.Source {
    public struct Artifact: Equatable, Sendable {
        public let path: Swift.String
        public let contents: Swift.String
        public let digest: SourceDomain.Profile.Digest

        public init(path: Swift.String, contents: Swift.String) {
            self.path = path
            self.contents = contents
            self.digest = .init(
                FIPS_180_4.SHA256.digest(contents.utf8.map(Byte.init)).hex
            )
        }
    }
}
