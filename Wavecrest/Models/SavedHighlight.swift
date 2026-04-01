import Foundation

struct SavedHighlight: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    let sourceUrl: String?
    let jobId: String
    let filename: String
    let duration: Double?
    let summaryTranscript: String?
    let savedAt: Date

    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(filename)
    }
}
