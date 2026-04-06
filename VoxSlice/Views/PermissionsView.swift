import SwiftUI

struct PermissionsView: View {
    @Bindable var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Welcome heading per UI-SPEC Copywriting
            Text("Welcome to VoxSlice")
                .font(.system(size: 28, weight: .bold))

            Text("Grant the required permissions to get started, then configure your API keys in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    iconName: "display",
                    title: "Screen Recording",
                    description: "VoxSlice needs screen recording access to capture system audio from meeting apps like Zoom and Google Meet.",
                    isGranted: permissionManager.screenRecordingGranted,
                    buttonTitle: permissionManager.screenRecordingPromptShown ? "Open System Settings" : "Grant Permission",
                    openSettingsAction: {
                        if !permissionManager.screenRecordingPromptShown {
                            permissionManager.requestScreenRecordingPermission()
                        } else {
                            permissionManager.openScreenRecordingSettings()
                        }
                    }
                )

                PermissionCard(
                    iconName: "mic",
                    title: "Microphone",
                    description: "VoxSlice needs microphone access to record your voice during meetings.",
                    isGranted: permissionManager.microphoneGranted,
                    buttonTitle: permissionManager.microphonePromptShown ? "Open System Settings" : "Grant Permission",
                    openSettingsAction: {
                        if !permissionManager.microphonePromptShown {
                            Task {
                                await permissionManager.requestMicrophonePermission()
                            }
                        } else {
                            permissionManager.openMicrophoneSettings()
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

            // Screen Recording restart notice per UI-SPEC
            if permissionManager.screenRecordingGranted {
                Text("After granting Screen Recording access, VoxSlice must restart. Save any work and restart the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
        .padding(32)
        .frame(width: 440, height: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Per D-18: Poll permission status when app becomes active
            permissionManager.onWindowBecameActive()
        }
        .alert("VoxSlice needs to restart", isPresented: $permissionManager.showRestartAlert) {
            Button("Restart") {
                permissionManager.restartApp()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("VoxSlice needs to restart to use Screen Recording. Restart now?")
        }
        .onChange(of: permissionManager.allPermissionsGranted) { _, allGranted in
            // Per D-20: Auto-dismiss when all permissions granted
            if allGranted {
                dismiss()
            }
        }
    }
}

struct PermissionCard: View {
    let iconName: String
    let title: String
    let description: String
    let isGranted: Bool
    var buttonTitle: String = "Open System Settings"
    let openSettingsAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()

            // Status + action
            if isGranted {
                // Per UI-SPEC: "Granted" green checkmark
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                // Per UI-SPEC: "Not Granted" yellow warning + "Open System Settings" button
                VStack(spacing: 8) {
                    Label("Not Granted", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Button(buttonTitle) {
                        openSettingsAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}
