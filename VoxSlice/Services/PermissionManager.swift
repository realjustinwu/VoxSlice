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

    /// Screen Recording permission check using CGPreflightScreenCaptureAccess per D-18
    /// This checks if the app has been granted screen recording access without triggering a prompt
    func checkScreenRecordingPermission() {
        let previousState = screenRecordingGranted
        // CGPreflightScreenCaptureAccess returns true if permission is already granted
        // It does NOT trigger the system prompt (that's CGRequestScreenCaptureAccess)
        screenRecordingGranted = CGPreflightScreenCaptureAccess()

        // Per D-19: If screen recording was just granted (was false, now true), show restart alert
        if !previousState && screenRecordingGranted {
            showRestartAlert = true
        }
    }

    /// Microphone permission check
    func checkMicrophonePermission() {
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
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

    /// Request microphone permission (triggers system prompt)
    func requestMicrophonePermission() async -> Bool {
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
