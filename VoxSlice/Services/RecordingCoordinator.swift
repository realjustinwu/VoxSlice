import Foundation
import Combine

// MARK: - RecordingCoordinator

/// Orchestrates the full recording lifecycle by delegating to AudioCaptureService.
/// Provides the clean public API that the menu bar UI consumes.
/// Manages coordinator-level state transitions, notification forwarding, and
/// elapsed time formatting.
@Observable
@MainActor
final class RecordingCoordinator {

    // MARK: - Published State (UI binds to these)

    /// Current recording state
    var state: RecordingState = .idle

    /// The active or most recent recording
    var currentRecording: RecordingInfo?

    /// Elapsed recording duration in seconds
    var elapsedDuration: TimeInterval = 0

    /// Elapsed time formatted as "MM:SS" per D-06
    var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Dependencies

    private let audioCaptureService: AudioCaptureService
    private let storageService: StorageService
    private let permissionManager: PermissionManager
    private(set) var transcriptionService: TranscriptionService
    private(set) var analysisService: AnalysisService

    // MARK: - Notification Observers

    private var cancellables: [AnyCancellable] = []

    // MARK: - Notification Names (public API for UI)
    // Defined in AppConstants for single source of truth; aliased here for convenience

    static let recordingDidStart = AppConstants.recordingDidStartNotification
    static let recordingDidStop = AppConstants.recordingDidStopNotification
    static let recordingDidFail = AppConstants.recordingDidFailNotification
    static let deviceDidChange = AppConstants.deviceDidChangeNotification

    // MARK: - Initialization

    init(
        audioCaptureService: AudioCaptureService,
        storageService: StorageService,
        permissionManager: PermissionManager,
        transcriptionService: TranscriptionService,
        analysisService: AnalysisService
    ) {
        self.audioCaptureService = audioCaptureService
        self.storageService = storageService
        self.permissionManager = permissionManager
        self.transcriptionService = transcriptionService
        self.analysisService = analysisService

        setupNotificationObservers()
    }

    // MARK: - Notification Observer Setup

    private func setupNotificationObservers() {
        // Observe AudioCaptureService recording stopped notification
        NotificationCenter.default.publisher(for: .voxsliceRecordingStopped)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleCaptureServiceStopped()
            }
            .store(in: &cancellables)

        // Observe AudioCaptureService device changed notification
        NotificationCenter.default.publisher(for: .voxsliceDeviceChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleDeviceChangeFromCaptureService(notification)
            }
            .store(in: &cancellables)

        // Observe AudioCaptureService silence detected notification
        NotificationCenter.default.publisher(for: .voxsliceSilenceDetected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSilenceDetected()
            }
            .store(in: &cancellables)

