import SwiftUI

/// A view for missing transcript or analysis states per D-12 and UI-SPEC.
/// Shows icon, title, message, and retry button centered in a card.
struct MissingDataView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(buttonTitle, action: onRetry)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Retry the failed operation")
    }
}
