import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("saveLocation") private var saveLocation: SaveLocation = .localOnly
    @AppStorage("audioFormat") private var audioFormat: AudioFormat = .wav
    @AppStorage("customFolderBookmark") private var bookmarkData: Data?
    @State private var showingFolderPicker = false

    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var customFolderURL: URL? {
        guard let data = bookmarkData else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) else { return nil }
        if isStale {
            bookmarkData = try? url.bookmarkData(options: [],
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
        }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                saveLocationSection
                audioFormatSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var saveLocationSection: some View {
        Section {
            Picker("Save Location", selection: $saveLocation) {
                ForEach(SaveLocation.allCases) { location in
                    HStack {
                        Text(location.label)
                        if location == .iCloud && !iCloudAvailable {
                            Spacer()
                            Text("Not signed in")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(location)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("7.5-save-location-picker")

            if saveLocation == .iCloud && !iCloudAvailable {
                Label("Sign in to iCloud in Settings to enable sync.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if saveLocation == .customFolder {
                if let folderName = customFolderURL?.lastPathComponent {
                    Label("Selected: \(folderName)", systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Choose Folder") {
                    showingFolderPicker = true
                }
                .accessibilityIdentifier("7.5-folder-picker-button")
                .sheet(isPresented: $showingFolderPicker) {
                    FolderPickerView { url in
                        guard url.startAccessingSecurityScopedResource() else { return }
                        defer { url.stopAccessingSecurityScopedResource() }

                        if let data = try? url.bookmarkData(options: [],
                                                             includingResourceValuesForKeys: nil,
                                                             relativeTo: nil) {
                            bookmarkData = data
                        }
                    }
                }
            }
        } header: {
            Text("Save Location")
        } footer: {
            switch saveLocation {
            case .iCloud:
                Text("Recordings are copied to iCloud Drive and available on all your devices.")
            case .customFolder:
                Text("Recordings are saved to your chosen folder. Select an iCloud Drive folder for cross-device sync.")
            case .localOnly:
                Text("Recordings are stored in this app's Documents folder on this device only.")
            }
        }
    }

    private var audioFormatSection: some View {
        Section {
            Picker("Audio Format", selection: $audioFormat) {
                ForEach(AudioFormat.allCases) { format in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(format.label)
                        Text(format.sizeEstimate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("7.7-format-picker")
        } header: {
            Text("Audio Format")
        } footer: {
            Text("Estimated file size for a 1-minute recording.")
        }
    }
}

// MARK: - Supporting types

enum SaveLocation: String, CaseIterable, Identifiable {
    case localOnly
    case iCloud
    case customFolder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localOnly:    return "Local Only"
        case .iCloud:       return "iCloud Drive"
        case .customFolder: return "Custom Folder"
        }
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case wav
    case m4a

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wav: return "WAV (Lossless)"
        case .m4a: return "M4A (Compressed)"
        }
    }

    var sizeEstimate: String {
        switch self {
        case .wav: return "~10 MB / min"
        case .m4a: return "~1 MB / min"
        }
    }
}

// MARK: - Folder Picker

struct FolderPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - iCloud save helper (called after a recording is saved)

extension SettingsView {
    /// Copies a local recording to iCloud Drive if iCloud save is enabled.
    static func copyToICloudIfNeeded(localURL: URL) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "saveLocation") == SaveLocation.iCloud.rawValue else { return }
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents") else { return }

        let destURL = containerURL.appendingPathComponent(localURL.lastPathComponent)
        try? FileManager.default.setUbiquitous(true, itemAt: localURL, destinationURL: destURL)
    }

    /// Copies a local recording to the user's chosen custom folder.
    static func copyToCustomFolderIfNeeded(localURL: URL) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "saveLocation") == SaveLocation.customFolder.rawValue else { return }
        guard let bookmarkData = defaults.data(forKey: "customFolderBookmark") else { return }

        var isStale = false
        guard let folderURL = try? URL(resolvingBookmarkData: bookmarkData,
                                        options: [],
                                        relativeTo: nil,
                                        bookmarkDataIsStale: &isStale) else { return }

        guard folderURL.startAccessingSecurityScopedResource() else { return }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        let destURL = folderURL.appendingPathComponent(localURL.lastPathComponent)
        try? FileManager.default.copyItem(at: localURL, to: destURL)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
