import Byte_Primitives
import FIPS_180_4
import Foundation

extension Repository.Policy.Caller.Wave {
    static func digest(_ values: [String]) -> String {
        var bytes: [UInt8] = []
        for value in values {
            bytes.append(contentsOf: value.utf8)
            bytes.append(0)
        }
        return FIPS_180_4.SHA256.digest(bytes.map(Byte.init)).hex
    }

    static func digest(_ data: Data) -> String {
        FIPS_180_4.SHA256.digest([UInt8](data).map(Byte.init)).hex
    }

    static func stableData<T: Encodable>(_ value: T) throws(Error) -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        } catch {
            throw .verification("transaction evidence did not encode: \(error)")
        }
    }
}
