import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class AudioPlayerCoordinator {
    static let shared = AudioPlayerCoordinator()
    private weak var activePlayer: AudioPlayerManager?
    private init() {}

    func activate(_ player: AudioPlayerManager) {
        if let current = activePlayer, current !== player {
            current.pause()
        }
        activePlayer = player
    }
}

@MainActor
final class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Float = 1.0

    private(set) var currentURL: URL?
    var nowPlayingTitle: String = "Wavecrest"
    private var player: AVPlayer?

    init() {
        setupRemoteControls()
    }
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?

    func loadAudio(from url: URL) {
        AudioPlayerCoordinator.shared.activate(self)
        setupPlayer(url: url)
    }

    /// Prepares audio for playback without stopping other players.
    /// Use this when pre-loading audio that the user hasn't explicitly started yet.
    func prepare(from url: URL) {
        setupPlayer(url: url)
    }

    private func setupPlayer(url: URL) {
        stop()
        currentURL = url

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.pause()

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.duration = item.duration.seconds
                    self?.updateNowPlaying()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.player?.seek(to: .zero)
                self?.currentTime = 0
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            AudioPlayerCoordinator.shared.activate(self)
            player.rate = playbackRate
        }
        isPlaying.toggle()
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    func skip(by seconds: Double) {
        let target = max(0, min(currentTime + seconds, duration))
        seek(to: target)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    func stop() {
        player?.pause()
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
        }
        statusObserver?.invalidate()
        timeObserver = nil
        statusObserver = nil
        player = nil

        isPlaying = false
        currentTime = 0
        duration = 0
        playbackRate = 1.0
        currentURL = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyMediaType: MPMediaType.podcast.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0,
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteControls() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.addTarget { [weak self] _ in
            guard let self, !isPlaying else { return .commandFailed }
            togglePlayPause()
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self, isPlaying else { return .commandFailed }
            togglePlayPause()
            return .success
        }
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -15)
            self?.updateNowPlaying()
            return .success
        }
        cc.skipForwardCommand.preferredIntervals = [30]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: 30)
            self?.updateNowPlaying()
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            self?.updateNowPlaying()
            return .success
        }
    }
}
