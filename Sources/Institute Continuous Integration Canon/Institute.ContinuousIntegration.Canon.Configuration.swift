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

    public struct Render: Sendable, Equatable {
        public static let outputDirectory = ".institute/configuration"

        public let declaration: Declaration
        public let profiles: [Tool: String]

        /// Resolve only profiles installed by the canonical profile owner.
        /// That owner has not ratified profile bytes yet, so this public
        /// entry point refuses before any repository-local output is made.
        public init(declaration: Declaration) throws(Error) {
            try self.init(declaration: declaration, profile: Self.authoritativeProfile)
        }

        init(
            declaration: Declaration,
            profile: (Baseline, Declaration) throws(Error) -> String
        ) throws(Error) {
            guard declaration.deltas.isEmpty else {
                throw .unratifiedDeltas(declaration.deltas)
            }
            var selected: [Tool: String] = [:]
            for baseline in Baseline.allCases {
                let text = try profile(baseline, declaration)
                guard !text.isEmpty else { throw .emptyProfile(baseline) }
                selected[baseline.tool] = text
            }
            self.declaration = declaration
            self.profiles = selected
        }

        public func text(for tool: Tool) throws(Error) -> String {
            guard let profile = profiles[tool] else { throw .missingProfile(tool) }
            return profile
        }

        private static func authoritativeProfile(
            _ baseline: Baseline,
            _ declaration: Declaration
        ) throws(Error) -> String {
            _ = declaration
            throw .profileUnavailable(baseline)
        }
    }

    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case emptyProfile(Baseline)
        case profileUnavailable(Baseline)
        case missingProfile(Tool)
        case unratifiedDeltas(Set<LocalDelta>)
        case commandRequiresClassAndRoot
        case unknownCommandArgument(String)
        case invalidRepositoryClass(String)
        case invalidDelta(String)
        case duplicateDelta(LocalDelta)

        public var description: String {
            switch self {
            case .emptyProfile(let baseline): "configuration profile \(baseline.rawValue) is empty"
            case .profileUnavailable(let baseline):
                "canonical configuration profile \(baseline.rawValue) is unavailable"
            case .missingProfile(let tool): "configuration profile for \(tool.rawValue) is required"
            case .unratifiedDeltas(let deltas):
                "configuration deltas are not ratified: \(deltas.map(\.rawValue).sorted().joined(separator: ","))"
            case .commandRequiresClassAndRoot:
                "render-configuration requires --class and --root"
            case .unknownCommandArgument(let argument):
                "unknown render-configuration argument \(argument)"
            case .invalidRepositoryClass(let value):
                "--class must be package|institute|tool, not \(value)"
            case .invalidDelta(let value):
                "--delta must name an admitted typed delta, not \(value)"
            case .duplicateDelta(let delta):
                "--delta \(delta.rawValue) is duplicated"
            }
        }
    }

    /// The portable command grammar. It is intentionally a typed parsing
    /// seam rather than a bag of paths and configuration-text arguments.
    public struct Command: Sendable, Equatable {
        public let declaration: Declaration
        public let root: String

        public init(arguments: [String]) throws(Error) {
            var repositoryClass: RepositoryClass?
            var deltas: Set<LocalDelta> = []
            var root: String?
            var iterator = arguments.makeIterator()
            while let argument = iterator.next() {
                switch argument {
                case "--class":
                    guard let raw = iterator.next() else { throw .commandRequiresClassAndRoot }
                    guard let value = RepositoryClass(rawValue: raw) else { throw .invalidRepositoryClass(raw) }
                    repositoryClass = value
                case "--delta":
                    guard let raw = iterator.next() else { throw .commandRequiresClassAndRoot }
                    guard let value = LocalDelta(rawValue: raw) else { throw .invalidDelta(raw) }
                    guard deltas.insert(value).inserted else { throw .duplicateDelta(value) }
                case "--root": root = iterator.next()
                default: throw .unknownCommandArgument(argument)
                }
            }
            guard let repositoryClass, let root else { throw .commandRequiresClassAndRoot }
            self.declaration = .init(repositoryClass: repositoryClass, deltas: deltas)
            self.root = root
        }
    }
}
