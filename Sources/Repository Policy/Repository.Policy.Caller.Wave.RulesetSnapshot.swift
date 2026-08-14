import Foundation

extension Repository.Policy.Caller.Wave {
    public struct RulesetSnapshot: Codable, Sendable, Equatable {
        public let repository: String
        public let id: Int64
        public let restore: Data
        public let opened: Data

        public init(
            repository: String,
            id: Int64,
            live: Data,
            canonical: Data,
            integrationID: Int64
        ) throws(Error) {
            let liveObject = try Self.object(live, label: "live ruleset")
            let canonicalObject = try Self.object(canonical, label: "canonical ruleset")
            let keys = ["name", "target", "enforcement", "bypass_actors", "conditions", "rules"]
            let restoreObject = Dictionary(
                uniqueKeysWithValues: keys.compactMap { key in
                    liveObject[key].map { (key, $0) }
                }
            )
            let expectedObject = Dictionary(
                uniqueKeysWithValues: keys.compactMap { key in
                    canonicalObject[key].map { (key, $0) }
                }
            )
            let restore = try Self.data(restoreObject)
            let expected = try Self.data(expectedObject)
            guard restore == expected else {
                throw .ruleset("\(repository): protected-main read-back differs from canonical policy")
            }
            var openedObject = restoreObject
            openedObject["bypass_actors"] = [
                [
                    "actor_id": integrationID,
                    "actor_type": "Integration",
                    "bypass_mode": "always",
                ]
            ]
            self.repository = repository
            self.id = id
            self.restore = restore
            self.opened = try Self.data(openedObject)
        }

        public func verifiesClosed(_ live: Data) -> Bool {
            guard let object = try? Self.object(live, label: "closed ruleset") else {
                return false
            }
            let keys = ["name", "target", "enforcement", "bypass_actors", "conditions", "rules"]
            let normalized = Dictionary(
                uniqueKeysWithValues: keys.compactMap { key in
                    object[key].map { (key, $0) }
                }
            )
            return (try? Self.data(normalized)) == restore
        }

        public func verifiesOpened(_ live: Data) -> Bool {
            guard let object = try? Self.object(live, label: "opened ruleset") else {
                return false
            }
            let keys = ["name", "target", "enforcement", "bypass_actors", "conditions", "rules"]
            let normalized = Dictionary(
                uniqueKeysWithValues: keys.compactMap { key in
                    object[key].map { (key, $0) }
                }
            )
            return (try? Self.data(normalized)) == opened
        }

        public static func normalized(_ live: Data) throws(Error) -> Data {
            let object = try Self.object(live, label: "ruleset")
            let keys = ["name", "target", "enforcement", "bypass_actors", "conditions", "rules"]
            return try Self.data(
                Dictionary(
                    uniqueKeysWithValues: keys.compactMap { key in
                        object[key].map { (key, $0) }
                    }
                )
            )
        }

        private static func object(
            _ data: Data,
            label: String
        ) throws(Error) -> [String: Any] {
            do {
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw Error.ruleset("\(label) is not a JSON object")
                }
                return object
            } catch let error as Error {
                throw error
            } catch {
                throw .ruleset("\(label) did not decode: \(error)")
            }
        }

        private static func data(_ object: [String: Any]) throws(Error) -> Data {
            do {
                return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            } catch {
                throw .ruleset("ruleset payload did not encode: \(error)")
            }
        }
    }
}
