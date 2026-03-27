import Foundation

// MARK: - Thread status

enum ThreadStatus: String, CaseIterable {
    case active
    case processing
    case completed
    case failed

    var label: String {
        switch self {
        case .active:     return "Active"
        case .processing: return "Processing"
        case .completed:  return "Completed"
        case .failed:     return "Failed"
        }
    }

    var iconName: String {
        switch self {
        case .active:     return "circle.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed:  return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .active:     return "blue"
        case .processing: return "orange"
        case .completed:  return "green"
        case .failed:     return "red"
        }
    }
}

// MARK: - Thread metadata

struct ThreadMetadata: Identifiable, Equatable {
    let id: String
    let title: String
    let agent: String
    let status: ThreadStatus
    let created: Date
    let updated: Date
    let hasCompletionMarker: Bool
    let fileURL: URL

    /// Parse YAML frontmatter from a thread .md file.
    /// Expected format:
    /// ```
    /// ---
    /// id: abc-123
    /// title: "Some title"
    /// agent: default
    /// status: active
    /// created: 2026-03-04T10:30:00Z
    /// updated: 2026-03-04T10:31:45Z
    /// completion_marker: 2026-03-04T10:31:45Z  (optional)
    /// ---
    /// ```
    static func parse(from fileURL: URL) -> ThreadMetadata? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(content: content, fileURL: fileURL)
    }

    static func parse(content: String, fileURL: URL) -> ThreadMetadata? {
        let frontmatter = extractFrontmatter(from: content)
        guard !frontmatter.isEmpty else { return nil }

        guard let id = frontmatter["id"] else { return nil }

        let title = frontmatter["title"]?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? "Untitled"

        let agent = frontmatter["agent"] ?? "default"

        let status = ThreadStatus(rawValue: frontmatter["status"] ?? "active") ?? .active

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let iso8601NoFrac = ISO8601DateFormatter()
        iso8601NoFrac.formatOptions = [.withInternetDateTime]

        let created = parseDate(frontmatter["created"], formatters: [iso8601, iso8601NoFrac]) ?? Date()
        let updated = parseDate(frontmatter["updated"], formatters: [iso8601, iso8601NoFrac]) ?? created

        let hasCompletionMarker = frontmatter["completion_marker"] != nil

        return ThreadMetadata(
            id: id,
            title: title,
            agent: agent,
            status: status,
            created: created,
            updated: updated,
            hasCompletionMarker: hasCompletionMarker,
            fileURL: fileURL
        )
    }

    // MARK: - Private helpers

    /// Extract key-value pairs from YAML frontmatter delimited by `---`.
    private static func extractFrontmatter(from content: String) -> [String: String] {
        let lines = content.components(separatedBy: .newlines)

        guard let firstDelimiter = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return [:]
        }

        let afterFirst = firstDelimiter + 1
        guard afterFirst < lines.count else { return [:] }

        guard let secondDelimiter = lines[afterFirst...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return [:]
        }

        var result: [String: String] = [:]
        for i in afterFirst..<secondDelimiter {
            let line = lines[i]
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty && !value.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private static func parseDate(_ string: String?, formatters: [ISO8601DateFormatter]) -> Date? {
        guard let string else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
