import Foundation
import GitHub_Continuous_Integration_Validation
import GitHub_Standard
import Institute_Continuous_Integration
import Package_Manager
import Repository_Policy

extension Main {
    static func control(_ arguments: [String]) {
        guard arguments.first == "validate" else {
            refuse("control requires the `validate` operation")
        }
        let rest = Array(arguments.dropFirst())
        let repository = value("--repository", in: rest)
        let root = value("--root", in: rest)
        guard !repository.isEmpty, !root.isEmpty else {
            refuse("control validate requires --repository and --root")
        }

        let subject = GitHub.ContinuousIntegration.Validation.Subject(
            repository: repository,
            root: root)
        let branchPins = GitHub.ContinuousIntegration.Validation.BranchPins(
            organizations: .init(names: Institute.ContinuousIntegration.Organization.active))
        let branchFindings: [GitHub.ContinuousIntegration.Validation.Finding]
        do {
            branchFindings = try branchPins.findings(in: subject)
        } catch {
            refuse("control validate could not evaluate branch pins: \(error)")
        }

        var refused = false
        for finding in branchFindings.sorted() {
            print(finding.tsv)
            if finding.rule == GitHub.ContinuousIntegration.Validation.BranchPins.rule {
                refused = true
            }
        }

        if repository.split(separator: "/").last != "swift-html-prism" {
            for finding in identityFindings(root: root) {
                switch finding.disposition {
                case .fatal:
                    refused = true
                    print("\(repository)\tIDENTITY-CONFLICT\t\(identityMessage(finding))")

                case .stalePin:
                    print("\(repository)\tIDENTITY-CONFLICT-STALE-PIN\t\(identityMessage(finding))")
                }
            }
        }

        do {
            for finding in try RepositoryPolicy.BrokenSymlink.findings(at: root) {
                print("\(repository)\tBROKEN-SYMLINK\t\(finding.path)")
            }
        } catch {
            refuse("control validate could not evaluate symbolic links: \(error)")
        }

        if refused { exit(1) }
    }

    private static func identityFindings(
        root: String
    ) -> [Package.Manifest.Identity.Conflict.Finding] {
        var entries: [Package.Manifest.Identity.Conflict.Entry] = []
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: root)
        } catch {
            return []
        }
        for name in names.sorted()
        where Package.Manifest.Identity.Conflict.isRootManifest(name) {
            guard let data = FileManager.default.contents(atPath: root + "/" + name) else {
                continue
            }
            entries += Package.Manifest.Identity.Conflict.entries(
                in: String(decoding: data, as: UTF8.self),
                document: name)
        }

        if let data = FileManager.default.contents(atPath: root + "/Package.resolved") {
            entries += Package.Manifest.Identity.Conflict.entries(
                inResolved: String(decoding: data, as: UTF8.self))
        }
        return Package.Manifest.Identity.Conflict.findings(in: entries)
    }

    private static func identityMessage(
        _ finding: Package.Manifest.Identity.Conflict.Finding
    ) -> String {
        let locations = Dictionary(grouping: finding.entries, by: \.location)
            .keys.sorted()
            .map { location in
                let documents = finding.entries
                    .filter { $0.location == location }
                    .map(\.document).sorted().joined(separator: ", ")
                return "\(location) [\(documents)]"
            }
            .joined(separator: "; ")
        return "identity '\(finding.identity)' has distinct canonical locations: \(locations)"
    }
}
