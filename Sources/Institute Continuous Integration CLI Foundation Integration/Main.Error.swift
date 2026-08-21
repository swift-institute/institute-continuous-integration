// Licensed under the Apache License, Version 2.0.

import Institute_Continuous_Integration
import Institute_Continuous_Integration_Command
import Institute_Continuous_Integration_Validation

extension Main {
    enum Error: Swift.Error {
        case command(ContinuousIntegration.Command.Gitignore.Error)
        case unreadable(String)
        case environment(ContinuousIntegration.Validation.EnvironmentDefect)
        case unowned([String])
    }
}

extension Main.Error {
    var message: String {
        switch self {
        case .command(let error): error.message

        case .unreadable(let path): "could not read `\(path)`"

        case .environment(let error): error.message

        case .unowned(let directories):
            "unowned Gitignore fixture directories: \(directories.joined(separator: ", "))"
        }
    }
}
