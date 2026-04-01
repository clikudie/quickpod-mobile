import SwiftUI
import UniformTypeIdentifiers

struct SubmitView: View {
    @ObservedObject var viewModel: HighlightViewModel
    @State private var podcastURL = ""
    @State private var showFilePicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Paste a podcast or YouTube URL to generate an AI-powered highlight reel.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)

                // URL input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Podcast URL")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    TextField("https://example.com/episode", text: $podcastURL)
                        .textFieldStyle(.plain)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    viewModel.submit(url: podcastURL)
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Label("Generate Highlights", systemImage: "wand.and.stars")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting || podcastURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)

                // Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.separator))
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.separator))
                }
                .padding(.horizontal)

                // File upload
                Button {
                    showFilePicker = true
                } label: {
                    Label("Upload Audio File", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSubmitting)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let fileURL = urls.first else { return }
                viewModel.submitFile(url: fileURL)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

/// Reusable card wrapper with rounded corners and shadow
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

#Preview {
    NavigationStack {
        SubmitView(viewModel: HighlightViewModel())
    }
}
