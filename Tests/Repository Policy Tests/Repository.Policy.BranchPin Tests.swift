import Foundation
import Package_Manager
import Repository_Policy
import Testing

@Suite
struct RepositoryPolicyBranchPinTests {
    @Test
    func `fleet policy decodes active organizations`() throws {
        let path = try #require(
            Bundle.module.url(forResource: "fleet-minimal", withExtension: "json")?.path)
        let fleet = try RepositoryPolicy.Fleet.read(at: path)

        #expect(fleet.schemaVersion == 1)
        #expect(fleet.activeOrganizationNames == ["swift-institute"])
    }

    @Test
    func `only non-main Institute branches refuse`() {
        let dependencies: [Package.Manifest.Dependency.SourceControl] = [
            .init(
                url: "https://github.com/swift-foundations/swift-alpha.git",
                branch: "feature/x",
                document: "Package.swift"),
            .init(
                url: "https://github.com/swift-foundations/swift-beta.git",
                branch: "main",
                document: "Package.swift"),
            .init(
                url: "https://github.com/elsewhere/swift-gamma.git",
                branch: "feature/x",
                document: "Package.swift"),
        ]

        let findings = RepositoryPolicy.BranchPin.findings(
            in: dependencies,
            organizations: ["swift-foundations"])

        #expect(
            findings == [
                .init(
                    document: "Package.swift",
                    url: "https://github.com/swift-foundations/swift-alpha.git",
                    branch: "feature/x")
            ])
    }
}
