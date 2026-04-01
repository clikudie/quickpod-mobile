import SwiftUI

struct LibraryPlayerView: View {
    let highlightId: UUID
    @ObservedObject var store: LibraryStore
    @ObservedObject var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var showFullTranscript = false
    @State private var showDeleteConfirmation = false
    @State private var showRenameAlert = false
    @State private var renameText = ""

    private var highlight: SavedHighlight? {
        store.items.first { $0.id == highlightId }
    }

    var body: some View {
        if let highlight {
            ScrollView {
                VStack(spacing: 20) {
                    // Source & date
                    if highlight.sourceUrl != nil || true {
                        HStack(spacing: 16) {
                            if let source = highlight.sourceUrl,
                               let host = URL(string: source)?.host {
                                Label(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host, systemImage: "link")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(highlight.savedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 4)
                    }

                    // Player
                    AudioPlayerView(player: player)

                    // Summary Transcript
                    if let summary = highlight.summaryTranscript, !summary.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Summary", systemImage: "doc.text")
                                        .font(.headline)
                                    Spacer()
                                    Button(showFullTranscript ? "Show less" : "Show more") {
                                        withAnimation { showFullTranscript.toggle() }
                                    }
                                    .font(.subheadline)
                                }
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(showFullTranscript ? nil : 4)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(highlight.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            renameText = highlight.title
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Rename Highlight", isPresented: $showRenameAlert) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { store.rename(item: highlight, to: trimmed) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete this highlight?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    player.stop()
                    store.delete(item: highlight)
                    dismiss()
                }
            }
            .onAppear {
                player.nowPlayingTitle = highlight.title
                if player.currentURL != highlight.fileURL {
                    player.prepare(from: highlight.fileURL)
                }
            }
        }
    }
}
