import Foundation
import Repository_Policy

extension Main {
    enum Shape {
        static func findings(
            repository: String,
            gitignore: Data?,
            ignoredIndexedPaths: [String],
            caller: Data?
        ) -> [String] {
            var findings: [String] = []
            if gitignore != Repository.Policy.Uniformity.Wave.Payload.bytes {
                findings.append(
                    "\(repository)\tPACKAGE-SHAPE-002\t.gitignore: bytes differ from "
                        + "ratified shape policy 4"
                )
            } else {
                for path in ignoredIndexedPaths.sorted() {
                    findings.append(
                        "\(repository)\tPACKAGE-SHAPE-001\t\(path): tracked path is outside "
                            + "shape policy 4"
                    )
                }
            }

            if caller != Data(Repository.Policy.Caller.Render.terminal.utf8) {
                findings.append(
                    "\(repository)\tPACKAGE-SHAPE-003\t.github/workflows/ci.yml: bytes differ "
                        + "from the generated terminal caller"
                )
            }
            return findings
        }
    }
}
