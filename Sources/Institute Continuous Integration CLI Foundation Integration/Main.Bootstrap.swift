// Licensed under the Apache License, Version 2.0.

import Byte_Primitives
import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Receipt

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// The three bootstrap faces: the cache key an identity derives, the
    /// manifest a producing run writes beside the binaries it built, and
    /// the fail-closed verification a consuming run performs before it
    /// trusts a restored cache entry.
    static func bootstrap(face: String, _ rest: [String]) {
        typealias Bootstrap = Institute.ContinuousIntegration.Receipt.Bootstrap
        let identity = Bootstrap.Identity(
            workspaceRevision: value("--workspace-revision", in: rest),
            sourcesRevision: value("--sources-revision", in: rest),
            toolchain: value("--toolchain", in: rest),
            operatingSystem: value("--os", in: rest),
            architecture: value("--arch", in: rest),
            provisioning: value("--provisioning", in: rest)
                .split(separator: ",").map(String.init))
        do throws(Bootstrap.Identity.ValidationError) {
            try identity.validate()
        } catch {
            report("bootstrap identity refused: \(error)")
            exit(1)
        }

        switch face {
        case "bootstrap-identity":
            var payload = json(identity)
            payload["key"] = identity.digest
            emit(payload)

        case "bootstrap-manifest":
            let root = value("--root", in: rest)
            let paths = value("--executables", in: rest)
                .split(separator: ",").map(String.init)
            var executables: [[String: Any]] = []
            for path in paths {
                guard let data = FileManager.default.contents(atPath: root + "/" + path) else {
                    fail("bootstrap-manifest: unreadable executable \(path)")
                }
                let executable = Bootstrap.Manifest.Executable(
                    path: path, bytes: [UInt8](data).map(Byte.init))
                executables.append(["path": executable.path, "digest": executable.digest])
            }
            if executables.isEmpty { fail("bootstrap-manifest: no executables") }
            emit([
                "identity": json(identity),
                "key": identity.digest,
                "executables": executables,
                "producerRun": value("--producer-run", in: rest),
            ])

        case "bootstrap-verify":
            let root = value("--root", in: rest)
            let manifestPath = value("--manifest", in: rest)
            guard let manifestData = FileManager.default.contents(atPath: manifestPath),
                let object = (try? JSONSerialization.jsonObject(with: manifestData))
                    as? [String: Any],
                let identityObject = object["identity"] as? [String: Any],
                let key = object["key"] as? String,
                let executableObjects = object["executables"] as? [[String: Any]],
                let producerRun = object["producerRun"] as? String
            else {
                fail("bootstrap-verify: unreadable or malformed manifest")
            }
            let recorded = Bootstrap.Identity(
                workspaceRevision: identityObject["workspaceRevision"] as? String ?? "",
                sourcesRevision: identityObject["sourcesRevision"] as? String ?? "",
                toolchain: identityObject["toolchain"] as? String ?? "",
                operatingSystem: identityObject["operatingSystem"] as? String ?? "",
                architecture: identityObject["architecture"] as? String ?? "",
                provisioning: identityObject["provisioning"] as? [String] ?? [])
            let manifest = Bootstrap.Manifest(
                identity: recorded,
                key: key,
                executables: executableObjects.map {
                    .init(
                        path: $0["path"] as? String ?? "",
                        digest: $0["digest"] as? String ?? "")
                },
                producerRun: producerRun)
            do throws(Bootstrap.Manifest.VerificationError) {
                try manifest.verify(against: identity) { path in
                    FileManager.default.contents(atPath: root + "/" + path)
                        .map { [UInt8]($0).map(Byte.init) }
                }
            } catch {
                report("bootstrap cache entry refused (fail closed): \(error)")
                exit(1)
            }
            print(
                "verified: key \(identity.digest), \(executableObjects.count) "
                    + "executable(s), producer run \(producerRun)")

        default:
            fail("unreachable")
        }
    }

    private static func json(
        _ identity: Institute.ContinuousIntegration.Receipt.Bootstrap.Identity
    ) -> [String: Any] {
        [
            "workspaceRevision": identity.workspaceRevision,
            "sourcesRevision": identity.sourcesRevision,
            "toolchain": identity.toolchain,
            "operatingSystem": identity.operatingSystem,
            "architecture": identity.architecture,
            "provisioning": identity.provisioning.sorted(),
        ]
    }

    /// Sorted-key JSON on stdout. A payload this command assembled from
    /// validated values cannot fail to serialize; a failure here is a
    /// defect in this file, not an input.
    private static func emit(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys])
        else { fail("could not serialize the bootstrap payload") }
        print(String(decoding: data, as: UTF8.self))
    }
}
