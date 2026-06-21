import Foundation

struct DiffFile: Identifiable, Hashable, Decodable {
    let oldPath: String
    let newPath: String
    let diff: String
    let newFile: Bool
    let renamedFile: Bool
    let deletedFile: Bool

    var id: String { "\(oldPath)->\(newPath)" }
    var displayPath: String { newPath.isEmpty ? oldPath : newPath }
    var lines: [DiffLine] { DiffParser.parse(diff) }

    enum CodingKeys: String, CodingKey {
        case oldPath = "old_path"
        case newPath = "new_path"
        case diff
        case newFile = "new_file"
        case renamedFile = "renamed_file"
        case deletedFile = "deleted_file"
    }
}

struct DiffLine: Identifiable, Hashable {
    let id = UUID()
    let kind: Kind
    let content: String

    enum Kind: Hashable {
        case hunk
        case context
        case addition
        case deletion
        case metadata
    }
}

enum DiffParser {
    static func parse(_ diff: String) -> [DiffLine] {
        diff.split(separator: "\n", omittingEmptySubsequences: false).map { rawLine in
            let line = String(rawLine)

            if line.hasPrefix("@@") {
                return DiffLine(kind: .hunk, content: line)
            }
            if line.hasPrefix("\\") {
                return DiffLine(kind: .metadata, content: line)
            }
            if line.hasPrefix("+") {
                return DiffLine(kind: .addition, content: String(line.dropFirst()))
            }
            if line.hasPrefix("-") {
                return DiffLine(kind: .deletion, content: String(line.dropFirst()))
            }
            if line.hasPrefix(" ") {
                return DiffLine(kind: .context, content: String(line.dropFirst()))
            }

            return DiffLine(kind: .context, content: line)
        }
    }
}
