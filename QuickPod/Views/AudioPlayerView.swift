import SwiftUI

struct AudioPlayerView: View {
    @ObservedObject var player: AudioPlayerManager

    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    private var speedLabel: String {
        player.playbackRate == 1.0 ? "1×" : String(format: "%.2g×", player.playbackRate)
    }

    var body: some View {
        CardView {
            VStack(spacing: 20) {
                // Progress
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                        in: 0...max(player.duration, 1)
                    )
                    .tint(Color.accentColor)

                    HStack {
                        Text(TimeFormatter.formatted(player.currentTime))
                        Spacer()
                        Text(TimeFormatter.formatted(player.duration))
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                }

                // Transport controls
                HStack(spacing: 0) {
                    Spacer()
                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                    }
                    Spacer()
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 58))
                    }
                    Spacer()
                    Button { player.skip(by: 30) } label: {
                        Image(systemName: "goforward.30")
                            .font(.title2)
                    }
                    Spacer()
                }
                .foregroundStyle(Color.accentColor)

                // Speed menu
                Menu {
                    ForEach(speeds, id: \.self) { speed in
                        Button { player.setPlaybackRate(speed) } label: {
                            if player.playbackRate == speed {
                                Label(speed == 1.0 ? "1× — Normal" : String(format: "%.2g×", speed), systemImage: "checkmark")
                            } else {
                                Text(speed == 1.0 ? "1× — Normal" : String(format: "%.2g×", speed))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(speedLabel)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    AudioPlayerView(player: AudioPlayerManager())
        .padding()
}
