import SwiftUI

struct ErrorSection: View {
    let message: String

    var body: some View {
        Section {
            Text(message)
                .foregroundStyle(TextColor.error)
                .font(AppFont.metadata)
        }
    }
}
