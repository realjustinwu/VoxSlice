import SwiftUI

/// Placeholder view when no recording is selected, per D-11.
/// Centered vertically and horizontally with app icon and prompt text.
struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Select a recording to view details")
                .font(.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
