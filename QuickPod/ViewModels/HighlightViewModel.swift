import Foundation
import Combine

@MainActor
final class HighlightViewModel: ObservableObject {
    // MARK: - Job State
    @Published var jobId: String?
    @Published var jobStatus: JobStatus?
    @Published var jobDetail: JobDetail?
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // MARK: - Audio Playback
    @Published var playerManager = AudioPlayerManager()

    // MARK: - Save
    @Published var isDownloading = false
    @Published var savedLocally = false

    private let api = QuickPodAPI.shared
    private var pollingTask: Task<Void, Never>?

    // MARK: - Stage Messages

    private static let stageMessages: [JobStatus: [String]] = [
        .queued: [
            "Warming up the engines...",
            "Your request is in the queue...",
            "Preparing to analyze your podcast...",
        ],
        .running: [
            "Downloading and transcribing audio...",
            "Analyzing transcript for key moments...",
            "Selecting the best highlights...",
            "Composing your highlight reel...",
            "Almost there, finalizing output...",
        ],
    ]

    @Published var stageMessage: String = "Preparing..."
    @Published var elapsedSeconds: Int = 0
    private var messageIndex = 0
    private var messageTimer: Task<Void, Never>?
    private var elapsedTimer: Task<Void, Never>?

    // MARK: - Submit

    func submit(url: String) {
        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a podcast URL"
            return
        }

        reset()
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let response = try await api.createHighlight(url: url)
                jobId = response.jobId
                jobStatus = response.status
                isSubmitting = false
                startPolling()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        startMessageRotation()
        startElapsedTimer()

        pollingTask = Task {
            while !Task.isCancelled {
                guard let id = jobId else { break }
                do {
                    let detail = try await api.getHighlight(jobId: id)
                    jobStatus = detail.status
                    jobDetail = detail

                    if detail.status == .succeeded || detail.status == .failed {
                        messageTimer?.cancel()
                        elapsedTimer?.cancel()
                        if detail.status == .succeeded, let audioPath = detail.outputAudioUrl {
                            setupPlayer(audioPath: audioPath)
                        }
                        if detail.status == .failed {
                            errorMessage = detail.error ?? "Job failed"
                        }
                        break
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    break
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        messageTimer?.cancel()
        messageTimer = nil
        elapsedTimer?.cancel()
        elapsedTimer = nil
    }

    /// Restart polling if a job is in progress (called when app returns to foreground).
    func resumePollingIfNeeded() {
        guard jobId != nil, jobStatus != .succeeded, jobStatus != .failed else { return }
        startPolling()
    }

    /// Open a job by ID — used when the user taps a push notification.
    func openJob(jobId: String) {
        guard self.jobId != jobId else { return }
        reset()
        self.jobId = jobId
        startPolling()
    }

    private func startElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedSeconds = 0
        elapsedTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds += 1
            }
        }
    }

    private func startMessageRotation() {
        messageIndex = 0
        updateStageMessage()
        messageTimer?.cancel()
        messageTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                messageIndex += 1
                updateStageMessage()
            }
        }
    }

    private func updateStageMessage() {
        let status = jobStatus ?? .queued
        let messages = Self.stageMessages[status] ?? Self.stageMessages[.queued]!
        stageMessage = messages[messageIndex % messages.count]
    }

    // MARK: - Audio Player

    private var remoteAudioURL: URL?

    private func setupPlayer(audioPath: String) {
        guard let remoteURL = api.audioURL(for: audioPath) else { return }
        remoteAudioURL = remoteURL
        if let source = jobDetail?.sourceUrl,
           let host = URL(string: source)?.host {
            playerManager.nowPlayingTitle = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        playerManager.loadAudio(from: remoteURL)
    }

    // MARK: - Save Audio

    func saveAudio() {
        guard let remoteURL = remoteAudioURL, let id = jobId else { return }

        let userId = AuthStore.shared.userId ?? "unknown"
        let filename = "quickpod-\(userId)-\(id).mp3"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(filename)

        isDownloading = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: remoteURL)
                try data.write(to: fileURL)
                addToLibrary(fileURL: fileURL, jobId: id)
            } catch {
                errorMessage = "Failed to save audio: \(error.localizedDescription)"
            }
            isDownloading = false
        }
    }

    private func addToLibrary(fileURL: URL, jobId id: String) {
        let number = LibraryStore.shared.items.count + 1
        let title = "New Summary \(number)"
        let highlight = SavedHighlight(
            id: UUID(),
            title: title,
            sourceUrl: jobDetail?.sourceUrl,
            jobId: id,
            filename: fileURL.lastPathComponent,
            duration: playerManager.duration > 0 ? playerManager.duration : nil,
            summaryTranscript: jobDetail?.summaryTranscript,
            savedAt: Date()
        )
        LibraryStore.shared.add(highlight)
        savedLocally = true
    }

    // MARK: - Reset

    func reset() {
        stopPolling()
        playerManager.stop()

        remoteAudioURL = nil
        jobId = nil
        jobStatus = nil
        jobDetail = nil
        errorMessage = nil
        isDownloading = false
        savedLocally = false
        stageMessage = "Preparing..."
        elapsedSeconds = 0
    }

    deinit {
        pollingTask?.cancel()
        messageTimer?.cancel()
    }
}
