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
}
