import Foundation

enum AppConstants {
    static let appName = "VoxSlice"
    static let defaultOutputPath = "~/Documents/VoxSlice"
    static let recordingsDir = "recordings"
    static let transcriptsDir = "transcripts"
    static let analysisDir = "analysis"
    static let configDir = "config"

    // Keychain item keys
    static let keychainService = "com.voxslice.app"
    static let sttApiKeyAccount = "stt-api-key"
    static let aiApiKeyAccount = "ai-api-key"

    // UserDefaults keys
    static let outputFolderKey = "outputFolderPath"
    static let sttProviderKey = "sttProvider"
    static let aiProviderKey = "aiProvider"
    static let sttEndpointURLKey = "sttEndpointURL"
    static let aiEndpointURLKey = "aiEndpointURL"

    // Audio capture settings (per D-03)
    static let audioSampleRate: Double = 44100.0
    static let audioBitrate: Int = 128000
    static let silenceDetectionTimeout: TimeInterval = 30.0  // per D-12
    static let silenceThreshold: Float = 0.01               // amplitude threshold for silence detection
    static let audioFileExtension = "m4a"                    // per D-01
    static let metadataFileExtension = "json"                // per D-11
    static let recordingTimestampFormat = "yyyy-MM-dd_HH-mm-ss"  // per D-10

    // Notification names for coordinator-level events
    static let recordingDidStartNotification = Notification.Name("voxslice.recordingDidStart")
    static let recordingDidStopNotification = Notification.Name("voxslice.recordingDidStop")
    static let recordingDidFailNotification = Notification.Name("voxslice.recordingDidFail")
    static let deviceDidChangeNotification = Notification.Name("voxslice.deviceDidChange")
}
