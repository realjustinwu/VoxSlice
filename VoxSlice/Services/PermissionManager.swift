import Foundation
import CoreGraphics
import AVFoundation
import AppKit

@Observable
final class PermissionManager {
    // Permission states
    var screenRecordingGranted = false
    var microphoneGranted = false
    var showRestartAlert = false
    var microphonePromptShown = false
    var screenRecordingPromptShown = false
    private var restartAlertShown = false

    /// Whether all required permissions are granted
    var allPermissionsGranted: Bool {
        screenRecordingGranted && microphoneGranted
    }

    /// Whether any permission is missing (triggers initial permissions window per D-16)
    var hasMissingPermissions: Bool {
        !screenRecordingGranted || !microphoneGranted
    }

    init() {
        checkAllPermissions()
    }

    /// Check both permissions
    func checkAllPermissions() {
        checkScreenRecordingPermission()
        checkMicrophonePermission()
    }

    /// Screen Recording permission check.
    /// CGPreflightScreenCaptureAccess() is the only truly side-effect-free check.
    /// CGWindowListCreateImage and SCShareableContent both trigger system dialogs.
    func checkScreenRecordingPermission() {
        let previousState = screenRecordingGranted
        screenRecordingGranted = CGPreflightScreenCaptureAccess()

        if !previousState && screenRecordingGranted && !restartAlertShown {
            showRestartAlert = true
            restartAlertShown = true
        }
    }

    /// Microphone permission check
    func checkMicrophonePermission() {
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    /// Request Screen Recording permission (triggers system dialog, registers app in privacy list)
    func requestScreenRecordingPermission() {
        screenRecordingPromptShown = true
        // CGRequestScreenCaptureAccess shows the system prompt and adds app to the list
        screenRecordingGranted = CGRequestScreenCaptureAccess()
    }

    /// Open System Settings to Screen Recording pane per D-17 deep link
    func openScreenRecordingSettings() {
        // Per UI-SPEC: x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open System Settings to Microphone pane per D-17 deep link
    func openMicrophoneSettings() {
        // Per UI-SPEC: x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Request microphone permission (triggers system prompt, registers app in privacy list)
    func requestMicrophonePermission() async -> Bool {
        microphonePromptShown = true
        let granted = await AVAudioApplication.requestRecordPermission()
        microphoneGranted = granted
        return granted
    }

    /// Restart the app (called after Screen Recording permission granted per D-19)
    func restartApp() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }

    /// Called when the app window becomes active — re-check permissions per D-18
    func onWindowBecameActive() {
        checkAllPermissions()
    }
}
