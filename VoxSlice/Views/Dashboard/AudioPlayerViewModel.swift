import SwiftUI
import AVFoundation
import Combine

/// ViewModel wrapping AVPlayer for dashboard audio playback per D-13, D-14, D-15.
/// Provides play/pause, seek, skip +-15s, speed control (0.5x-2.0x),
/// periodic time tracking at 0.25s intervals, and current segment identification
/// for transcript highlighting.
@Observable
@MainActor
final class AudioPlayerViewModel {

    // MARK: - Public State

    /// Whether audio is currently playing
    var isPlaying: Bool = false

    /// Current playback position in seconds
    var currentTime: Double = 0

    /// Total audio duration in seconds
    var duration: Double = 0

    /// Current playback speed (0.5, 1.0, 1.5, 2.0)
    var playbackRate: Float = 1.0

    /// ID of the segment that contains the current playback time
    var currentSegmentId: UUID?

    /// Whether audio is being loaded
    var isLoading: Bool = false

    /// Error message if audio fails to load or play
    var errorMessage: String?

    /// Whether audio file exists and is loadable
    var audioAvailable: Bool = false

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemStatusObserver: AnyCancellable?
    private var segments: [Segment] = []

    // MARK: - Computed Properties for UI Display

    /// Current time formatted as MM:SS
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    /// Total duration formatted as MM:SS
    var formattedDuration: String {
        formatTime(duration)
    }

    /// Normalized seek position (0.0 to 1.0) for slider binding
    var formattedSeekPosition: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // MARK: - Init

    init() {}

    // MARK: - Public Methods

    /// Load audio for a recording history item.
    /// Uses RecordingHistoryService to get the merged audio file URL.
    func loadAudio(for item: RecordingHistoryItem, historyService: RecordingHistoryService) {
        // Clean up any existing player
        cleanup()

        // Reset state
        currentTime = 0
        currentSegmentId = nil
        isPlaying = false
        isLoading = true
        errorMessage = nil
        audioAvailable = false

        // Store segments for current-segment lookup
        segments = item.transcript?.segments ?? []

        // Get merged audio URL from history service
        guard let url = historyService.recordingURL(for: item) else {
            isLoading = false
            audioAvailable = false
            errorMessage = "Audio file not found. The recording may have been moved or deleted."
            return
        }

        // Create AVPlayer with the audio file
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        // Observe player item status for ready/failed states
        playerItemStatusObserver = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.audioAvailable = true
                    let dur = playerItem.duration.seconds
                    self.duration = dur.isNaN ? 0 : dur
                    self.isPlaying = false
                case .failed:
                    self.isLoading = false
                    self.audioAvailable = false
                    self.errorMessage = "Could not play audio. The file may be corrupted."
                @unknown default:
                    break
                }
            }

        // Add periodic time observer every 0.25 seconds per D-15
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            self.updateCurrentSegment()
        }
    }

    /// Start playback
    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
    }

    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Toggle between play and pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if audioAvailable {
            play()
        }
    }

    /// Seek to a specific time in seconds with precise tolerance
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateCurrentSegment()
    }

    /// Seek to the start time of a transcript segment
    func seekToSegment(_ segment: Segment) {
        seek(to: segment.startTime)
    }

    /// Skip forward 15 seconds per D-14
    func skipForward() {
        let target = min(currentTime + 15, duration)
        seek(to: target)
    }

    /// Skip backward 15 seconds per D-14
    func skipBackward() {
        let target = max(currentTime - 15, 0)
        seek(to: target)
    }

    /// Set playback speed (0.5, 1.0, 1.5, 2.0)
    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    /// Clean up player resources. Called when detail view disappears
    /// or recording selection changes.
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        playerItemStatusObserver = nil
        isPlaying = false
    }

    // MARK: - Private Methods

    /// Find the segment containing the current playback time and update currentSegmentId.
    /// Segments may have gaps; if in a gap, keep the last matched segment or nil.
    private func updateCurrentSegment() {
        // Find segment where currentTime >= startTime && currentTime < endTime
        var matchedSegment: Segment?
        for segment in segments {
            if currentTime >= segment.startTime && currentTime < segment.endTime {
                matchedSegment = segment
                break
            }
        }

        // Only update if found a match (preserves last segment highlight during gaps)
        if let match = matchedSegment {
            if currentSegmentId != match.id {
                currentSegmentId = match.id
            }
        } else if currentTime <= 0 || segments.isEmpty {
            // At the very beginning or no segments: clear highlight
            currentSegmentId = nil
        }
        // If in a gap between segments, keep currentSegmentId as-is
    }

    /// Format time in MM:SS format per UI-SPEC.
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    // MARK: - Deinit

    deinit {
        // Note: cleanup() is @MainActor, but deinit is nonisolated.
        // Player and observer cleanup happens when cleanup() is called explicitly
        // from onDisappear or onChange. This is safe because AVPlayer deallocates
        // cleanly when references are dropped.
    }
}
