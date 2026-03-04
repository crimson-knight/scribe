import SwiftUI
import AVFoundation

struct RecordingsListView: View {
    @ObservedObject var model: AudioRecorderModel
    @State private var recordingFiles: [RecordingFile] = []
    @State private var deleteTarget: RecordingFile? = nil
    @State private var showDeleteAlert = false
    @State private var playingPath: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if recordingFiles.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(recordingFiles) { file in
                            recordingRow(file)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTarget = file
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityIdentifier("7.3-recordings-list")
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: loadRecordings)
            .onChange(of: model.savedRecordings) { _ in loadRecordings() }
            .alert("Delete Recording?", isPresented: $showDeleteAlert, presenting: deleteTarget) { file in
                Button("Delete", role: .destructive) { deleteFile(file) }
                Button("Cancel", role: .cancel) {}
            } message: { file in
                Text("\"\(file.name)\" will be permanently deleted.")
            }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No recordings yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the Record tab to capture audio.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityIdentifier("7.3-empty-state")
    }

    @ViewBuilder
    private func recordingRow(_ file: RecordingFile) -> some View {
        Button {
            handleTap(file)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: playingPath == file.path ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(playingPath == file.path ? .red : .blue)
                    .accessibilityIdentifier("7.3-play-button")

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(file.formattedDate)
                        Text("·")
                        Text(file.formattedSize)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("7.3-recording-row-\(file.name)")
    }

    // MARK: - Actions

    private func handleTap(_ file: RecordingFile) {
        if playingPath == file.path {
            let _ = scribe_stop_playback()
            playingPath = nil
        } else {
            // Stop existing playback first
            if playingPath != nil {
                let _ = scribe_stop_playback()
            }
            let result = scribe_start_playback(file.path)
            playingPath = result == 0 ? file.path : nil
        }
    }

    private func loadRecordings() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let files = (try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        recordingFiles = files
            .filter { $0.pathExtension.lowercased() == "wav" }
            .compactMap { url -> RecordingFile? in
                let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                return RecordingFile(
                    path: url.path,
                    name: url.deletingPathExtension().lastPathComponent,
                    creationDate: attrs?.creationDate ?? Date.distantPast,
                    fileSize: attrs?.fileSize ?? 0
                )
            }
            .sorted { $0.creationDate > $1.creationDate }
    }

    private func deleteFile(_ file: RecordingFile) {
        try? FileManager.default.removeItem(atPath: file.path)
        if playingPath == file.path {
            let _ = scribe_stop_playback()
            playingPath = nil
        }
        loadRecordings()
    }
}

// MARK: - Model

struct RecordingFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let creationDate: Date
    let fileSize: Int

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: creationDate, relativeTo: Date())
    }

    var formattedSize: String {
        let bytes = Double(fileSize)
        if bytes < 1_000_000 {
            return String(format: "%.0f KB", bytes / 1_000)
        }
        return String(format: "%.1f MB", bytes / 1_000_000)
    }
}
