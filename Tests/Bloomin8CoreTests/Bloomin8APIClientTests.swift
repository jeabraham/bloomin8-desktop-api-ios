import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Bloomin8Core

final class Bloomin8APIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.handler = nil
    }

    func testListsGalleriesFromDocumentedEndpoint() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.absoluteString, "http://frame.local/gallery/list")
            return (response(for: request, status: 200), Data(#"[{"name":"default"},{"name":"travel"}]"#.utf8))
        }

        let galleries = try await makeClient().galleries(host: "frame.local")

        XCTAssertEqual(galleries.map(\.name), ["default", "travel"])
    }

    func testStartsSlideshowWithIntervalInSecondsIncludingTwoHours() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/show")
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["play_type"] as? Int, 1)
            XCTAssertEqual(json["gallery"] as? String, "travel")
            XCTAssertEqual(json["duration"] as? Int, 7_200)
            return (response(for: request, status: 200), Data())
        }

        try await makeClient().startSlideshow(host: "192.168.1.20", gallery: "travel", durationSeconds: 7_200)
    }

    func testReportsHTTPErrorAndResponseBody() async {
        StubURLProtocol.handler = { request in
            (response(for: request, status: 503), Data("frame is busy".utf8))
        }

        do {
            _ = try await makeClient().galleries(host: "frame.local")
            XCTFail("Expected an HTTP error")
        } catch let error as Bloomin8APIError {
            XCTAssertEqual(error, .httpStatus(503, "frame is busy"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsInvalidHostsAndNonpositiveIntervals() async {
        XCTAssertThrowsError(try Bloomin8APIClient.baseURL(for: "http://frame.local/path"))

        do {
            try await makeClient().startSlideshow(host: "frame.local", gallery: "default", durationSeconds: 0)
            XCTFail("Expected an invalid interval error")
        } catch let error as Bloomin8APIError {
            XCTAssertEqual(error, .invalidDuration)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> Bloomin8APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return Bloomin8APIClient(session: URLSession(configuration: configuration))
    }

}

private func response(for request: URLRequest, status: Int) -> HTTPURLResponse {
    guard let url = request.url else {
        preconditionFailure("A stubbed request must have a URL")
    }
    return HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            XCTFail("No URLProtocol handler configured")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
