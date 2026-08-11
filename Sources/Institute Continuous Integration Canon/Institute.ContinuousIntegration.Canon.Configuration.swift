// Copyright 2026 Coen ten Thije
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.

import Institute_Continuous_Integration

extension Institute.ContinuousIntegration.Canon {
    /// The portable, typed selection of an Institute formatting policy.
    ///
    /// This deliberately names policy *identity*, not formatter options. The
    /// values of the first shared profiles remain a ratification input; a
    /// caller therefore supplies a complete central profile and this model
    /// refuses to invent a local replacement.
    public enum Configuration {}
}

extension Institute.ContinuousIntegration.Canon.Configuration {
    public enum Tool: String, CaseIterable, Sendable {
        case swiftFormat = "swift-format"
        case swiftLint = "swiftlint"

        public var generatedFileName: String {
            switch self {
            case .swiftFormat: ".swift-format"
            case .swiftLint: ".swiftlint.yml"
            }
        }

        public var invocation: String {
            switch self {
            case .swiftFormat: "swift format --configuration \(generatedPath)"
            case .swiftLint: "swiftlint --config \(generatedPath)"
            }
        }

        public var generatedPath: String {
            "\(Render.outputDirectory)/\(generatedFileName)"
        }
    }

    /// A baseline name is deliberately closed. It prevents repository names,
    /// paths, globs, and arbitrary profile labels from becoming a second
    /// policy language.
    public enum Baseline: String, CaseIterable, Sendable {
        case swiftFormatV1 = "swift-format-v1"
        case swiftLintV1 = "swiftlint-v1"

        public var tool: Tool {
            switch self {
            case .swiftFormatV1: .swiftFormat
            case .swiftLintV1: .swiftLint
            }
        }
    }

    public enum RepositoryClass: String, CaseIterable, Sendable {
        case package
        case institute
        case tool
    }

    /// The only local semantic deltas currently admitted by the assessment.
    /// Their profile bytes are intentionally not selected here: until those
    /// semantics are ratified, asking to render either delta fails closed.
    public enum LocalDelta: String, CaseIterable, Hashable, Sendable {
        case frozenEvidence = "frozen-evidence"
        case fixtureCorpus = "fixture-corpus"
    }

    public struct Declaration: Sendable, Equatable {
        public let repositoryClass: RepositoryClass
        public let deltas: Set<LocalDelta>

        public init(repositoryClass: RepositoryClass, deltas: Set<LocalDelta> = []) {
            self.repositoryClass = repositoryClass
            self.deltas = deltas
        }
    }

    /// A complete already-ratified profile. `text` is supplied by the future
    /// canonical profile owner, never composed from per-repository snippets.
    public struct Profile: Sendable, Equatable {
        public let baseline: Baseline
        public let declaration: Declaration
        public let text: String

        public init(
            baseline: Baseline,
            declaration: Declaration,
            text: String
        ) throws(Error) {
            guard !text.isEmpty else { throw .emptyProfile(baseline) }
            self.baseline = baseline
            self.declaration = declaration
            self.text = text
        }
    }

    public struct Render: Sendable, Equatable {
        public static let outputDirectory = ".institute/configuration"

        public let declaration: Declaration
        public let profiles: [Tool: Profile]

        public init(
            declaration: Declaration,
            profiles: [Profile]
        ) throws(Error) {
            guard declaration.deltas.isEmpty else {
                throw .unratifiedDeltas(declaration.deltas)
            }
            var selected: [Tool: Profile] = [:]
            for profile in profiles {
                guard profile.declaration == declaration else {
                    throw .profileDoesNotMatchDeclaration(profile.baseline)
                }
                guard selected[profile.baseline.tool] == nil else {
                    throw .duplicateProfile(profile.baseline.tool)
                }
                selected[profile.baseline.tool] = profile
            }
            for tool in Tool.allCases where selected[tool] == nil {
                throw .missingProfile(tool)
            }
            self.declaration = declaration
            self.profiles = selected
        }

        public func text(for tool: Tool) throws(Error) -> String {
            guard let profile = profiles[tool] else { throw .missingProfile(tool) }
            return profile.text
        }
    }

    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case emptyProfile(Baseline)
        case missingProfile(Tool)
        case duplicateProfile(Tool)
        case profileDoesNotMatchDeclaration(Baseline)
        case unratifiedDeltas(Set<LocalDelta>)

        public var description: String {
            switch self {
            case .emptyProfile(let baseline): "configuration profile \(baseline.rawValue) is empty"
            case .missingProfile(let tool): "configuration profile for \(tool.rawValue) is required"
            case .duplicateProfile(let tool): "configuration profile for \(tool.rawValue) is duplicated"
            case .profileDoesNotMatchDeclaration(let baseline):
                "configuration profile \(baseline.rawValue) does not match the declared class and deltas"
            case .unratifiedDeltas(let deltas):
                "configuration deltas are not ratified: \(deltas.map(\.rawValue).sorted().joined(separator: ","))"
            }
        }
    }
}
