import SwiftUI

struct JobStatusView: View {
    @ObservedObject var viewModel: HighlightViewModel

    private var stageName: String {
        switch viewModel.jobStatus {
        case .queued:    return "Starting soon"
        case .running:   return "Working on it"
        case .failed:    return "Failed"
        case .succeeded: return "Done"
        case .none:      return "Submitting"
        }
    }

    private var stageIcon: String {
        switch viewModel.jobStatus {
        case .queued:    return "clock.fill"
        case .running:   return "bolt.fill"
        case .failed:    return "xmark.circle.fill"
        case .succeeded: return "checkmark.circle.fill"
        case .none:      return "arrow.up.circle.fill"
        }
    }

    @State private var spinDegrees: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 6)
                    .frame(width: 120, height: 120)

                // Spinning arc while running
                if viewModel.jobStatus == .running {
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(spinDegrees))
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                spinDegrees = 360
                            }
                        }
                }

                // Icon
                Image(systemName: stageIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.jobStatus == .running || viewModel.jobStatus == .queued)
            }

            // Stage label + rotating message
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

            // Estimate label (only while active)
            if viewModel.jobStatus == .queued || viewModel.jobStatus == .running {
                Text("Typically 2–5 minutes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
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
    JobStatusView(viewModel: HighlightViewModel())
}
