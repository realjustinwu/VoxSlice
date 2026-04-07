import SwiftUI

/// A view for a single transcript segment block per D-09 and UI-SPEC.
/// Displays speaker label, timestamp bracket, and segment text.
/// Clickable for audio seek (wired in Plan 03).
struct TranscriptSegmentView: View {
    let segment: Segment
    let speakerLabel: String
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                // Left accent bar when highlighted per D-15
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(width: 3)
                        .padding(.trailing, 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Speaker label + timestamp row
                    HStack {
                        Text(speakerLabel)
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        Text("[\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))]")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Segment text
                    Text(segment.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(speakerLabel), [\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))], \(segment.text)")
    }

    // MARK: - Helpers

    /// Format time in MM:SS format per UI-SPEC.
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
