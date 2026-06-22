import SwiftUI

struct PipelineStatusBadge: View {
    let status: Pipeline.Status

    var body: some View {
        Label(status.displayName, systemImage: status.iconName)
            .font(AppFont.metadata)
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
        case .canceling: String(localized: "Canceling")
        case .waitingForCallback: String(localized: "Waiting")
        case .waitingForResource: String(localized: "Waiting")
        }
    }

    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .running: "play.circle.fill"
        case .pending, .waiting, .preparing, .created, .waitingForCallback, .waitingForResource: "clock.fill"
        case .canceled: "minus.circle.fill"
        case .skipped: "forward.fill"
        case .manual: "hand.raised.fill"
        case .scheduled: "calendar.circle.fill"
        case .canceling: "stop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: StatusColor.success
        case .failed: StatusColor.failed
        case .running: StatusColor.running
        case .pending, .waiting, .preparing, .created, .waitingForCallback, .waitingForResource: StatusColor.pending
        case .canceled, .skipped: StatusColor.canceled
        case .manual: StatusColor.manual
        case .scheduled: StatusColor.scheduled
        case .canceling: StatusColor.pending
        }
    }
}
