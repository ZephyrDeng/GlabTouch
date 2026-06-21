import Foundation

enum GitLabBaseURLNormalizer {
    static func normalize(_ input: String) -> URL? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        let candidate = trimmedInput.contains("://") ? trimmedInput : "https://\(trimmedInput)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else { return nil }

        return url
    }
}
