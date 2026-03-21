import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var items: [SavedHighlight] = []

    private var fileURL: URL?
    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    private init() {
        // Loaded after login via switchUser
    }

    func switchUser(userId: String?) {
        if let userId {
            fileURL = docs.appendingPathComponent("quickpod-library-\(userId).json")
        } else {
            fileURL = nil
        }
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([SavedHighlight].self, from: data)
        } catch {
            print("LibraryStore: failed to load – \(error)")
            items = []
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("LibraryStore: failed to save – \(error)")
        }
    }

    // MARK: - Public API

    func add(_ item: SavedHighlight) {
        items.insert(item, at: 0)
        save()
    }

    func rename(item: SavedHighlight, to newTitle: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].title = newTitle
        save()
    }

    func delete(item: SavedHighlight) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: item.fileURL)
        save()
    }

    func isSaved(jobId: String) -> Bool {
        items.contains { $0.jobId == jobId }
    }

    func search(_ query: String) -> [SavedHighlight] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }
        return items.filter {
            $0.title.lowercased().contains(trimmed) ||
            ($0.sourceUrl?.lowercased().contains(trimmed) ?? false)
        }
    }
}
