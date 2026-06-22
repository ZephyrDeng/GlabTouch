import SwiftUI

// MARK: - Status Colors

enum StatusColor {
    static let success: Color = .green
    static let failed: Color = .red
    static let running: Color = .blue
    static let pending: Color = .orange
    static let canceled: Color = .gray
    static let manual: Color = .purple
    static let scheduled: Color = .teal
}

// MARK: - Diff Colors

enum DiffColor {
    static let additionForeground: Color = .green
    static let deletionForeground: Color = .red
    static let hunkForeground: Color = .blue
    static let metadataForeground: Color = .secondary
    static let contextForeground: Color = .primary

    static let additionBackground = Color.green.opacity(0.12)
    static let deletionBackground = Color.red.opacity(0.12)
    static let hunkBackground = Color.blue.opacity(0.10)
    static let metadataBackground = Color.secondary.opacity(0.08)
    static let contextBackground = Color.clear
}

// MARK: - Text Colors

enum TextColor {
    static let primary: Color = .primary
    static let secondary: Color = .secondary
    static let tertiary: Color = .secondary.opacity(0.6)
    static let error: Color = .red
    static let approved: Color = .green
}
