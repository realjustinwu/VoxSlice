import Foundation

// MARK: - STT Providers (per D-02)
enum STTProvider: String, CaseIterable, Codable {
    case openAI = "openai"
    case google = "google"
    case assemblyAI = "assemblyai"

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI Whisper API"
        case .google: return "Google Speech-to-Text"
        case .assemblyAI: return "AssemblyAI"
        }
    }

    var description: String {
        switch self {
        case .openAI: return "OpenAI gpt-4o-transcribe model. Supports streaming, timestamps, and multilingual transcription."
        case .google: return "Google Cloud Speech-to-Text. Supports real-time streaming and 125+ languages."
        case .assemblyAI: return "AssemblyAI. High-accuracy transcription with speaker diarization and sentiment analysis."
        }
    }

    /// Default API endpoint URL for this provider
    var defaultEndpoint: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .google: return "https://speech.googleapis.com/v1"
        case .assemblyAI: return "https://api.assemblyai.com/v2"
        }
    }

    /// The keychain account name for this provider's API key
    var keychainAccount: String {
        "stt-\(rawValue)-api-key"
    }
}

// MARK: - AI Providers (per D-06)
enum AIProvider: String, CaseIterable, Codable {
    case openAI = "openai"
    case deepseek = "deepseek"
    case zhipuAI = "zhipuai"

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI (GPT-4o)"
        case .deepseek: return "Deepseek"
        case .zhipuAI: return "\u{667a}\u{8bfe}\u{5927}\u{6a21}\u{578b} (ZhipuAI/GLM)"  // 智谱大模型
        }
    }

    var description: String {
        switch self {
        case .openAI: return "OpenAI GPT-4o for meeting analysis. Industry-standard quality."
        case .deepseek: return "Deepseek AI. OpenAI-compatible API with competitive pricing."
        case .zhipuAI: return "ZhipuAI GLM-4. Domestic Chinese AI model with OpenAI-compatible API."
        }
    }

    /// Default API endpoint URL per D-07
    var defaultEndpoint: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .zhipuAI: return "https://open.bigmodel.cn/api/paas/v4"
        }
    }

    /// The keychain account name for this provider's API key
    var keychainAccount: String {
        "ai-\(rawValue)-api-key"
    }
}
