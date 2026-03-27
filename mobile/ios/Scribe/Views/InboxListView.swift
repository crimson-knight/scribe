import SwiftUI

// MARK: - Inbox list view

struct InboxListView: View {
    @StateObject private var inboxService = ICloudInboxService()
    @State private var showQuickDictation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if inboxService.isLoading {
                        loadingState
                    } else if !inboxService.iCloudAvailable {
                        iCloudUnavailableState
                    } else if inboxService.threads.isEmpty {
                        emptyState
                    } else {
                        threadList
                    }
                }

                // Quick dictation FAB (Story 14.4)
                if inboxService.iCloudAvailable {
                    quickDictationFAB
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                inboxService.startMonitoring()
            }
            .onDisappear {
                inboxService.stopMonitoring()
            }
            .sheet(isPresented: $showQuickDictation) {
                QuickDictationOverlay(inboxService: inboxService)
            }
        }
        .accessibilityIdentifier("14.1-inbox-tab")
    }

    // MARK: - Thread list

    private var threadList: some View {
        List(inboxService.threads) { thread in
            NavigationLink(destination: ThreadDetailView(thread: thread)) {
                ThreadRowView(thread: thread)
            }
            .accessibilityIdentifier("14.1-thread-row-\(thread.id)")
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("14.1-thread-list")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No threads yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the microphone button to dictate a new thread.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier("14.1-inbox-empty")
    }

    // MARK: - iCloud unavailable

    private var iCloudUnavailableState: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("iCloud Required")
                .font(.headline)
            Text("Sign in to iCloud in Settings to use the inbox. Threads sync between your devices via iCloud Drive.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.callout)
        }
        .padding()
    }

    // MARK: - Loading state

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading inbox...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick dictation FAB (Story 14.4)

    private var quickDictationFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showQuickDictation = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .accessibilityLabel("Quick dictation")
                .accessibilityIdentifier("14.4-quick-dictation-fab")
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Thread row view

private struct ThreadRowView: View {
    let thread: ThreadMetadata

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(thread.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Metadata line
                HStack(spacing: 6) {
                    Text(thread.status.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Unread indicator for active threads
            if thread.status == .active {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        Image(systemName: thread.status.iconName)
            .font(.system(size: 20))
            .foregroundStyle(statusColor)
            .frame(width: 28, height: 28)
    }

    private var statusColor: Color {
        switch thread.status {
        case .active:     return .blue
        case .processing: return .orange
        case .completed:  return .green
        case .failed:     return .red
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: thread.updated, relativeTo: Date())
    }
}

// MARK: - Quick dictation overlay (Story 14.4)

struct QuickDictationOverlay: View {
    let inboxService: ICloudInboxService
    @StateObject private var speechService = SpeechTranscriptionService()
    @Environment(\.dismiss) private var dismiss

    @State private var hasFinished = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button("Cancel") {
                    speechService.stopTranscription()
                    dismiss()
                }
                .accessibilityIdentifier("14.4-cancel-button")

                Spacer()

                Text("Quick Dictation")
                    .font(.headline)

                Spacer()

                // Balance the cancel button
                Color.clear.frame(width: 60)
            }
            .padding()

            Spacer()

            // Transcription text
            if speechService.transcribedText.isEmpty && speechService.isTranscribing {
                Text("Listening...")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("14.4-listening-label")
            } else if !speechService.transcribedText.isEmpty {
                ScrollView {
                    Text(speechService.transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .accessibilityIdentifier("14.4-transcription-text")
            }

            Spacer()

            // Recording indicator
            if speechService.isTranscribing {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .scaleEffect(speechService.isTranscribing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(), value: speechService.isTranscribing)

                    Text("Recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Send button (shown when we have text and stopped)
            if !speechService.transcribedText.isEmpty && !speechService.isTranscribing {
                Button {
                    createThreadAndDismiss()
                } label: {
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .accessibilityIdentifier("14.4-send-button")
            }

            // Error message
            if let error = speechService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .onAppear {
            speechService.startTranscription(silenceTimeout: 3.0, maxDuration: 60.0)
        }
        .onChange(of: speechService.didAutoStop) { stopped in
            if stopped && !speechService.transcribedText.isEmpty && !hasFinished {
                createThreadAndDismiss()
            } else if stopped && speechService.transcribedText.isEmpty {
                // No speech detected
                speechService.errorMessage = "No speech detected."
            }
        }
    }

    private func createThreadAndDismiss() {
        guard !hasFinished else { return }
        hasFinished = true

        let text = speechService.transcribedText
        guard !text.isEmpty else {
            dismiss()
            return
        }

        let _ = inboxService.createThread(transcription: text)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    InboxListView()
}
