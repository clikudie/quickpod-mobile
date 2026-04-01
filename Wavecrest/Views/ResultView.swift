import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: HighlightViewModel

    @State private var showFullTranscript = false
    @State private var summaryCopied = false

    private var detail: JobDetail? { viewModel.jobDetail }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Warning banner
                if let warning = detail?.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Player
                AudioPlayerView(player: viewModel.playerManager)

                // Save button
                Button {
                    viewModel.saveAudio()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isDownloading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.savedLocally ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        }
                        Text(viewModel.savedLocally ? "Saved to Library" : viewModel.isDownloading ? "Saving..." : "Save to Library")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.savedLocally ? .green : Color.accentColor)
                .disabled(viewModel.isDownloading || viewModel.savedLocally)

                // Summary Transcript
                if let summary = detail?.summaryTranscript, !summary.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Summary", systemImage: "doc.text")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = summary
                                    summaryCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        summaryCopied = false
                                    }
                                } label: {
                                    Image(systemName: summaryCopied ? "checkmark" : "doc.on.doc")
                                        .foregroundStyle(summaryCopied ? .green : .secondary)
                                }
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

                // Error
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(viewModel: HighlightViewModel())
    }
}
