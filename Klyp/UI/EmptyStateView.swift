import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        Text("No clipboard history yet")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("No clipboard history yet")
    }
}
