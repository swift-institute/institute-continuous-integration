// Copyright 2026 Coen ten Thije
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

import Foundation
import Institute_Continuous_Integration_Canon
import Repository_Policy

extension Main {
    /// Renders centrally supplied, typed configuration profiles below the
    /// explicit generated location. CI/editor adoption is intentionally a
    /// separate owner task; this command only makes that adoption possible.
    static func renderConfiguration(_ arguments: [String]) throws(Error) {
        typealias Configuration = Institute.ContinuousIntegration.Canon.Configuration
        var repositoryClass: Configuration.RepositoryClass?
        var deltas: Set<Configuration.LocalDelta> = []
        var formatProfile: String?
        var lintProfile: String?
        var root: String?
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--class":
                guard let raw = iterator.next(), let value = Configuration.RepositoryClass(rawValue: raw) else {
                    throw .configuration(RepositoryPolicy.ConfigurationError("--class must be package|institute|tool"))
                }
                repositoryClass = value
            case "--delta":
                guard let raw = iterator.next(), let value = Configuration.LocalDelta(rawValue: raw) else {
                    throw .configuration(RepositoryPolicy.ConfigurationError("--delta must name an admitted typed delta"))
                }
                guard deltas.insert(value).inserted else {
                    throw .configuration(RepositoryPolicy.ConfigurationError("--delta \(raw) is duplicated"))
                }
            case "--swift-format-profile": formatProfile = iterator.next()
            case "--swiftlint-profile": lintProfile = iterator.next()
            case "--root": root = iterator.next()
            default:
                throw .configuration(RepositoryPolicy.ConfigurationError("unknown render-configuration argument \(argument)"))
            }
        }
        guard let repositoryClass, let formatProfile, let lintProfile, let root else {
            throw .configuration(RepositoryPolicy.ConfigurationError(
                "render-configuration requires --class, --swift-format-profile, --swiftlint-profile, and --root"))
        }
        let declaration = Configuration.Declaration(repositoryClass: repositoryClass, deltas: deltas)
        let format: String
        let lint: String
        do {
            format = try String(contentsOf: URL(filePath: formatProfile), encoding: .utf8)
            lint = try String(contentsOf: URL(filePath: lintProfile), encoding: .utf8)
        } catch {
            throw .io("could not read canonical configuration profile: \(error)")
        }
        let render: Configuration.Render
        do throws(Configuration.Error) {
            render = try .init(
                declaration: declaration,
                profiles: [
                    try .init(baseline: .swiftFormatV1, declaration: declaration, text: format),
                    try .init(baseline: .swiftLintV1, declaration: declaration, text: lint),
                ])
        } catch {
            throw .configuration(RepositoryPolicy.ConfigurationError(error.description))
        }
        let directory = URL(filePath: root).appending(path: Configuration.Render.outputDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for tool in Configuration.Tool.allCases {
                try render.text(for: tool).write(
                    to: directory.appending(path: tool.generatedFileName), atomically: true, encoding: .utf8)
            }
        } catch {
            throw .io("could not write generated configuration: \(error)")
        }
        for tool in Configuration.Tool.allCases { print(tool.invocation) }
    }
}
