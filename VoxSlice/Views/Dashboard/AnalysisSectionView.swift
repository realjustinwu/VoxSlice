import SwiftUI

/// A reusable section view for displaying one analysis section per D-10.
/// Shows section title with trailing CopyButton, and content below.
struct AnalysisSectionView<Content: View>: View {
    let title: String
    let copyText: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row with CopyButton
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                CopyButton(text: copyText)
            }

            // Section content
            content()
        }
        .padding(.top, 16)
    }
}
