import SwiftUI

/// Sidebar recording list with search bar, status dots, and rich row layout per D-04 through D-07.
struct SidebarView: View {
    let historyService: RecordingHistoryService
    @Binding var selectedRecordingId: UUID?
    @State private var searchDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar at top (sticky, does not scroll) per D-07
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search recordings...", text: searchBinding)
                    .textFieldStyle(.plain)
                    .font(.body)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Recording list or empty state
            if historyService.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.regular)
                Spacer()
            } else if historyService.filteredRecordings.isEmpty {
                emptyState
            } else {
                List(historyService.filteredRecordings, selection: $selectedRecordingId) { item in
                    recordingRow(item)
                        .tag(item.id)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200)
    }

    // MARK: - Search Binding with 300ms Debounce

    /// A binding that debounces search text changes by 300ms per D-07.
    private var searchBinding: Binding<String> {
        Binding<String>(
            get: { historyService.searchText },
            set: { newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    historyService.searchText = newValue
                }
            }
        )
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if historyService.searchText.isEmpty {
            // No recordings at all
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No recordings yet")
                    .font(.headline)
                Text("Record your first meeting to see it here.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            // No search results
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No recordings match your search.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    // MARK: - Recording Row

    @ViewBuilder
    private func recordingRow(_ item: RecordingHistoryItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Status dot per D-06
            Circle()
                .fill(statusColor(for: item.status))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                // Date/time line per UI-SPEC
                Text(formattedDate(item.recording.startTime))
                    .font(.headline)

                // Title line with trailing duration
                HStack {
                    Text(item.displayTitle)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(formattedDuration(item.recording.duration))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                // Summary preview line
                if let summary = item.displaySummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Speaker count line
                if let transcript = item.transcript {
                    Text("\(transcript.speakers.count) speakers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayTitle), \(formattedDate(item.recording.startTime)), \(formattedDuration(item.recording.duration)), \(statusDescription(for: item.status))")
    }

    // MARK: - Helpers

    /// Format date as "Apr 7, 2026 at 2:30 PM" per UI-SPEC copywriting contract.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    /// Format duration as "Xm Ys" per UI-SPEC copywriting contract.
    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    /// Status dot color per D-06.
    private func statusColor(for status: ProcessingStatus) -> Color {
        switch status {
        case .completed: return .green
        case .transcribing, .analyzing: return .orange
        case .failed: return .red
        case .new, .transcribed: return Color(NSColor.tertiaryLabelColor)
        }
    }

    /// Human-readable status description for accessibility.
    private func statusDescription(for status: ProcessingStatus) -> String {
        switch status {
        case .new: return "not processed"
        case .transcribing: return "transcribing"
        case .transcribed: return "transcribed"
        case .analyzing: return "analyzing"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }
}
