import Foundation

final class QuickPodAPI {
    static let shared = QuickPodAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private static let defaultBaseURL = "https://quickpod.likudie.com"
    private static let baseURLKey = "quickpod_base_url"

    var baseURL: String {
        get {
            UserDefaults.standard.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.baseURLKey)
        }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    var token: String? = nil

    // MARK: - Auth

    func register(email: String, password: String) async throws -> TokenResponse {
        let body = AuthRequest(email: email, password: password)
        return try await post(path: "/auth/register", body: body, authenticated: false)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let body = AuthRequest(email: email, password: password)
        return try await post(path: "/auth/login", body: body, authenticated: false)
    }

    func me() async throws -> UserResponse {
        return try await get(path: "/auth/me")
    }

    // MARK: - Endpoints

    func createHighlight(url: String) async throws -> HighlightResponse {
        let body = HighlightRequest(url: url)
        return try await post(path: "/highlight", body: body)
    }

    func getHighlight(jobId: String) async throws -> JobDetail {
        return try await get(path: "/highlight/\(jobId)")
    }

    func healthCheck() async throws -> HealthResponse {
        return try await get(path: "/health")
    }

    func audioURL(for path: String) -> URL? {
        let clean = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: baseURL + clean)
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuth(&request)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(path: String, body: B, authenticated: Bool = true) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        if authenticated { addAuth(&request) }
        return try await execute(request)
    }

    private func addAuth(_ request: inout URLRequest) {
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let serverMessage = (try? decoder.decode(ServerErrorBody.self, from: data))?.message
            throw APIError.httpError(statusCode: http.statusCode, serverMessage: serverMessage)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}

private struct ServerErrorBody: Decodable {
    let error: String?
    let detail: String?
    var message: String? { error ?? detail }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, serverMessage: String?)
    case network(URLError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid. Check Settings."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .network(let urlError):
            return urlError.friendlyMessage
        case .httpError(let code, let serverMessage):
            if let msg = serverMessage, !msg.isEmpty, msg.count < 120 {
                return msg
            }
            return Self.friendlyMessage(for: code)
        }
    }

    private static func friendlyMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400: return "The request was invalid. Please check the URL."
        case 401: return "Authentication required."
        case 403: return "Access denied."
        case 404: return "Resource not found."
        case 422: return "Invalid input. Please check the podcast URL."
        case 429: return "Too many requests. Please wait and try again."
        case 500: return "The server encountered an error. Please try again."
        case 502, 503, 504: return "The server is unavailable. Please try again later."
        default: return "Something went wrong (error \(statusCode)). Please try again."
        }
    }
}

extension URLError {
    var friendlyMessage: String {
        switch code {
        case .notConnectedToInternet:
            return "No internet connection."
        case .timedOut:
            return "The request timed out. Please check your connection."
        case .cannotConnectToHost, .cannotFindHost:
            return "Cannot reach the server. Check the URL in Settings."
        case .networkConnectionLost:
            return "The connection was lost. Please try again."
        default:
            return "A network error occurred. Please try again."
        }
    }
}
