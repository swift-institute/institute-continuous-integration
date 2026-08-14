import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension RepositoryPolicy {
    public struct GitHubClient: Sendable {
        /// Every way one client operation refuses: an HTTP status outside
        /// the operation's contract, a transport failure underneath the
        /// request, a response body that does not decode, a response that
        /// violates the operation's preconditions, or a refusal raised by
        /// the Issue grammar during a compaction.
        public enum Error: Swift.Error, CustomStringConvertible, Sendable {
            case http(method: String, path: String, status: Int, response: String)
            case transport(path: String, message: String)
            case decoding(path: String, message: String)
            case precondition(String)
            case issue(RepositoryPolicy.Issue.Error)

            public var description: String {
                switch self {
                case .http(let method, let path, let status, let response):
                    return "\(method) \(path) returned HTTP \(status): \(response)"

                case .transport(let path, let message):
                    return "\(path): transport failure: \(message)"

                case .decoding(let path, let message):
                    return "\(path): response did not decode: \(message)"

                case .precondition(let message):
                    return message

                case .issue(let error):
                    return "issue grammar refusal: \(error)"
                }
            }
        }

        private let token: String
        private let baseURL: URL

        public init(token: String, baseURL: URL) {
            self.token = token
            self.baseURL = baseURL
        }

        public func repositories(organization: String) async throws(Error) -> [Repository] {
            var page = 1
            var result = [Repository]()
            while true {
                let path = "/orgs/\(organization)/repos?type=public&per_page=100&page=\(page)"
                let response = try await request(method: "GET", path: path)
                guard response.status == 200 else {
                    throw error(method: "GET", path: path, response: response)
                }
                let repositories = try decode([Repository].self, from: response.data, path: path)
                result.append(contentsOf: repositories)
                guard repositories.count == 100 else { return result }
                page += 1
            }
        }

        public func repository(_ fullName: String) async throws(Error) -> Repository {
            let path = "/repos/\(fullName)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            return try decode(Repository.self, from: response.data, path: path)
        }

        public func rootManifestKind(_ fullName: String) async throws(Error) -> String? {
            let path = "/repos/\(fullName)/contents/Package.swift"
            let response = try await request(method: "GET", path: path)
            if response.status == 404 { return nil }
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            return try decode(Content.self, from: response.data, path: path).type
        }

        /// Reads one current Issue body and its HTTP entity tag. The tag and
        /// body digest are both required before an apply operation can begin.
        public func issueSnapshot(
            _ fullName: String,
            number: Int
        ) async throws(Error) -> Issue.Snapshot {
            let path = "/repos/\(fullName)/issues/\(number)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            guard let revision = response.headers["Etag"] ?? response.headers["ETag"] else {
                throw Error.precondition(
                    "\(fullName)#\(number): GitHub did not return an entity tag"
                )
            }
            let issue = try decode(RemoteIssue.self, from: response.data, path: path)
            let state: Issue.NativeState
            if issue.state == "open" {
                state = .open
            } else if issue.stateReason == "not_planned" {
                state = .notPlanned
            } else if issue.stateReason == "duplicate" {
                state = .duplicate
            } else {
                state = .completed
            }
            return .init(
                coordinate: issue.htmlURL,
                revision: revision,
                body: issue.body ?? "",
                native: .init(state: state)
            )
        }

        /// Plans a compaction from one current body. `apply: false` is fully
        /// report-only. On apply, the current GET compares the caller's
        /// revision and digest immediately before the one body PATCH; GitHub
        /// does not support conditional unsafe REST requests. The checkpoint
        /// comment is posted only after that PATCH succeeds.
        public func compactIssue(
            _ fullName: String,
            number: Int,
            guard expected: Issue.Guard,
            apply: Bool
        ) async throws(Error) -> Issue.Compaction? {
            let snapshot = try await issueSnapshot(fullName, number: number)
            let plan: Issue.Compaction?
            do throws(Issue.Error) {
                plan = try Issue.Compactor.plan(snapshot: snapshot, guard: expected)
            } catch {
                throw Error.issue(error)
            }
            guard let plan else { return nil }
            guard apply else { return plan }

            let issuePath = "/repos/\(fullName)/issues/\(number)"
            let update = try await request(
                method: "PATCH",
                path: issuePath,
                body: encode(["body": plan.body])
            )
            guard update.status == 200 else {
                throw error(method: "PATCH", path: issuePath, response: update)
            }
            let commentPath = "\(issuePath)/comments"
            let comment = try await request(
                method: "POST",
                path: commentPath,
                body: encode(["body": plan.checkpoint])
            )
            guard comment.status == 201 else {
                throw error(method: "POST", path: commentPath, response: comment)
            }
            return plan
        }

        public func surfaceFiles(_ fullName: String) async throws(Error) -> [String: String] {
            var pending = [
                ".github/workflows",
                ".github/actions",
                ".github/ISSUE_TEMPLATE",
            ]
            var files = [String: String]()
            while let path = pending.popLast() {
                let response = try await request(
                    method: "GET",
                    path: "/repos/\(fullName)/contents/\(path)"
                )
                if response.status == 404 {
                    continue
                }
                guard response.status == 200 else {
                    throw error(
                        method: "GET",
                        path: "/repos/\(fullName)/contents/\(path)",
                        response: response
                    )
                }

                // A directory listing decodes as an array; a file decodes
                // as a single object. Probe the array shape first and fall
                // through to the file shape when it does not apply.
                let entries: [Content]?
                do {
                    entries = try JSONDecoder().decode([Content].self, from: response.data)
                } catch {
                    entries = nil
                }
                if let entries {
                    for entry in entries.sorted(by: { $0.path < $1.path }).reversed() {
                        if entry.type == "dir" {
                            pending.append(entry.path)
                        } else if entry.type == "file", isGovernedSurface(path: entry.path) {
                            pending.append(entry.path)
                        }
                    }
                    continue
                }

                let content = try decode(
                    Content.self,
                    from: response.data,
                    path: "/repos/\(fullName)/contents/\(path)"
                )
                guard content.type == "file", isGovernedSurface(path: content.path) else {
                    continue
                }
                guard
                    content.encoding == "base64",
                    let encoded = content.content,
                    let data = Data(
                        base64Encoded: encoded,
                        options: .ignoreUnknownCharacters
                    ),
                    let source = String(data: data, encoding: .utf8)
                else {
                    throw Error.precondition(
                        "\(fullName): could not decode governed file \(content.path)"
                    )
                }
                files[content.path] = source
            }
            return files
        }

        public func vulnerabilityReporting(
            _ fullName: String
        ) async throws(Error) -> VulnerabilityReporting {
            let path = "/repos/\(fullName)/private-vulnerability-reporting"
            let response = try await request(method: "GET", path: path)
            if response.status == 404 { return .disabled }
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            let state = try decode(
                PrivateVulnerabilityReporting.self,
                from: response.data,
                path: path
            )
            return state.enabled ? .enabled : .disabled
        }

        public func enableVulnerabilityReporting(_ fullName: String) async throws(Error) {
            let path = "/repos/\(fullName)/private-vulnerability-reporting"
            let response = try await request(method: "PUT", path: path)
            guard response.status == 204 else {
                throw error(method: "PUT", path: path, response: response)
            }
        }

        public func callerWaveRepository(
            _ fullName: String
        ) async throws(Error) -> Repository_Policy.Repository.Policy.Caller.Wave.Repository {
            let path = "/repos/\(fullName)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            let repository = try decode(WaveRepository.self, from: response.data, path: path)
            return .init(
                visibility: repository.visibility,
                archived: repository.archived,
                disabled: repository.disabled,
                defaultBranch: repository.defaultBranch
            )
        }

        public func callerWaveHead(_ fullName: String) async throws(Error) -> String {
            let path = "/repos/\(fullName)/git/ref/heads/main"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            return try decode(WaveReference.self, from: response.data, path: path).object.sha
        }

        public func callerWaveSource(
            _ fullName: String,
            head: String
        ) async throws(Error)
            -> Repository_Policy.Repository.Policy.Caller.Wave.CallerSource
        {
            guard let source = try await callerWaveSourceIfPresent(fullName, head: head) else {
                throw Error.precondition("\(fullName): required package caller is absent")
            }
            return source
        }

        public func callerWaveSourceIfPresent(
            _ fullName: String,
            head: String
        ) async throws(Error)
            -> Repository_Policy.Repository.Policy.Caller.Wave.CallerSource?
        {
            let path = "/repos/\(fullName)/contents/.github/workflows/ci.yml?ref=\(head)"
            let response = try await request(method: "GET", path: path)
            if response.status == 404 { return nil }
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            let content = try decode(WaveContent.self, from: response.data, path: path)
            guard content.encoding == "base64",
                let bytes = Data(
                    base64Encoded: content.content,
                    options: .ignoreUnknownCharacters
                )
            else {
                throw Error.precondition("\(fullName): caller content is not base64")
            }
            return .init(blob: content.sha, bytes: bytes)
        }

        public func callerWaveRulesets(
            _ fullName: String
        ) async throws(Error)
            -> [Repository_Policy.Repository.Policy.Caller.Wave.RulesetReference]
        {
            let path = "/repos/\(fullName)/rulesets"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            return try decode([WaveRuleset].self, from: response.data, path: path)
                .map { .init(id: $0.id, name: $0.name) }
        }

        public func callerWaveRuleset(
            _ fullName: String,
            id: Int64
        ) async throws(Error) -> Data {
            let path = "/repos/\(fullName)/rulesets/\(id)"
            let response = try await request(method: "GET", path: path)
            guard response.status == 200 else {
                throw error(method: "GET", path: path, response: response)
            }
            return response.data
        }

        public func callerWaveReplaceRuleset(
            _ fullName: String,
            id: Int64,
            payload: Data
        ) async throws(Error) {
            let path = "/repos/\(fullName)/rulesets/\(id)"
            let response = try await request(method: "PUT", path: path, body: payload)
            guard response.status == 200 else {
                throw error(method: "PUT", path: path, response: response)
            }
        }

        public func callerWaveCreateBlob(
            _ fullName: String,
            content: Data
        ) async throws(Error) -> String {
            let path = "/repos/\(fullName)/git/blobs"
            let body = encodeObject([
                "content": content.base64EncodedString(),
                "encoding": "base64",
            ])
            let response = try await request(method: "POST", path: path, body: body)
            guard response.status == 201 else {
                throw error(method: "POST", path: path, response: response)
            }
            return try decode(WaveSHA.self, from: response.data, path: path).sha
        }

        public func callerWaveCreateCommit(
            _ fullName: String,
            parent: String,
            blob: String,
            message: String
        ) async throws(Error) -> String {
            let commitPath = "/repos/\(fullName)/git/commits/\(parent)"
            let commitResponse = try await request(method: "GET", path: commitPath)
            guard commitResponse.status == 200 else {
                throw error(method: "GET", path: commitPath, response: commitResponse)
            }
            let baseTree = try decode(
                WaveCommit.self,
                from: commitResponse.data,
                path: commitPath
            ).tree.sha

            let treePath = "/repos/\(fullName)/git/trees"
            let treeBody = encodeObject([
                "base_tree": baseTree,
                "tree": [
                    [
                        "path": ".github/workflows/ci.yml",
                        "mode": "100644",
                        "type": "blob",
                        "sha": blob,
                    ]
                ],
            ])
            let treeResponse = try await request(method: "POST", path: treePath, body: treeBody)
            guard treeResponse.status == 201 else {
                throw error(method: "POST", path: treePath, response: treeResponse)
            }
            let tree = try decode(WaveSHA.self, from: treeResponse.data, path: treePath).sha

            let createPath = "/repos/\(fullName)/git/commits"
            let createBody = encodeObject([
                "message": message,
                "tree": tree,
                "parents": [parent],
            ])
            let createResponse = try await request(
                method: "POST",
                path: createPath,
                body: createBody
            )
            guard createResponse.status == 201 else {
                throw error(method: "POST", path: createPath, response: createResponse)
            }
            return try decode(WaveSHA.self, from: createResponse.data, path: createPath).sha
        }

        public func callerWaveMoveMain(
            _ fullName: String,
            to head: String
        ) async throws(Error) {
            let path = "/repos/\(fullName)/git/refs/heads/main"
            let response = try await request(
                method: "PATCH",
                path: path,
                body: encodeObject(["sha": head, "force": false])
            )
            guard response.status == 200 else {
                throw error(method: "PATCH", path: path, response: response)
            }
        }

        private func request(
            method: String,
            path: String,
            body: Data? = nil
        ) async throws(Error) -> (data: Data, status: Int, headers: [String: String]) {
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
                preconditionFailure("Invalid GitHub API path: \(path)")
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.setValue("swift-institute-repository-policy", forHTTPHeaderField: "User-Agent")
            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } else if method == "PUT" {
                request.httpBody = Data()
                request.setValue("0", forHTTPHeaderField: "Content-Length")
            }
            let data: Data
            let anyResponse: URLResponse
            do {
                (data, anyResponse) = try await URLSession.shared.data(for: request)
            } catch {
                throw Error.transport(path: path, message: String(describing: error))
            }
            guard let response = anyResponse as? HTTPURLResponse else {
                throw Error.transport(path: path, message: "response is not HTTP")
            }
            return (
                data, response.statusCode,
                response.allHeaderFields.reduce(into: [:]) {
                    $0[String(describing: $1.key)] = String(describing: $1.value)
                }
            )
        }

        private func error(
            method: String,
            path: String,
            response: (data: Data, status: Int, headers: [String: String])
        ) -> GitHubClient.Error {
            .http(
                method: method,
                path: path,
                status: response.status,
                response: String(decoding: response.data.prefix(2_000), as: UTF8.self)
            )
        }

        private func decode<T: Decodable>(
            _ type: T.Type,
            from data: Data,
            path: String
        ) throws(Error) -> T {
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                throw Error.decoding(path: path, message: String(describing: error))
            }
        }

        /// Encodes a request body whose value is a string dictionary — a
        /// shape `JSONEncoder` encodes totally, so a failure here is a
        /// programming error, not a runtime condition.
        private func encode(_ body: [String: String]) -> Data {
            do {
                return try JSONEncoder().encode(body)
            } catch {
                preconditionFailure("string dictionary failed to encode: \(error)")
            }
        }

        private func encodeObject(_ body: Any) -> Data {
            do {
                return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            } catch {
                preconditionFailure("JSON request body failed to encode: \(error)")
            }
        }

        private func isGovernedSurface(path: String) -> Bool {
            if path.hasPrefix(".github/ISSUE_TEMPLATE/") {
                return true
            }
            if path.hasPrefix(".github/workflows/") {
                return path.hasSuffix(".yml") || path.hasSuffix(".yaml")
            }
            if path.hasPrefix(".github/actions/") {
                return path.hasSuffix("/action.yml") || path.hasSuffix("/action.yaml")
            }
            return false
        }

        private struct Content: Decodable {
            let type: String
            let path: String
            let encoding: String?
            let content: String?
        }

        private struct WaveRepository: Decodable {
            let visibility: String
            let archived: Bool
            let disabled: Bool
            let defaultBranch: String

            enum CodingKeys: String, CodingKey {
                case visibility
                case archived
                case disabled
                case defaultBranch = "default_branch"
            }
        }

        private struct WaveReference: Decodable {
            let object: WaveSHA
        }

        private struct WaveContent: Decodable {
            let sha: String
            let encoding: String
            let content: String
        }

        private struct WaveRuleset: Decodable {
            let id: Int64
            let name: String
        }

        private struct WaveSHA: Decodable {
            let sha: String
        }

        private struct WaveCommit: Decodable {
            let tree: WaveSHA
        }

        private struct RemoteIssue: Decodable {
            let body: String?
            let htmlURL: String
            let state: String
            let stateReason: String?

            enum CodingKeys: String, CodingKey {
                case body
                case htmlURL = "html_url"
                case state
                case stateReason = "state_reason"
            }
        }

        private struct PrivateVulnerabilityReporting: Decodable {
            let enabled: Bool
        }
    }
}
