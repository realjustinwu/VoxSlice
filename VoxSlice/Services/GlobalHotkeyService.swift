import Cocoa

/// Manages global keyboard shortcut for recording toggle from any application context.
/// Per D-01: Uses NSEvent.addGlobalMonitorForEvents (no Accessibility permission needed).
/// Per D-04: @Observable service in VoxSlice/Services/.
/// IMPORTANT: Uses BOTH global and local monitors so the hotkey works whether
/// VoxSlice is in the foreground or background (per RECD-01 "from any context").
@Observable
@MainActor
final class GlobalHotkeyService {

    // MARK: - Published State

    /// Whether the global hotkey is enabled (per D-08)
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: AppConstants.globalHotkeyKey + "Enabled")
            if isEnabled {
                registerMonitors()
            } else {
                unregisterMonitors()
            }
        }
    }

    /// Current modifier flags for the hotkey (per D-07)
    var modifierFlags: UInt

    /// Current key code for the hotkey (per D-07)
    var keyCode: UInt16

    /// Human-readable description of current shortcut (e.g., "Cmd+Shift+R")
    var shortcutDescription: String {
        guard isEnabled else { return "Disabled" }
        return formatShortcut(modifierFlags: modifierFlags, keyCode: keyCode)
    }

    // MARK: - Private State

    /// Global monitor: fires when app is NOT in focus
    private var globalMonitor: Any?
    /// Local monitor: fires when app IS in focus
    private var localMonitor: Any?
    private weak var recordingCoordinator: RecordingCoordinator?

    // MARK: - Initialization

    init(recordingCoordinator: RecordingCoordinator) {
        self.recordingCoordinator = recordingCoordinator

        // Load from UserDefaults per D-07, default to Cmd+Shift+R per D-02
        let saved = UserDefaults.standard.object(forKey: AppConstants.globalHotkeyKey) as? [String: Any]
        self.modifierFlags = saved?["modifiers"] as? UInt
            ?? AppConstants.defaultHotkeyModifiers
        self.keyCode = saved?["keyCode"] as? UInt16
            ?? AppConstants.defaultHotkeyKeyCode
        self.isEnabled = UserDefaults.standard.object(forKey: AppConstants.globalHotkeyKey + "Enabled") as? Bool
            ?? true  // Enabled by default

        if isEnabled {
            registerMonitors()
        }
    }

    deinit {
        unregisterMonitors()
    }

    // MARK: - Public API

    /// Update the hotkey binding. Per D-07: stores modifier flags + keyCode in UserDefaults.
    func updateShortcut(modifiers: UInt, keyCode: UInt16) {
        self.modifierFlags = modifiers
        self.keyCode = keyCode

        UserDefaults.standard.set(
            ["modifiers": modifiers, "keyCode": keyCode],
            forKey: AppConstants.globalHotkeyKey
        )

        // Re-register monitors with new shortcut
        if isEnabled {
            unregisterMonitors()
            registerMonitors()
        }
    }

    /// Clear/disable the global hotkey per D-08.
    func clearShortcut() {
        isEnabled = false
    }

    // MARK: - NSEvent Monitors

    /// Register BOTH global and local event monitors per D-01.
    /// - addGlobalMonitorForEvents: fires when app is NOT in focus (background)
    /// - addLocalMonitorForEvents: fires when app IS in focus (foreground)
    /// Both are required so the hotkey works from ANY application context.
    private func registerMonitors() {
        // Global monitor (app in background)
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor (app in foreground)
        guard localMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event  // Local monitors must return the event (do not consume it)
        }
    }

    private func unregisterMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    /// Handle key event from either global or local monitor.
    /// Per D-03: Toggle behavior - same shortcut starts and stops recording.
    /// SECURITY: Only matches the exact configured modifier+key combo.
    /// Does NOT log, store, or transmit any key data.
    private func handleKeyEvent(_ event: NSEvent) {
        // Match exact modifier flags and key code
        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        guard eventModifiers == modifierFlags && event.keyCode == keyCode else { return }

        Task { @MainActor [weak self] in
            guard let self, let coordinator = self.recordingCoordinator else { return }
            self.toggleRecording(coordinator)
        }
    }

    /// Per D-03: Toggle behavior matching menu bar single-click toggle from Phase 2 D-04.
    /// Per CONTEXT.md specifics: hotkey is blocked during transcription and analysis states.
    /// IMPORTANT: During transcription/analysis, RecordingState is .completed -- so we must
    /// check TranscriptionStep and AnalysisStep to prevent starting a new recording while
    /// the previous one is still being processed.
    private func toggleRecording(_ coordinator: RecordingCoordinator) {
        let state = coordinator.state

        // Check if transcription or analysis is in progress.
        // Both TranscriptionStep and AnalysisStep have .failed(AssociatedError) with associated values,
        // so use `if case .failed` pattern matching instead of `!= .failed`.
        let transcriptionStep = coordinator.transcriptionService.transcriptionStep
        let analysisStep = coordinator.analysisService.analysisStep

        let isTranscribing: Bool = {
            switch transcriptionStep {
            case .idle, .completed:
                return false
            case .failed:
                return false
            default:
                return true  // .preparing, .sending, .chunkProgress, .processingSpeakers, .saving
            }
        }()

        let isAnalyzing: Bool = {
            switch analysisStep {
            case .idle, .completed:
                return false
            case .failed:
                return false
            default:
                return true  // .preparing, .sending, .processing, .saving
            }
        }()

        guard !isTranscribing && !isAnalyzing else { return }

        switch state {
        case .idle, .completed, .failed:
            coordinator.startRecording()
        case .recording:
            coordinator.stopRecording()
        case .stopping:
            break  // Ignore during transition
        }
    }

    // MARK: - Formatting

    /// Format modifier flags + key code into human-readable string like "Cmd+Shift+R"
    func formatShortcut(modifierFlags: UInt, keyCode: UInt16) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)

        if flags.contains(.control) { parts.append("Ctrl") }
        if flags.contains(.option) { parts.append("Opt") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Cmd") }

        // Map common key codes to characters
        if let keyChar = keyCodeToCharacter(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("Key\(keyCode)")
        }

        return parts.joined(separator: "+")
    }

    private func keyCodeToCharacter(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 10: return "B"; case 11: return "Q"
        case 12: return "W"; case 13: return "E"; case 14: return "R"; case 15: return "T"
        case 16: return "Y"; case 17: return "U"; case 18: return "I"; case 19: return "O"
        case 20: return "P"; case 21: return "["; case 22: return "]"; case 23: return "\\"
        case 24: return "="; case 25: return "J"; case 26: return "K"; case 27: return "-"
        case 28: return "L"; case 29: return ";"; case 30: return "'"; case 31: return "`"
        case 33: return "N"; case 34: return "M"; case 35: return ","
        case 36: return "Return"; case 37: return "L"; case 38: return "/"
        case 39: return "'"; case 40: return "'"
        case 49: return "Space"
        default: return nil
        }
    }
}
