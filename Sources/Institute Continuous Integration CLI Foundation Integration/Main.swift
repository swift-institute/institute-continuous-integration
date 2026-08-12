// Licensed under the Apache License, Version 2.0.

import Foundation
import Institute_Continuous_Integration

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

// The thin CLI mapping. It owns argument grammar and wire encoding only;
// every predicate belongs to a library target and is called, never
// re-derived here.
@main
enum Main {}

extension Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        // The Gitignore faces keep their typed command grammar.
        case "render-gitignore", "validate-gitignore", "validate-gitignore-fixtures":
            gitignore(arguments)

        case "plan": plan(Array(arguments.dropFirst()))
        case "aggregate": aggregate(Array(arguments.dropFirst()))

        case "bootstrap-identity", "bootstrap-manifest", "bootstrap-verify":
            bootstrap(face: arguments[0], Array(arguments.dropFirst()))

        case "validate": validate(Array(arguments.dropFirst()))
        case "validate-fixtures": validateFixtures(Array(arguments.dropFirst()))
        case "workflow-json": workflowJSON(Array(arguments.dropFirst()))
        case "verdict-inventory": verdictInventory(Array(arguments.dropFirst()))
        case "check-canon": checkCanon(Array(arguments.dropFirst()))
        case "canon-rule-count": canonRuleCount(Array(arguments.dropFirst()))
        case "runtime-receipt": runtimeReceipt(Array(arguments.dropFirst()))
        case "runtime-receipt-augment": runtimeReceiptAugment(Array(arguments.dropFirst()))
        case "startup-failures": startupFailures(Array(arguments.dropFirst()))
        case "symbol-graph-umbrella": symbolGraphUmbrella(Array(arguments.dropFirst()))

        default:
            fail(
                "usage: institute-continuous-integration "
                    + "plan|aggregate|validate|validate-fixtures|workflow-json"
                    + "|verdict-inventory|check-canon|canon-rule-count"
                    + "|render-gitignore|validate-gitignore|validate-gitignore-fixtures"
                    + "|symbol-graph-umbrella|bootstrap-identity|bootstrap-manifest"
                    + "|bootstrap-verify|runtime-receipt|runtime-receipt-augment"
                    + "|startup-failures ...")
        }
    }

    /// The tool name every diagnostic is prefixed with. It is the
    /// executable's own name, so a log line names the binary a reader can
    /// run.
    static let tool = "institute-continuous-integration"

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(tool): \(message)\n".utf8))
        exit(2)
    }

    static func report(_ message: String) {
        FileHandle.standardError.write(Data("\(tool): \(message)\n".utf8))
    }

    /// `validate --script` found no Swift owner for that retired script.
    ///
    /// A third code, distinct from `0` (ran) and `2` (could not run),
    /// because "this file has no Swift owner" is a normal, expected answer
    /// and must not be readable as either a clean scan or a broken
    /// machine.
    static let unportedScript: Int32 = 3

    /// Every value of a repeatable flag, in the order given.
    static func values(_ flag: String, in arguments: [String]) -> [String] {
        var found: [String] = []
        for (index, argument) in arguments.enumerated()
        where argument == flag && index + 1 < arguments.count {
            found.append(arguments[index + 1])
        }
        return found
    }

    /// An `alias=path` pair, as the canon roots are given.
    static func aliased(_ text: String) -> (alias: String, path: String)? {
        guard let split = text.firstIndex(of: "=") else { return nil }
        return (String(text[..<split]), String(text[text.index(after: split)...]))
    }

    static func value(_ flag: String, in arguments: [String]) -> String {
        guard let index = arguments.firstIndex(of: flag),
            index + 1 < arguments.count
        else { return "" }
        return arguments[index + 1]
    }

    static func read(_ path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
