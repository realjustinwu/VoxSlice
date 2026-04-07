import SwiftUI

// whisperX service configuration view per D-02
struct TranscriptionSettingsView: View {
    @Bindable var transcriptionService: TranscriptionService

    // Validation state follows Phase 1 ProviderValidationService pattern
    @State private var validationState: ValidationState = .idle
    @State private var serviceURL: String = ""

    var body: some View {
        Form {
            // whisperX Service URL per UI-SPEC "Transcription tab layout"
            Section {
                HStack {
                    TextField("whisperX Service URL", text: $serviceURL, prompt: Text("http://localhost:8000"))
                        .textFieldStyle(.roundedBorder)

                    // Validate Connection button per UI-SPEC validation states
                    Button {
                        Task { await validateConnection() }
                    } label: {
                        HStack(spacing: 6) {
                            switch validationState {
                            case .validating:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Validating...")
                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Connected")
                            case .invalid(let message):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Connection Failed")
                            case .idle:
                                Text("Validate Connection")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(serviceURL.isEmpty || validationState.isValidating)
                }

                // Hint text per UI-SPEC copywriting
                Text("URL of your local whisperX HTTP service")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Error message below URL field per UI-SPEC
                if case .invalid(let message) = validationState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Transcription Service")
            }

            // Connection Status section per UI-SPEC
            if case .valid = validationState {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text("Connected")
                                .font(.body)
                            Text("whisperX service running")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Connection Status")
                }
            }
        }
        .padding(24)
        .onAppear {
            serviceURL = transcriptionService.whisperXURL
        }
        .onChange(of: serviceURL) { _, newValue in
            transcriptionService.whisperXURL = newValue
            if case .valid = validationState {
                validationState = .idle
            }
        }
    }

    // MARK: - Validation

    private func validateConnection() async {
        validationState = .validating
        transcriptionService.whisperXURL = serviceURL
        let (success, errorMessage) = await transcriptionService.healthCheck()
        if success {
            validationState = .valid
        } else {
            validationState = .invalid(errorMessage ?? "Could not connect to whisperX at \(serviceURL). Ensure the service is running.")
        }
    }
}
