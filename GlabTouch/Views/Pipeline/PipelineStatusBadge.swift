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
        case .created: "Created"
        case .waiting: "Waiting"
        case .preparing: "Preparing"
        case .pending: "Pending"
        case .running: "Running"
        case .success: "Passed"
        case .failed: "Failed"
        case .canceled: "Canceled"
        case .skipped: "Skipped"
        case .manual: "Manual"
        case .scheduled: "Scheduled"
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
