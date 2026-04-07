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

    // Transcription settings (per D-01/D-02)
    static let whisperXURLKey = "whisperXServiceURL"
    static let whisperXDefaultURL = "http://localhost:8000"
    static let whisperXHealthEndpoint = "/health"
    static let whisperXTranscribeEndpoint = "/transcribe"
    static let transcriptFileSuffix = "_transcript"
    static let transcriptFileExtension = "json"

    // Audio chunking (per D-11)
    static let maxUploadFileSize: UInt64 = 24 * 1024 * 1024  // 24MB (under 25MB Whisper limit)
    static let defaultChunkDuration: TimeInterval = 600.0    // 10 minutes per chunk

    // Notification names for transcription events
    static let transcriptionDidStartNotification = Notification.Name("voxslice.transcriptionDidStart")
    static let transcriptionDidCompleteNotification = Notification.Name("voxslice.transcriptionDidComplete")
    static let transcriptionDidFailNotification = Notification.Name("voxslice.transcriptionDidFail")

    // Analysis settings (per D-03)
    static let analysisLanguageKey = "analysisLanguage"

    // Analysis notification names
    static let analysisDidStartNotification = Notification.Name("voxslice.analysisDidStart")
    static let analysisDidCompleteNotification = Notification.Name("voxslice.analysisDidComplete")
    static let analysisDidFailNotification = Notification.Name("voxslice.analysisDidFail")

    // Analysis file naming
    static let analysisFileSuffix = "_analysis"
    static let analysisFileExtension = "md"

    // Dashboard settings
    static let dashboardWindowFrame = "dashboardWindowFrame"

    // Merged audio file naming
    static let mergedFileSuffix = "_merged"

    // Dashboard notification names
    static let dashboardDataDidChangeNotification = Notification.Name("voxslice.dashboardDataDidChange")
}
