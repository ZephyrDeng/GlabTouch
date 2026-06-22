import SwiftUI

struct ErrorSection: View {
    let message: String

    var body: some View {
        Section {
            ErrorText(message: message)
        }
    }
}

struct ErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundStyle(TextColor.error)
            .font(AppFont.metadata)
    }
}
