import Foundation

// MARK: - Message role

enum MessageRole: String {
    case user
    case assistant

    var isUser: Bool { self == .user }
}

// MARK: - Thread message

struct ThreadMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let timestamp: String
    let content: String

    init(role: MessageRole, timestamp: String, content: String) {
        self.id = UUID()
        self.role = role
        self.timestamp = timestamp
        self.content = content
    }

    /// Parse all messages from a thread .md file content.
    /// Messages are delimited by `## Role -- Time` headers.
    /// Example:
    /// ```
    /// ## User -- 10:30 AM
    /// Hello, please review this.
    ///
    /// ## Assistant -- 10:31 AM
    /// I've reviewed it and...
    /// ```
    static func parseMessages(from content: String) -> [ThreadMessage] {
        // Strip frontmatter first
        let body = stripFrontmatter(from: content)

        // Split on ## headers
        let pattern = ##"## (User|Assistant) [—\-]+ (.+)"##
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsBody = body as NSString
        let matches = regex.matches(in: body, options: [], range: NSRange(location: 0, length: nsBody.length))

        guard !matches.isEmpty else { return [] }

        var messages: [ThreadMessage] = []

        for (i, match) in matches.enumerated() {
            guard match.numberOfRanges >= 3 else { continue }

            let roleString = nsBody.substring(with: match.range(at: 1)).lowercased()
            let timestamp = nsBody.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)

            let role: MessageRole = roleString == "user" ? .user : .assistant

            // Content is between end of this header line and start of next header (or end of string)
            let headerEnd = match.range.location + match.range.length
            let contentEnd: Int
            if i + 1 < matches.count {
                contentEnd = matches[i + 1].range.location
            } else {
                contentEnd = nsBody.length
            }

            let contentRange = NSRange(location: headerEnd, length: contentEnd - headerEnd)
            let messageContent = nsBody.substring(with: contentRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !messageContent.isEmpty {
                messages.append(ThreadMessage(role: role, timestamp: timestamp, content: messageContent))
            }
        }

        return messages
    }

    // MARK: - Private

    /// Remove YAML frontmatter (between --- delimiters) from content.
    private static func stripFrontmatter(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)

        guard let firstDelimiter = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return content
        }

        let afterFirst = firstDelimiter + 1
        guard afterFirst < lines.count else { return content }

        guard let secondDelimiter = lines[afterFirst...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return content
        }

        let bodyLines = Array(lines[(secondDelimiter + 1)...])
        return bodyLines.joined(separator: "\n")
    }
}
