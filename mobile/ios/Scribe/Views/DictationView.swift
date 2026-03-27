import SwiftUI

// MARK: - Dictation view (Story 14.3)

/// Full-screen dictation view for creating new threads via voice input.
/// Uses SpeechTranscriptionService for live transcription via Apple Speech framework.
struct DictationView: View {
    @StateObject private var speechService = SpeechTranscriptionService()
    @StateObject private var inboxService = ICloudInboxService()

    @State private var showConfirmation = false
    @State private var createdThreadTitle: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Live transcription area
                transcriptionArea

                Spacer()

                // Recording controls
                recordingControls

                // Status text
                statusText

                // Action buttons
                actionButtons

                Spacer()
            }
            .padding()
            .navigationTitle("Dictate")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                inboxService.startMonitoring()
            }
            .onDisappear {
                speechService.stopTranscription()
                inboxService.stopMonitoring()
            }
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                }
            }
        }
    }

    // MARK: - Transcription area

    private var transcriptionArea: some View {
        Group {
            if speechService.transcribedText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Tap the microphone to start dictating")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView {
                    Text(speechService.transcribedText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 250)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("14.3-transcription-text")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Recording controls

    private var recordingControls: some View {
        Button {
            if speechService.isTranscribing {
                speechService.stopTranscription()
            } else {
                speechService.startTranscription(silenceTimeout: 5.0, maxDuration: 120.0)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(speechService.isTranscribing ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: speechService.isTranscribing ? "stop.fill" : "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(speechService.isTranscribing ? .red : .blue)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(speechService.isTranscribing ? 1.08 : 1.0)
        .animation(.spring(duration: 0.25), value: speechService.isTranscribing)
        .accessibilityLabel(speechService.isTranscribing ? "Stop dictation" : "Start dictation")
        .accessibilityIdentifier("14.3-dictation-button")
    }

    // MARK: - Status

    private var statusText: some View {
        Group {
            if speechService.isTranscribing {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Listening...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = speechService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !speechService.transcribedText.isEmpty {
                Text("Review and send, or re-record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to dictate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        Group {
            if !speechService.transcribedText.isEmpty && !speechService.isTranscribing {
                HStack(spacing: 16) {
                    // Cancel
                    Button {
                        speechService.transcribedText = ""
                    } label: {
                        Label("Discard", systemImage: "trash")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityIdentifier("14.3-cancel-button")

                    // Send
                    Button {
                        sendThread()
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityIdentifier("14.3-send-button")
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Confirmation overlay

    private var confirmationOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Thread Created")
                .font(.headline)
            if let title = createdThreadTitle {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private func sendThread() {
        let text = speechService.transcribedText
        guard !text.isEmpty else { return }

        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()

        if let _ = inboxService.createThread(transcription: text) {
            let titleRaw = String(text.prefix(50))
            createdThreadTitle = text.count > 50 ? titleRaw + "..." : titleRaw

            withAnimation(.spring(duration: 0.3)) {
                showConfirmation = true
            }

            // Reset after showing confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showConfirmation = false
                }
                speechService.transcribedText = ""
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DictationView()
}
