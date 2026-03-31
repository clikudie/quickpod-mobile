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

    private static let persistedJobIdKey = "quickpod_last_job_id"

    @Published var stageMessage: String = "Preparing..."
    private var messageTimer: Task<Void, Never>?

    // MARK: - Submit

    func submitFile(url: URL) {
        reset()
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                // Copy to temp dir so security-scoped access isn't needed during the upload
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                _ = url.startAccessingSecurityScopedResource()
                try FileManager.default.copyItem(at: url, to: tempURL)
                url.stopAccessingSecurityScopedResource()

                let response = try await api.uploadAudio(fileURL: tempURL)
                try? FileManager.default.removeItem(at: tempURL)

                jobId = response.jobId
                UserDefaults.standard.set(response.jobId, forKey: Self.persistedJobIdKey)
                jobStatus = response.status
                isSubmitting = false
                startPolling()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

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
                UserDefaults.standard.set(response.jobId, forKey: Self.persistedJobIdKey)
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

    private static let pollTimeout: TimeInterval = 30 * 60  // 30 minutes

    func startPolling() {
        pollingTask?.cancel()
        startMessageRotation()

        let deadline = Date().addingTimeInterval(Self.pollTimeout)

        pollingTask = Task {
            while !Task.isCancelled {
                if Date() > deadline {
                    messageTimer?.cancel()
                    errorMessage = "The request is taking too long. Please try again later."
                    break
                }

                guard let id = jobId else { break }
                do {
                    let detail = try await api.getHighlight(jobId: id)
                    jobStatus = detail.status
                    jobDetail = detail
                    if let stage = detail.stage {
                        stageMessage = stage
                    }

                    if detail.status == .succeeded || detail.status == .failed {
                        messageTimer?.cancel()
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
        UserDefaults.standard.set(jobId, forKey: Self.persistedJobIdKey)
        startPolling()
    }

    /// Called from ContentView.onAppear to restore the last job after an app kill.
    func restoreLastJobIfNeeded() {
        guard jobId == nil,
              let savedId = UserDefaults.standard.string(forKey: Self.persistedJobIdKey) else { return }
        jobId = savedId
        jobStatus = .queued  // Show progress UI immediately while first poll is in flight
        startPolling()
    }

    private func startMessageRotation() {
        stageMessage = "Starting..."
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

        UserDefaults.standard.removeObject(forKey: Self.persistedJobIdKey)
        remoteAudioURL = nil
        jobId = nil
        jobStatus = nil
        jobDetail = nil
        errorMessage = nil
        isDownloading = false
        savedLocally = false
        stageMessage = "Preparing..."
    }

    deinit {
        pollingTask?.cancel()
        messageTimer?.cancel()

    }
}
