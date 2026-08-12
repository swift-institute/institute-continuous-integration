// Licensed under the Apache License, Version 2.0.

import Foundation
import Institute_Continuous_Integration
import Institute_Continuous_Integration_Symbol_Graph

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

extension Main {
    /// Patch and isolate an umbrella module's symbol graph for
    /// `docc convert --additional-symbol-graph-dir` ([DOC-019a]).
    static func symbolGraphUmbrella(_ rest: [String]) {
        typealias SymbolGraph = Institute.ContinuousIntegration.SymbolGraph
        let sourceDirectory = value("--symbol-graph-dir", in: rest)
        let outputDirectory = value("--output-dir", in: rest)
        let module = value("--umbrella-module", in: rest)
        if sourceDirectory.isEmpty || outputDirectory.isEmpty || module.isEmpty {
            fail(
                "symbol-graph-umbrella requires --symbol-graph-dir, --umbrella-module"
                    + " and --output-dir")
        }
        var excluded: Set<String> = []
        for (index, argument) in rest.enumerated() where argument == "--exclude-module" {
            if index + 1 < rest.count { excluded.insert(rest[index + 1]) }
        }
        // swift-linter:disable:next try optional
        // REASON: FileManager.contentsOfDirectory throws untyped; an unreadable source directory is refused on the next line.
        // swiftlint:disable:next no_try_optional
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: sourceDirectory)
        else {
            fail("symbol-graph-umbrella: \(sourceDirectory) is not a directory")
        }
        let umbrella = SymbolGraph.Umbrella(module: module, excludedModules: excluded)
        let isolation: SymbolGraph.Umbrella.Isolation
        do throws(SymbolGraph.Umbrella.Error) {
            isolation = try umbrella.isolate(files: names) { name in
                guard let data = FileManager.default.contents(
                    atPath: sourceDirectory + "/" + name)
                else { return nil }
                do throws(SymbolGraph.JSON.Error) {
                    return try SymbolGraph.Graph(
                        name: name, text: String(decoding: data, as: UTF8.self))
                } catch {
                    return nil
                }
            }
        } catch {
            report("symbol-graph-umbrella refused: \(error)")
            exit(2)
        }
        // swift-linter:disable:next try optional
        // REASON: FileManager.createDirectory throws untyped; an existing directory is the common case and a real failure surfaces as the write refusal below.
        // swiftlint:disable:next no_try_optional
        try? FileManager.default.createDirectory(
            atPath: outputDirectory, withIntermediateDirectories: true)
        // Stale graphs from a prior run are removed, not merged over: the
        // isolation is the point of the directory.
        // swift-linter:disable:next try optional
        // REASON: FileManager.contentsOfDirectory throws untyped; an absent output directory has no stale graphs to remove.
        // swiftlint:disable:next no_try_optional
        for stale in (try? FileManager.default.contentsOfDirectory(atPath: outputDirectory)) ?? []
        where stale.hasSuffix(".symbols.json") {
            // swift-linter:disable:next try optional
            // REASON: FileManager.removeItem throws untyped; a graph that cannot be removed is overwritten below or fails there.
            // swiftlint:disable:next no_try_optional
            try? FileManager.default.removeItem(atPath: outputDirectory + "/" + stale)
        }
        for graph in isolation.graphs {
            // swift-linter:disable:next try optional
            // REASON: both calls throw untyped; either failure is the same unwritable-graph refusal.
            // swiftlint:disable:next no_try_optional
            guard let text = try? graph.document.text(),
                (try? text.write(
                    toFile: outputDirectory + "/" + graph.name,
                    atomically: true, encoding: .utf8)) != nil
            else { fail("symbol-graph-umbrella: cannot write \(graph.name)") }
        }
        print(isolation.summary(outputDirectory: outputDirectory))
    }
}
