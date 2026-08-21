internal import Byte_Primitives
internal import FIPS_180_4
public import Institute_Continuous_Integration
public import Source_Profile

extension ContinuousIntegration.Source {
    public struct Artifact: Equatable, Sendable {
        public let path: Swift.String
        public let contents: Swift.String
        public let digest: Source_Profile.Source.Profile.Digest

        public init(path: Swift.String, contents: Swift.String) {
            self.path = path
            self.contents = contents
            self.digest = .init(
                FIPS_180_4.SHA256.digest(contents.utf8.map(Byte.init)).hex
            )
        }
    }
}
