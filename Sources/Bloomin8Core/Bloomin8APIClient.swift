import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct Gallery: Decodable, Equatable, Identifiable {
    public let name: String

    public var id: String { name }

    public init(name: String) {
        self.name = name
    }
}

public enum Bloomin8APIError: LocalizedError, Equatable {
    case invalidHost
    case invalidDuration
    case invalidResponse
    case httpStatus(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Enter a hostname or IP address without a URL path."
        case .invalidDuration:
            return "The slideshow interval must be a positive whole number of seconds."
        case .invalidResponse:
            return "The frame returned an invalid response."
        case let .httpStatus(status, detail):
            return detail.isEmpty ? "The frame returned HTTP \(status)." : "The frame returned HTTP \(status): \(detail)"
        }
    }
}

public struct Bloomin8APIClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public static func baseURL(for host: String) throws -> URL {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty,
              !host.contains("/"),
              !host.contains("?"),
              !host.contains("#"),
              !host.contains("@"),
              !host.contains(where: \.isWhitespace),
              !host.contains("://") else {
            throw Bloomin8APIError.invalidHost
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        guard let url = components.url, url.host != nil else {
            throw Bloomin8APIError.invalidHost
        }
        return url
    }

    public func galleries(host: String) async throws -> [Gallery] {
        let url = try endpoint(host: host, path: "/gallery/list")
        let data = try await request(url: url, method: "GET")
        do {
            return try JSONDecoder().decode([Gallery].self, from: data)
        } catch {
            throw Bloomin8APIError.invalidResponse
        }
    }

    public func startSlideshow(host: String, gallery: String, durationSeconds: Int) async throws {
        guard durationSeconds > 0 else {
            throw Bloomin8APIError.invalidDuration
        }

        let url = try endpoint(host: host, path: "/show")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ShowRequest(
            playType: 1,
            gallery: gallery,
            duration: durationSeconds
        ))
        _ = try await perform(request)
    }

    private func endpoint(host: String, path: String) throws -> URL {
        let baseURL = try Self.baseURL(for: host)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw Bloomin8APIError.invalidHost
        }
        components.path = path
        guard let url = components.url else {
            throw Bloomin8APIError.invalidHost
        }
        return url
    }

    private func request(url: URL, method: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw Bloomin8APIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let detail = String(decoding: data.prefix(200), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw Bloomin8APIError.httpStatus(response.statusCode, detail)
        }
        return data
    }

    private struct ShowRequest: Encodable {
        let playType: Int
        let gallery: String
        let duration: Int

        enum CodingKeys: String, CodingKey {
            case playType = "play_type"
            case gallery
            case duration
        }
    }
}
