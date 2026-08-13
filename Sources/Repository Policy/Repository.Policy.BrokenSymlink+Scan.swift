import Foundation

extension RepositoryPolicy.BrokenSymlink {
    /// Broken symbolic links beneath `root`, in repository-relative order.
    public static func findings(at root: String) throws(Error) -> [Finding] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: root) else {
            throw .unreadableRoot(root)
        }

        var findings: [Finding] = []
        while let path = enumerator.nextObject() as? String {
            let absolute = root + "/" + path
            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try fileManager.attributesOfItem(atPath: absolute)
            } catch {
                throw .unreadablePath(path)
            }
            guard attributes[.type] as? FileAttributeType == .typeSymbolicLink else {
                continue
            }
            if !fileManager.fileExists(atPath: absolute) {
                findings.append(.init(path: path))
            }
        }
        return findings.sorted { $0.path < $1.path }
    }
}
