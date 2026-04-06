import Foundation

// MARK: - Recording State

/// Represents the current state of a recording session
enum RecordingState: Equatable, Codable {
    case idle
    case recording
    case stopping
    case completed
    case failed(RecordingError)

    // Custom Codable to handle associated value enum
    private enum CodingKeys: String, CodingKey {
        case base, errorDetail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try container.decode(String.self, forKey: .base)
        switch base {
        case "idle":
            self = .idle
        case "recording":
            self = .recording
        case "stopping":
            self = .stopping
        case "completed":
            self = .completed
        case "failed":
            let detail = try container.decodeIfPresent(String.self, forKey: .errorDetail) ?? "unknown"
            self = .failed(.captureStartFailed(detail))
        default:
            self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode("idle", forKey: .base)
        case .recording:
            try container.encode("recording", forKey: .base)
        case .stopping:
            try container.encode("stopping", forKey: .base)
        case .completed:
            try container.encode("completed", forKey: .base)
        case .failed(let error):
            try container.encode("failed", forKey: .base)
            try container.encode(error.localizedDescription, forKey: .errorDetail)
        }
    }

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.stopping, .stopping), (.completed, .completed):
            return true
        case (.failed(let lError), .failed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Recording Error

/// Errors that can occur during recording
enum RecordingError: Error, LocalizedError, Equatable {
    case noPermission
    case captureStartFailed(String)
    case silenceDetected
    case deviceChangeFailed
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "Required permissions not granted"
        case .captureStartFailed(let reason):
            return "Failed to start capture: \(reason)"
        case .silenceDetected:
            return "Recording stopped: no audio detected for 30 seconds"
        case .deviceChangeFailed:
            return "Failed to handle audio device change"
        case .fileWriteFailed(let reason):
            return "Failed to write audio file: \(reason)"
        }
    }

    static func == (lhs: RecordingError, rhs: RecordingError) -> Bool {
        switch (lhs, rhs) {
        case (.noPermission, .noPermission),
             (.silenceDetected, .silenceDetected),
             (.deviceChangeFailed, .deviceChangeFailed):
            return true
        case (.captureStartFailed(let l), .captureStartFailed(let r)),
             (.fileWriteFailed(let l), .fileWriteFailed(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Audio Device Change

/// Type of audio device change event
enum AudioDeviceChangeType: String, Codable {
    case connected
    case disconnected
}

/// Records an audio device change event during recording
struct AudioDeviceChange: Codable, Identifiable {
    var id: UUID = UUID()
    let deviceName: String
    let changeType: AudioDeviceChangeType
    let timestamp: Date
}

// MARK: - Recording Info

/// Metadata for a recording session
struct RecordingInfo: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var micFilePath: String
    var systemFilePath: String
    var sampleRate: Double
    var bitrate: Int
    var state: RecordingState
    var micDeviceName: String
    var systemAudioDeviceName: String
    var deviceChanges: [AudioDeviceChange]
    var silenceDetected: Bool

    /// Computed duration: endTime - startTime, or time elapsed since startTime if still recording
    var duration: TimeInterval {
        let end = endTime ?? Date.now
        return end.timeIntervalSince(startTime)
    }

    /// Computed metadata file path derived from the mic file path per D-11
    var metadataFilePath: String {
        let micURL = URL(fileURLWithPath: micFilePath)
        let directory = micURL.deletingLastPathComponent()
        let filename = micURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_mic", with: "")
        return directory
            .appendingPathComponent(filename)
            .appendingPathExtension(AppConstants.metadataFileExtension)
            .path
    }

    init(
        id: UUID = UUID(),
        startTime: Date = .now,
        endTime: Date? = nil,
        micFilePath: String,
        systemFilePath: String,
        sampleRate: Double = AppConstants.audioSampleRate,
        bitrate: Int = AppConstants.audioBitrate,
        state: RecordingState = .idle,
        micDeviceName: String = "",
        systemAudioDeviceName: String = "",
        deviceChanges: [AudioDeviceChange] = [],
        silenceDetected: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.micFilePath = micFilePath
        self.systemFilePath = systemFilePath
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.state = state
        self.micDeviceName = micDeviceName
        self.systemAudioDeviceName = systemAudioDeviceName
        self.deviceChanges = deviceChanges
        self.silenceDetected = silenceDetected
    }
}
