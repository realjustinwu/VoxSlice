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
    private(set) lazy var recordingHistoryService = RecordingHistoryService(
        storageService: storageService
    )
    var permissionsWindow: NSWindow?
    var dashboardWindow: NSWindow?

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

    // MARK: - Dashboard Window

    /// Opens the dashboard window, or brings it to front if already open.
    /// Managed as raw NSWindow via AppDelegate (same pattern as permissionsWindow)
    /// since LSUIElement=true complicates SwiftUI WindowGroup behavior.
    func showDashboardWindow() {
        if let window = dashboardWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Restore saved frame or use default per UI-SPEC
        let defaultFrame = NSRect(x: 0, y: 0, width: 1000, height: 650)
        let frameString = UserDefaults.standard.string(forKey: AppConstants.dashboardWindowFrame)
        let contentRect = frameString.flatMap { NSRectFromString($0) } ?? defaultFrame

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxSlice"
        window.minSize = NSSize(width: 800, height: 500)
        window.contentView = NSHostingView(rootView: DashboardView().environment(self))
        window.delegate = self

        // Only center on first launch (when no saved frame)
        if frameString == nil {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        dashboardWindow = window
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    nonisolated func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: AppConstants.dashboardWindowFrame)
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Task { @MainActor in
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: AppConstants.dashboardWindowFrame)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of destroying it per D-03
        sender.orderOut(nil)
        return false
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
