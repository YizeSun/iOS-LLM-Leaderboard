import Foundation
import PowerAppKitTestSupport
import PowerEvidence
import PowerGitHubSubmission
import PowerSubmissionKit
import XCTest

final class PowerGitHubSubmissionTests: XCTestCase {
    func testPublishBranchesDirectlyFromExactUpstreamHead() async throws {
        let recorder = GitHubRequestRecorder()
        GitHubURLProtocol.recorder = recorder
        defer { GitHubURLProtocol.recorder = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GitHubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = try GitHubSubmissionClient(
            clientID: "public-client-id",
            session: session
        )
        let evidence = try PowerEvidenceEncoder.encode(
            PowerAppKitFixture.envelope()
        )
        let package = try PowerSubmissionPackage(
            encodedEvidence: evidence,
            githubLogin: "contributor",
            conflictOfInterest: .none,
            disclosure: nil,
            environmentNotes: nil,
            submissionID: UUID(
                uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
            )!
        )

        let pullRequestURL = try await client.publish(
            package: package,
            contributor: "contributor",
            token: "token"
        )
        let requests = recorder.requests()

        XCTAssertEqual(
            pullRequestURL.absoluteString,
            "https://github.com/YizeSun/iOS-LLM-Leaderboard/pull/99"
        )
        XCTAssertFalse(
            requests.contains { $0.path.contains("merge-upstream") }
        )
        let createReference = try XCTUnwrap(
            requests.first {
                $0.method == "POST"
                    && $0.path
                        == "/repos/contributor/iOS-LLM-Leaderboard/git/refs"
            }
        )
        let referenceBody = try jsonBody(createReference)
        XCTAssertEqual(referenceBody["sha"] as? String, "upstream-head")
        XCTAssertEqual(
            referenceBody["ref"] as? String,
            "refs/heads/power-2-submission-"
                + "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )

        let createCommit = try XCTUnwrap(
            requests.first {
                $0.method == "POST"
                    && $0.path
                        == "/repos/contributor/iOS-LLM-Leaderboard/git/commits"
            }
        )
        let commitBody = try jsonBody(createCommit)
        XCTAssertEqual(
            commitBody["parents"] as? [String],
            ["upstream-head"]
        )
    }

    private func jsonBody(_ request: RecordedGitHubRequest) throws
        -> [String: Any]
    {
        let body = try XCTUnwrap(request.body)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
    }
}

private struct RecordedGitHubRequest: Sendable {
    let method: String
    let path: String
    let body: Data?
}

private final class GitHubRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var captured: [RecordedGitHubRequest] = []

    func respond(to request: URLRequest) throws -> (Int, Data) {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let body = try request.httpBody ?? request.httpBodyStream.map {
            try Self.read($0)
        }
        lock.lock()
        captured.append(
            .init(method: method, path: path, body: body)
        )
        lock.unlock()

        let json: String
        switch (method, path) {
        case (
            "GET",
            "/repos/YizeSun/iOS-LLM-Leaderboard"
        ):
            json = """
                {"default_branch":"main"}
                """
        case (
            "GET",
            "/repos/YizeSun/iOS-LLM-Leaderboard/git/ref/heads/main"
        ):
            json = """
                {"object":{"sha":"upstream-head"}}
                """
        case (
            "GET",
            "/repos/YizeSun/iOS-LLM-Leaderboard/git/commits/upstream-head"
        ):
            json = """
                {"tree":{"sha":"upstream-tree"}}
                """
        case (
            "GET",
            "/repos/contributor/iOS-LLM-Leaderboard"
        ):
            json = """
                {
                  "default_branch":"main",
                  "fork":true,
                  "parent":{
                    "full_name":"YizeSun/iOS-LLM-Leaderboard"
                  }
                }
                """
        case (
            "POST",
            "/repos/contributor/iOS-LLM-Leaderboard/git/refs"
        ):
            json = """
                {"object":{"sha":"upstream-head"}}
                """
        case (
            "POST",
            "/repos/contributor/iOS-LLM-Leaderboard/git/blobs"
        ):
            json = """
                {"sha":"blob"}
                """
        case (
            "POST",
            "/repos/contributor/iOS-LLM-Leaderboard/git/trees"
        ):
            json = """
                {"sha":"submission-tree"}
                """
        case (
            "POST",
            "/repos/contributor/iOS-LLM-Leaderboard/git/commits"
        ):
            json = """
                {"sha":"submission-commit"}
                """
        case (
            "PATCH",
            "/repos/contributor/iOS-LLM-Leaderboard/git/refs/heads/"
                + "power-2-submission-"
                + "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        ):
            json = """
                {"object":{"sha":"submission-commit"}}
                """
        case (
            "POST",
            "/repos/YizeSun/iOS-LLM-Leaderboard/pulls"
        ):
            json = """
                {
                  "html_url":
                    "https://github.com/YizeSun/iOS-LLM-Leaderboard/pull/99"
                }
                """
        default:
            throw UnexpectedRequest(method: method, path: path)
        }
        return (200, Data(json.utf8))
    }

    func requests() -> [RecordedGitHubRequest] {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    private static func read(_ stream: InputStream) throws -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(
                &buffer,
                maxLength: buffer.count
            )
            if count < 0 {
                throw stream.streamError ?? UnexpectedRequest(
                    method: "READ",
                    path: "request body"
                )
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class GitHubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var recorder: GitHubRequestRecorder?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.github.com"
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let recorder = Self.recorder else {
                throw UnexpectedRequest(
                    method: request.httpMethod ?? "GET",
                    path: request.url?.path ?? ""
                )
            }
            let (status, data) = try recorder.respond(to: request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                ]
            )!
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct UnexpectedRequest: Error {
    let method: String
    let path: String
}
