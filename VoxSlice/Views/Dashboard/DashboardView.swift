import SwiftUI

/// Root dashboard view using NavigationSplitView per D-02.
/// Shows sidebar with recording history on the left and detail view on the right.
struct DashboardView: View {
    @State var selectedRecordingId: UUID?
    @Environment(AppDelegate.self) var appDelegate

    var body: some View {
        NavigationSplitView {
            SidebarView(
                historyService: appDelegate.recordingHistoryService,
                selectedRecordingId: $selectedRecordingId
            )
            .frame(minWidth: 200)
        } detail: {
            if let selectedId = selectedRecordingId,
               let item = appDelegate.recordingHistoryService.recordings.first(where: { $0.id == selectedId }) {
                DetailView(item: item, coordinator: appDelegate.recordingCoordinator)
            } else {
                DetailPlaceholderView()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            appDelegate.recordingHistoryService.loadRecordings()
        }
    }
}
