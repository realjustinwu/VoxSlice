import SwiftUI

// AppDelegate manages the permissions window lifecycle and service dependencies
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionManager = PermissionManager()
    let storageService = StorageService()
    private(set) lazy var audioCaptureService = AudioCaptureService(
        storageService: storageService,
        permissionManager: permissionManager
    )
    private(set) lazy var transcriptionService = TranscriptionService(
        storageService: storageService
    )
    private(set) lazy var analysisService = AnalysisService(storageService: storageService)
    private(set) lazy var recordingCoordinator: RecordingCoordinator = {
        RecordingCoordinator(
            audioCaptureService: audioCaptureService,
            storageService: storageService,
            permissionManager: permissionManager,
            transcriptionService: transcriptionService,
            analysisService: analysisService
        )
    }()
    var permissionsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Per D-16: Show permissions window on first launch if any permission missing
        if permissionManager.hasMissingPermissions {
            showPermissionsWindow()
        }
    }

    func showPermissionsWindow() {
        // Per D-16: Show permissions window if permissions are missing
        let contentView = PermissionsView(permissionManager: permissionManager)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxSlice Permissions"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        permissionsWindow = window
    }
}

@main
struct VoxSliceApp: App {
    // Per D-16: Register AppDelegate to manage permissions window
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Computed menu bar icon per UI-SPEC:
    /// Priority: recording > transcription failed > transcribing > analysis failed > analyzing > analysis complete > idle
    private var menuBarIcon: String {
        let recordingState = appDelegate.recordingCoordinator.state
        let transcriptionStep = appDelegate.recordingCoordinator.transcriptionService.transcriptionStep
        let analysisStep = appDelegate.recordingCoordinator.analysisService.analysisStep

        if recordingState == .recording {
            return "record.circle"
        } else if case .failed = transcriptionStep {
            return "exclamationmark.triangle"
        } else if transcriptionStep != .idle && transcriptionStep != .completed {
            return "doc.text.below.ecg"
        } else if case .failed = analysisStep {
            return "exclamationmark.triangle"
        } else if analysisStep == .preparing || analysisStep == .sending || analysisStep == .processing || analysisStep == .saving {
            return "sparkles"
        } else if analysisStep == .completed {
            return "checkmark.circle"
        } else {
            return "waveform.circle"
        }
    }

    var body: some Scene {
        MenuBarExtra("VoxSlice", systemImage: menuBarIcon) {
            MenuBarView(coordinator: appDelegate.recordingCoordinator)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                storageService: appDelegate.storageService,
                transcriptionService: appDelegate.transcriptionService,
                analysisService: appDelegate.analysisService
            )
        }
    }
}