        // Observe AudioCaptureService state changes via Combine timer
        // Sync coordinator state with capture service state every 0.5s
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncStateWithCaptureService()
            }
            .store(in: &cancellables)

        // Observe transcription completion to auto-trigger analysis per D-09
        NotificationCenter.default.publisher(for: AppConstants.transcriptionDidCompleteNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let transcript = notification.userInfo?["transcript"] as? TranscriptInfo {
                    self?.startAnalysis(transcript: transcript)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Start Recording

    /// Public API to start a new recording session.
    /// Delegates to AudioCaptureService for actual audio capture.
    func startRecording() {
        // Guard: already recording or in transition
        guard state == .idle || state == .completed || state == .failed(.noPermission) else {
            return
        }

        // Guard: permissions
        guard permissionManager.allPermissionsGranted else {
            state = .failed(.noPermission)
            NotificationCenter.default.post(
                name: RecordingCoordinator.recordingDidFail,
                object: nil,
                userInfo: ["error": "Permissions not granted"]
            )
            return
        }

        do {
            // Delegate to AudioCaptureService for audio capture
            // AudioCaptureService handles: filename generation, file creation,
            // mic/system capture, timers, and state management
            try audioCaptureService.startRecording()

            // Sync state from capture service
            state = audioCaptureService.state
            currentRecording = audioCaptureService.currentRecording
            elapsedDuration = 0

            // Post notification for UI
            NotificationCenter.default.post(name: RecordingCoordinator.recordingDidStart, object: nil)
        } catch {
            state = .failed(.captureStartFailed(error.localizedDescription))
            NotificationCenter.default.post(
                name: RecordingCoordinator.recordingDidFail,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }

    // MARK: - Stop Recording

    /// Public API to stop the current recording session.
    /// Delegates to AudioCaptureService for stopping audio streams.
    func stopRecording() {
        // Guard: not currently recording
        guard state == .recording else {
            return
        }

        state = .stopping

        do {
            // Delegate to AudioCaptureService to stop capture
            // AudioCaptureService handles: stopping engine/stream, closing files,
            // saving metadata JSON, posting internal notification
            let completedRecording = try audioCaptureService.stopRecording()

            // Update coordinator state from completed recording
            currentRecording = completedRecording
            state = .completed

            // Post notification for UI
            NotificationCenter.default.post(
                name: RecordingCoordinator.recordingDidStop,
                object: nil,
                userInfo: ["recording": completedRecording]
            )

            // Auto-transcribe per D-10
            startTranscription(recording: completedRecording)
        } catch {
            state = .failed(.captureStartFailed(error.localizedDescription))
            NotificationCenter.default.post(
                name: RecordingCoordinator.recordingDidFail,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }

    // MARK: - Device Change Handling

    /// Handle device change notifications forwarded from AudioCaptureService.
    /// Logs device changes and posts user-visible notification per D-08/D-09.
    private func handleDeviceChangeFromCaptureService(_ notification: NotificationCenter.Publisher.Output) {
        guard state == .recording else { return }

        // Extract device info from the capture service notification
        let deviceName = notification.userInfo?["deviceName"] as? String ?? "Unknown Device"
        let message = notification.userInfo?["message"] as? String ?? "Audio device changed"

        // Update current recording's device changes from capture service
        if let captureRecording = audioCaptureService.currentRecording {
            currentRecording?.deviceChanges = captureRecording.deviceChanges
        }

        // Forward as coordinator-level notification for UI to display per D-09
        NotificationCenter.default.post(
            name: RecordingCoordinator.deviceDidChange,
            object: nil,
            userInfo: [
                "deviceName": deviceName,
                "message": message
            ]
        )
    }

    // MARK: - Capture Service Event Handlers

    /// Called when AudioCaptureService stops recording (e.g., silence detection, stream error)
    private func handleCaptureServiceStopped() {
        // Only handle if we were in recording state (user-initiated stop handles its own state)
        guard state == .recording else { return }

        // Sync final state from capture service
        currentRecording = audioCaptureService.currentRecording
        state = audioCaptureService.state
        elapsedDuration = currentRecording?.duration ?? elapsedDuration

        NotificationCenter.default.post(
            name: RecordingCoordinator.recordingDidStop,
            object: nil,
            userInfo: currentRecording.map { ["recording": $0] } ?? nil
        )

        // Auto-transcribe per D-10
        if let recording = currentRecording {
            startTranscription(recording: recording)
        }
    }

    /// Called when AudioCaptureService detects silence and stops recording
    private func handleSilenceDetected() {
        // Sync state from capture service
        currentRecording = audioCaptureService.currentRecording
        state = audioCaptureService.state

        // Post failure notification with silence info
        NotificationCenter.default.post(
            name: RecordingCoordinator.recordingDidFail,
            object: nil,
            userInfo: ["error": "Recording stopped: no audio detected for 30 seconds"]
        )
    }

    // MARK: - State Synchronization

    /// Periodically sync coordinator state with AudioCaptureService state
    private func syncStateWithCaptureService() {
        // Only sync elapsed time and recording info while recording
        guard audioCaptureService.state == .recording else { return }

        if state == .recording {
            elapsedDuration = audioCaptureService.elapsedDuration
            currentRecording = audioCaptureService.currentRecording
        }
    }

    // MARK: - Transcription

    /// Trigger automatic transcription after recording stops per D-10.
    /// Runs in a background Task so recording state remains .completed.
    private func startTranscription(recording: RecordingInfo) {
        Task { @MainActor in
            do {
                let transcript = try await transcriptionService.transcribe(recording: recording)
                NotificationCenter.default.post(
                    name: AppConstants.transcriptionDidCompleteNotification,
                    object: nil,
                    userInfo: ["transcript": transcript]
                )
            } catch {
                NotificationCenter.default.post(
                    name: AppConstants.transcriptionDidFailNotification,
                    object: nil,
                    userInfo: ["error": error]
                )
            }
        }
    }

    // MARK: - Analysis

    /// Trigger automatic analysis after transcription completes per D-09.
    /// Runs in a background Task so transcription state remains .completed.
    private func startAnalysis(transcript: TranscriptInfo) {
        Task { @MainActor in
            do {
                let _ = try await analysisService.analyze(transcript: transcript)
                // Notification already posted by AnalysisService on success
            } catch {
                // Notification already posted by AnalysisService on failure
            }
        }
    }

}
