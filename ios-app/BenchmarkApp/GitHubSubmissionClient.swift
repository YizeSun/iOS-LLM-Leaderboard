import Foundation

struct GitHubDeviceAuthorization: Sendable, Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let expiresIn: Int
    let interval: Int
}

actor GitHubSubmissionClient {
    enum ClientError: LocalizedError {
        case missingClientID
        case invalidResponse
        case requestFailed(Int, String)
        case authorizationExpired
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                "Direct GitHub submission is not configured in this build."
            case .invalidResponse:
                "GitHub returned an unreadable response."
            case .requestFailed(let status, let message):
                "GitHub request failed (\(status)): \(message)"
            case .authorizationExpired:
                "GitHub authorization expired. Start the submission again."
            case .authorizationDenied:
                "GitHub authorization was cancelled."
            }
        }
    }

    private struct DeviceResponse: Decodable {
        let deviceCode: String
        let userCode: String
        let verificationURI: URL
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationURI = "verification_uri"
            case expiresIn = "expires_in"
            case interval
        }
    }

    private struct TokenResponse: Decodable {
        let accessToken: String?
        let error: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case error
        }
    }

    private struct User: Decodable { let login: String }
    private struct Repository: Decodable {
        let defaultBranch: String
        enum CodingKeys: String, CodingKey { case defaultBranch = "default_branch" }
    }
    private struct GitReference: Decodable {
        let object: GitObject
        struct GitObject: Decodable { let sha: String }
    }
    private struct GitCommit: Decodable {
        let tree: GitTree
        struct GitTree: Decodable { let sha: String }
    }
    private struct GitBlob: Decodable { let sha: String }
    private struct CreatedTree: Decodable { let sha: String }
    private struct CreatedCommit: Decodable { let sha: String }
    private struct PullRequest: Decodable {
        let htmlURL: URL
        enum CodingKeys: String, CodingKey { case htmlURL = "html_url" }
    }

    private let clientID: String
    private let session: URLSession
    private let apiVersion = "2026-03-10"
    private let upstreamOwner = "YizeSun"
    private let repositoryName = "iOS-LLM-Leaderboard"

    init(clientID: String, session: URLSession = .shared) throws {
        let normalized = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              !normalized.contains("$(") else {
            throw ClientError.missingClientID
        }
        self.clientID = normalized
        self.session = session
    }

    func startAuthorization() async throws -> GitHubDeviceAuthorization {
        let response: DeviceResponse = try await formRequest(
            url: URL(string: "https://github.com/login/device/code")!,
            fields: ["client_id": clientID, "scope": "public_repo"]
        )
        return .init(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURL: response.verificationURI,
            expiresIn: response.expiresIn,
            interval: response.interval
        )
    }

    func waitForAccessToken(_ authorization: GitHubDeviceAuthorization) async throws -> String {
        let deadline = Date().addingTimeInterval(TimeInterval(authorization.expiresIn))
        var interval = authorization.interval
        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            let response: TokenResponse = try await formRequest(
                url: URL(string: "https://github.com/login/oauth/access_token")!,
                fields: [
                    "client_id": clientID,
                    "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ]
            )
            if let token = response.accessToken { return token }
            switch response.error {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case "access_denied": throw ClientError.authorizationDenied
            case "expired_token": throw ClientError.authorizationExpired
            default: throw ClientError.invalidResponse
            }
        }
        throw ClientError.authorizationExpired
    }

    func authenticatedUser(token: String) async throws -> String {
        let user: User = try await apiRequest(path: "/user", token: token)
        return user.login
    }

    func publish(
        package: PowerSubmissionPackage,
        contributor: String,
        token: String
    ) async throws -> URL {
        let upstream: Repository = try await apiRequest(
            path: "/repos/\(upstreamOwner)/\(repositoryName)", token: token
        )
        let _: Repository? = try? await apiRequest(
            path: "/repos/\(upstreamOwner)/\(repositoryName)/forks",
            method: "POST",
            token: token,
            body: ["default_branch_only": true]
        ) as Repository
        try await waitForFork(owner: contributor, token: token)

        let base: GitReference = try await apiRequest(
            path: "/repos/\(upstreamOwner)/\(repositoryName)/git/ref/heads/\(upstream.defaultBranch)",
            token: token
        )
        let baseCommit: GitCommit = try await apiRequest(
            path: "/repos/\(upstreamOwner)/\(repositoryName)/git/commits/\(base.object.sha)",
            token: token
        )
        let branch = "power-submission-\(package.submissionID.uuidString.lowercased())"
        let _: GitReference = try await apiRequest(
            path: "/repos/\(contributor)/\(repositoryName)/git/refs",
            method: "POST",
            token: token,
            body: ["ref": "refs/heads/\(branch)", "sha": base.object.sha]
        )
        let resultBlob = try await createBlob(
            package.resultData, owner: contributor, token: token
        )
        let manifestBlob = try await createBlob(
            package.manifestData, owner: contributor, token: token
        )
        let tree: CreatedTree = try await apiRequest(
            path: "/repos/\(contributor)/\(repositoryName)/git/trees",
            method: "POST",
            token: token,
            body: [
                "base_tree": baseCommit.tree.sha,
                "tree": [
                    ["path": "\(package.repositoryDirectory)/result.json", "mode": "100644", "type": "blob", "sha": resultBlob.sha],
                    ["path": "\(package.repositoryDirectory)/submission.json", "mode": "100644", "type": "blob", "sha": manifestBlob.sha],
                ],
            ]
        )
        let commit: CreatedCommit = try await apiRequest(
            path: "/repos/\(contributor)/\(repositoryName)/git/commits",
            method: "POST",
            token: token,
            body: [
                "message": "Add Power 1.1 result",
                "tree": tree.sha,
                "parents": [base.object.sha],
            ]
        )
        let _: GitReference = try await apiRequest(
            path: "/repos/\(contributor)/\(repositoryName)/git/refs/heads/\(branch)",
            method: "PATCH",
            token: token,
            body: ["sha": commit.sha]
        )
        let pullRequest: PullRequest = try await apiRequest(
            path: "/repos/\(upstreamOwner)/\(repositoryName)/pulls",
            method: "POST",
            token: token,
            body: [
                "title": "Add Power 1.1 result",
                "head": "\(contributor):\(branch)",
                "base": upstream.defaultBranch,
                "body": "Submitted from the iOS Benchmark App. CI is authoritative for validation, triage, and ranking eligibility.",
                "maintainer_can_modify": true,
            ]
        )
        return pullRequest.htmlURL
    }

    private func waitForFork(owner: String, token: String) async throws {
        for _ in 0..<30 {
            do {
                let _: Repository = try await apiRequest(
                    path: "/repos/\(owner)/\(repositoryName)", token: token
                )
                return
            } catch {
                try await Task.sleep(for: .seconds(2))
            }
        }
        throw ClientError.requestFailed(408, "GitHub fork was not ready in time")
    }

    private func createBlob(_ data: Data, owner: String, token: String) async throws -> GitBlob {
        try await apiRequest(
            path: "/repos/\(owner)/\(repositoryName)/git/blobs",
            method: "POST",
            token: token,
            body: ["content": data.base64EncodedString(), "encoding": "base64"]
        )
    }

    private func formRequest<Response: Decodable>(
        url: URL,
        fields: [String: String]
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { key, value in
                "\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)
        return try await decoded(request)
    }

    private func apiRequest<Response: Decodable>(
        path: String,
        method: String = "GET",
        token: String,
        body: Any? = nil
    ) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.github.com\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await decoded(request)
    }

    private func decoded<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw ClientError.requestFailed(
                http.statusCode,
                message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }
}
