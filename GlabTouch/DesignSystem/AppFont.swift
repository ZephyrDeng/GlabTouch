import SwiftUI

enum AppFont {
    /// Semibold 17pt — MR titles, pipeline titles, section headers
    static let title: Font = .headline
    /// Regular 15pt — descriptions, subtitles, job names
    static let body: Font = .subheadline
    /// Regular 12pt — author names, MR IDs, timestamps
    static let metadata: Font = .caption
    /// Regular 11pt — branch refs, file paths in compact rows
    static let tertiary: Font = .caption2
    /// Regular 12pt monospaced — commit SHAs, diff lines, trace output
    static let mono: Font = .system(.caption, design: .monospaced)
}
