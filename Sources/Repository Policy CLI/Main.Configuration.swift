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
        let command: Configuration.Command
        do throws(Configuration.Error) {
            command = try .init(arguments: arguments)
        } catch {
            throw .configuration(RepositoryPolicy.ConfigurationError(error.description))
        }
        let render: Configuration.Render
        do throws(Configuration.Error) {
            render = try .init(declaration: command.declaration)
        } catch {
            throw .configuration(RepositoryPolicy.ConfigurationError(error.description))
        }
        let directory = URL(filePath: command.root).appending(path: Configuration.Render.outputDirectory)
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
