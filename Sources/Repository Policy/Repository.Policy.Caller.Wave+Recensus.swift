import Byte_Primitives
import FIPS_180_4
import Foundation

extension Repository.Policy.Caller.Wave {
    public static func recensus(
        population: Population,
        caller: Data
    ) -> Recensus {
        let canonicalDigest = digest(caller)
        let observations = population.subjects.map { subject in
            Observation(
                repository: subject.repository,
                head: subject.head,
                blob: subject.caller.blob,
                digest: digest(subject.caller.bytes),
                matches: subject.caller.bytes == caller
            )
        }
        return Recensus(
            organizations: population.organizations,
            examined: population.examined,
            excluded: population.excluded,
            canonicalDigest: canonicalDigest,
            observations: observations,
            accepted: !observations.isEmpty && observations.allSatisfy(\.matches)
        )
    }

    private static func digest(_ data: Data) -> String {
        FIPS_180_4.SHA256.digest([UInt8](data).map(Byte.init)).hex
    }
}
