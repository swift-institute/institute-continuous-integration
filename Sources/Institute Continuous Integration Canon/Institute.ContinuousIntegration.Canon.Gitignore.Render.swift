import Institute_Continuous_Integration

extension Institute.ContinuousIntegration.Canon.Gitignore {
    /// The propagation half of the gitignore pair — the Swift owner of
    /// `.github/scripts/render-gitignore.py`, driven by
    /// `sync-gitignore.yml`.
    ///
    /// Rendering is deterministic and byte-compared by the caller. The canon
    /// is the complete policy: existing handwritten content is never spliced
    /// onto it.
    public struct Render: Sendable, Equatable {
        /// The whole generated policy.
        public let canon: String

        public init(canon: Institute.ContinuousIntegration.Canon.Gitignore) throws(Error) {
            guard canon.isGenerated else { throw .terminatorAbsent }
            guard canon.text.contains(Institute.ContinuousIntegration.Canon.Gitignore.Capability.block)
            else { throw .capabilityBlockAbsent }
            self.canon = canon.text
        }
    }
}

extension Institute.ContinuousIntegration.Canon.Gitignore.Render {
    /// The file to write into a repository. Existing bytes do not affect the
    /// result because no post-generation policy fragment is lawful.
    public func callAsFunction(over existing: Institute.ContinuousIntegration.Canon.Gitignore?) -> String {
        _ = existing
        return canon
    }

    /// The one way a canonical document refuses.
    ///
    /// Refusing is about *canon*, never about the package under it: an
    /// unusable control-plane document is not a verdict on any
    /// repository, and the two must not travel on the same channel.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Canon carries no `END CANONICAL` terminator.
        case terminatorAbsent
        case capabilityBlockAbsent

        public var message: String {
            switch self {
            case .terminatorAbsent:
                "canon has no \(Institute.ContinuousIntegration.Canon.Gitignore.terminator) marker"
            case .capabilityBlockAbsent:
                "canon has no closed six-capability admission block"
            }
        }
    }
}
