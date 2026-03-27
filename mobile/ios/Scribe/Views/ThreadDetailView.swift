import SwiftUI

// MARK: - Thread detail view

struct ThreadDetailView: View {
    let thread: ThreadMetadata

    @State private var messages: [ThreadMessage] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            // Messages
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if messages.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                messageList
            }
        }
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadMessages)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            statusIndicator
            Text(thread.status.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)

            Spacer()

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .accessibilityIdentifier("14.2-status-bar")
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch thread.status {
        case .active, .processing:
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityIdentifier("14.2-status-spinner")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
                .accessibilityIdentifier("14.2-status-checkmark")
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
                .accessibilityIdentifier("14.2-status-failed")
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                // Scroll to bottom (most recent message)
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No messages yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch thread.status {
        case .active:     return .blue
        case .processing: return .orange
        case .completed:  return .green
        case .failed:     return .red
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: thread.updated)
    }

    private func loadMessages() {
        guard let content = try? String(contentsOf: thread.fileURL, encoding: .utf8) else {
            isLoading = false
            return
        }
        messages = ThreadMessage.parseMessages(from: content)
        isLoading = false
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ThreadMessage

    var body: some View {
        HStack {
            if message.role.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role.isUser ? .trailing : .leading, spacing: 4) {
                // Timestamp
                Text(message.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Bubble
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role.isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !message.role.isUser {
                Spacer(minLength: 60)
            }
        }
        .accessibilityIdentifier("14.2-message-\(message.role.rawValue)")
    }

    private var bubbleColor: Color {
        message.role.isUser ? .blue : Color(.systemGray5)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThreadDetailView(
            thread: ThreadMetadata(
                id: "preview-123",
                title: "Preview Thread",
                agent: "default",
                status: .completed,
                created: Date(),
                updated: Date(),
                hasCompletionMarker: true,
                fileURL: URL(fileURLWithPath: "/tmp/preview.md")
            )
        )
    }
}
