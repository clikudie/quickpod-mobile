import Foundation

struct HighlightRequest: Encodable {
    let url: String
}

struct HighlightResponse: Codable {
    let jobId: String
    let status: JobStatus
    let createdAt: String
}

enum JobStatus: String, Codable {
    case queued
    case running
    case succeeded
    case failed
}

struct JobDetail: Codable {
    let jobId: String
    let status: JobStatus
    let createdAt: String
    let updatedAt: String?
    let error: String?
    let warning: String?
    let sourceUrl: String?
    let outputAudioUrl: String?
    let title: String?
    let language: String?
    let selectedSegments: Int?
    let transcriptSegments: Int?
    let scoreThreshold: Double?
    let summaryTranscript: String?
    let segments: [Segment]?
    let shareClips: [ShareClip]?
}

struct Segment: Codable, Identifiable {
    let start: Double
    let end: Double
    let score: Double
    let reason: String

    var id: String { "\(start)-\(end)" }

    var duration: Double { end - start }
}

struct ShareClip: Codable, Identifiable {
    let label: String
    let start: Double
    let end: Double
    let audioUrl: String

    var id: String { "\(label)-\(start)-\(end)" }
}

struct HealthResponse: Codable {
    let status: String
}

struct AuthRequest: Encodable {
    let email: String
    let password: String
}

struct TokenResponse: Decodable {
    let accessToken: String
    let userId: String
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case accessToken, userId, isVerified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        userId = try container.decode(String.self, forKey: .userId)
        // Default true so older backends that don't send this field still work
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? true
    }
}

struct VerifyRequest: Encodable {
    let code: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String
}

struct UserResponse: Decodable {
    let userId: String
    let email: String
}
