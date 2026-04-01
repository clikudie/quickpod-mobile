import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var player: AudioPlayerManager
    @State private var searchText = ""

    private var filteredItems: [SavedHighlight] {
        store.search(searchText)
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                ContentUnavailableView(
                    "No Saved Highlights",
                    systemImage: "waveform",
                    description: Text("Highlights you save will appear here")
                )
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item.id) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                    .overlay {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(Color.accentColor)
                                    }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.body.weight(.semibold))
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        if let duration = item.duration {
                                            Text(TimeFormatter.formatted(duration))
                                                .font(.caption.monospaced())
                                        }
                                        Text(item.savedAt, style: .date)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { filteredItems[$0] }
                        for item in toDelete { store.delete(item: item) }
                    }
                }
                .searchable(text: $searchText, prompt: "Search highlights")
            }
        }
        .navigationDestination(for: UUID.self) { id in
            LibraryPlayerView(highlightId: id, store: store, player: player)
        }
    }
}
