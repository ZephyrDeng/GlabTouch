import SwiftUI

struct PipelineStatusBadge: View {
    let status: Pipeline.Status

    var body: some View {
        Label(status.displayName, systemImage: status.iconName)
            .font(.caption)
            .foregroundStyle(status.color)
    }
}

extension Pipeline.Status {
    var displayName: String {
        switch self {
        case .created: String(localized: "Created")
        case .waiting: String(localized: "Waiting")
        case .preparing: String(localized: "Preparing")
        case .pending: String(localized: "Pending")
        case .running: String(localized: "Running")
        case .success: String(localized: "Passed")
        case .failed: String(localized: "Failed")
        case .canceled: String(localized: "Canceled")
        case .skipped: String(localized: "Skipped")
        case .manual: String(localized: "Manual")
        case .scheduled: String(localized: "Scheduled")
        }
    }

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .running: "play.circle.fill"
        case .pending, .waiting, .preparing, .created: "clock.fill"
        case .canceled: "minus.circle.fill"
        case .skipped: "forward.fill"
        case .manual: "hand.raised.fill"
        case .scheduled: "calendar.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failed: .red
        case .running: .blue
        case .pending, .waiting, .preparing, .created: .orange
        case .canceled, .skipped: .gray
        case .manual: .purple
        case .scheduled: .teal
        }
    }
}
