import SwiftUI

// Reusable view for configuring an STT provider
struct STTProviderSettingsView: View {
    @Bindable var storageService: StorageService
    @State private var validationService = ProviderValidationService()

    // STT-specific state
    @AppStorage(AppConstants.sttProviderKey) private var selectedProvider: STTProvider = .openAI
    @AppStorage(AppConstants.sttEndpointURLKey) private var customEndpoint: String = ""
    @State private var apiKey: String = ""

    var body: some View {
        Form {
            // Provider picker per D-04
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(STTProvider.allCases, id: \.self) { provider in
                        VStack(alignment: .leading) {
                            Text(provider.displayName)
                            Text(provider.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("STT Provider")
            }

            // API Key per D-23
            Section {
                SecureField("API Key", text: $apiKey, prompt: Text("Enter your \(selectedProvider.displayName) API key"))
                    .textFieldStyle(.roundedBorder)

                // Custom endpoint URL per D-07
                TextField("Custom Endpoint URL", text: $customEndpoint, prompt: Text(selectedProvider.defaultEndpoint))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    // Validate button per D-24 with states per D-25
                    Button {
                        Task {
                            await validationService.validateSTTKey(
                                provider: selectedProvider,
                                apiKey: apiKey,
                                endpointURL: customEndpoint.isEmpty ? nil : customEndpoint
                            )
                            if case .valid = validationService.sttValidationState {
                                // Save to Keychain per D-11
                                try? KeychainService.shared.save(
                                    key: selectedProvider.keychainAccount,
                                    value: apiKey
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            switch validationService.sttValidationState {
                            case .validating:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Validating...")
                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Key verified")
                            case .invalid(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Invalid")
                            case .idle:
                                Text("Validate Key")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || validationService.sttValidationState.isValidating)
                }

                // Error message per UI-SPEC Copywriting
                if case .invalid(let message) = validationService.sttValidationState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("API Configuration")
            }
        }
        .padding(24)
        .onChange(of: selectedProvider) { _, _ in
            validationService.sttValidationState = .idle
            customEndpoint = ""
            apiKey = KeychainService.shared.read(key: selectedProvider.keychainAccount) ?? ""
        }
        .onAppear {
            apiKey = KeychainService.shared.read(key: selectedProvider.keychainAccount) ?? ""
        }
    }
}

// Reusable view for configuring an AI provider
struct AIProviderSettingsView: View {
    @Bindable var storageService: StorageService
    @State private var validationService = ProviderValidationService()

    // AI-specific state
    @AppStorage(AppConstants.aiProviderKey) private var selectedProvider: AIProvider = .openAI
    @AppStorage(AppConstants.aiEndpointURLKey) private var customEndpoint: String = ""
    @State private var apiKey: String = ""

    var body: some View {
        Form {
            // Provider picker per D-04
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        VStack(alignment: .leading) {
                            Text(provider.displayName)
                            Text(provider.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("AI Provider")
            }

            // API Key per D-23
            Section {
                SecureField("API Key", text: $apiKey, prompt: Text("Enter your \(selectedProvider.displayName) API key"))
                    .textFieldStyle(.roundedBorder)

                // Custom endpoint URL per D-07
                TextField("Custom Endpoint URL", text: $customEndpoint, prompt: Text(selectedProvider.defaultEndpoint))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()

                    Button {
                        Task {
                            await validationService.validateAIKey(
                                provider: selectedProvider,
                                apiKey: apiKey,
                                endpointURL: customEndpoint.isEmpty ? nil : customEndpoint
                            )
                            if case .valid = validationService.aiValidationState {
                                try? KeychainService.shared.save(
                                    key: selectedProvider.keychainAccount,
                                    value: apiKey
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            switch validationService.aiValidationState {
                            case .validating:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Validating...")
                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Key verified")
                            case .invalid(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Invalid")
                            case .idle:
                                Text("Validate Key")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || validationService.aiValidationState.isValidating)
                }

                if case .invalid(let message) = validationService.aiValidationState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("API Configuration")
            }
        }
        .padding(24)
        .onChange(of: selectedProvider) { _, _ in
            validationService.aiValidationState = .idle
            customEndpoint = ""
            apiKey = KeychainService.shared.read(key: selectedProvider.keychainAccount) ?? ""
        }
        .onAppear {
            apiKey = KeychainService.shared.read(key: selectedProvider.keychainAccount) ?? ""
        }
    }
}
