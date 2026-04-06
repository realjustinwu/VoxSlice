import Foundation

enum ValidationState: Equatable {
    case idle
    case validating
    case valid
    case invalid(String)  // Error message

    var isValidating: Bool { self == .validating }
    var isValid: Bool { self == .valid }
}

@Observable
final class ProviderValidationService {
    var sttValidationState: ValidationState = .idle
    var aiValidationState: ValidationState = .idle

    /// Validate an STT API key by calling the provider's API per D-24
    func validateSTTKey(provider: STTProvider, apiKey: String, endpointURL: String?) async {
        sttValidationState = .validating
        let baseURL = endpointURL ?? provider.defaultEndpoint

        do {
            let isValid = try await validateKey(baseURL: baseURL, apiKey: apiKey)
            if isValid {
                sttValidationState = .valid
            } else {
                sttValidationState = .invalid("Invalid API key. Check your key and try again.")
            }
        } catch {
            if error is URLError {
                sttValidationState = .invalid("Could not verify key. Check your internet connection and try again.")
            } else {
                sttValidationState = .invalid("Invalid API key. Check your key and try again.")
            }
        }
    }

    /// Validate an AI API key by calling the provider's models endpoint per D-24
    func validateAIKey(provider: AIProvider, apiKey: String, endpointURL: String?) async {
        aiValidationState = .validating
        let baseURL = endpointURL ?? provider.defaultEndpoint

        do {
            let isValid = try await validateKey(baseURL: baseURL, apiKey: apiKey)
            if isValid {
                aiValidationState = .valid
            } else {
                aiValidationState = .invalid("Invalid API key. Check your key and try again.")
            }
        } catch {
            if error is URLError {
                aiValidationState = .invalid("Could not verify key. Check your internet connection and try again.")
            } else {
                aiValidationState = .invalid("Invalid API key. Check your key and try again.")
            }
        }
    }

    // MARK: - Private

    /// For OpenAI-compatible endpoints, call GET /models to validate the key
    private func validateKey(baseURL: String, apiKey: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/models"),
              url.scheme == "https" else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
}
