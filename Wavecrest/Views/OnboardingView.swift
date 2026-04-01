import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private static let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Your podcast,\ndown to the highlights",
            body: "Wavecrest listens to any podcast or YouTube episode and extracts the moments that actually matter — no fluff, no filler."
        ),
        OnboardingPage(
            icon: "link.circle.fill",
            title: "Just paste a URL",
            body: "Copy the link to any episode — RSS feed, podcast website, Spotify, YouTube, wherever you found it — and paste it in."
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "AI picks the best parts",
            body: "Our model reads the full transcript and selects complete, coherent segments that tell the episode's story. Your highlight reel is usually ready in a couple of minutes."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, p in
                    pageView(p).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            bottomBar
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Page

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: p.icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text(p.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(p.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Dot indicators
            HStack(spacing: 8) {
                ForEach(0..<Self.pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.accentColor : Color(.tertiaryLabel))
                        .frame(width: i == page ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: page)
                }
            }

            // Next / Get Started
            Button {
                if page < Self.pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < Self.pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            // Skip (only on first two pages)
            if page < Self.pages.count - 1 {
                Button("Skip") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Keep layout stable
                Color.clear.frame(height: 20)
            }
        }
        .padding(.bottom, 48)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}

#Preview {
    OnboardingView(onFinish: {})
}
