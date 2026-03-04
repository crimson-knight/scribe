import SwiftUI

struct SettingsView: View {
    @AppStorage("saveLocation") private var saveLocation: SaveLocation = .localOnly
    @AppStorage("audioFormat") private var audioFormat: AudioFormat = .wav

    private var iCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
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
        } header: {
            Text("Save Location")
        } footer: {
            Text(saveLocation == .iCloud
                 ? "Recordings are copied to iCloud Drive and available on all your devices."
                 : "Recordings are stored in this app's Documents folder on this device only.")
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

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localOnly: return "Local Only"
        case .iCloud:    return "iCloud Drive"
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

// MARK: - iCloud save helper (called after a recording is saved)

extension SettingsView {
    /// Copies a local recording to iCloud Drive if iCloud save is enabled.
    /// Safe to call on any thread; uses FileManager which is thread-safe for this operation.
    static func copyToICloudIfNeeded(localURL: URL) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "saveLocation") == SaveLocation.iCloud.rawValue else { return }
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents") else { return }

        let destURL = containerURL.appendingPathComponent(localURL.lastPathComponent)
        try? FileManager.default.setUbiquitous(true, itemAt: localURL, destinationURL: destURL)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
