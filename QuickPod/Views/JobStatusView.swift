import SwiftUI

struct JobStatusView: View {
    @ObservedObject var viewModel: HighlightViewModel

    @State private var pulseScale: CGFloat = 1.0

    private var stageName: String {
        switch viewModel.jobStatus {
        case .queued: return "Queued"
        case .running: return "Processing"
        case .failed: return "Failed"
        case .succeeded: return "Complete"
        case .none: return "Submitting"
        }
    }

    private var stageIcon: String {
        switch viewModel.jobStatus {
        case .queued: return "clock.fill"
        case .running: return "bolt.fill"
        case .failed: return "xmark.circle.fill"
        case .succeeded: return "checkmark.circle.fill"
        case .none: return "arrow.up.circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale * 0.9)

                Image(systemName: stageIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.jobStatus != .failed)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }

            VStack(spacing: 8) {
                Text(stageName)
                    .font(.title2.bold())

                Text(viewModel.stageMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.stageMessage)
            }


            if let error = viewModel.errorMessage {
                CardView {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }

            Spacer()

            if viewModel.jobStatus == .failed {
                Button("Try Again") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    let vm = HighlightViewModel()
    JobStatusView(viewModel: vm)
}
