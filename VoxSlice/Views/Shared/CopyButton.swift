import SwiftUI

/// Shared copy-to-clipboard button with visual checkmark feedback.
/// Extracted from MenuBarView for reuse in dashboard detail view per D-10.
struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .controlSize(.small)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Copy")
        .accessibilityHint("Copy this section to clipboard")
    }
}
