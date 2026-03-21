import SwiftUI

struct JobStatusView: View {
    @ObservedObject var viewModel: HighlightViewModel

    // Soft time estimate: progress ring fills over this many seconds.
    // Capped at 95% so it never falsely reaches 100% before the job finishes.
    private static let estimatedSeconds: Double = 180

    private var progressFraction: Double {
        guard viewModel.jobStatus == .running else { return 0 }
        return min(Double(viewModel.elapsedSeconds) / Self.estimatedSeconds, 0.95)
    }

    private var elapsedLabel: String {
        let s = viewModel.elapsedSeconds
        guard s > 0 else { return "" }
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let rem = s % 60
        return rem == 0 ? "\(m)m" : "\(m)m \(rem)s"
    }

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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 6)
                    .frame(width: 120, height: 120)

                // Filled arc (only shown while running)
                if viewModel.jobStatus == .running {
                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progressFraction)
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

            // Elapsed time + estimate (only while active)
            if viewModel.jobStatus == .queued || viewModel.jobStatus == .running {
                VStack(spacing: 4) {
                    if !elapsedLabel.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.caption)
                            Text(elapsedLabel)
                                .font(.subheadline.monospacedDigit())
                        }
                        .foregroundStyle(.primary)
                    }

                    Text("Typically 2–5 minutes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
