import SwiftUI
import AVFoundation

// MARK: - Root view

struct ContentView: View {
    @StateObject private var model = AudioRecorderModel()

    var body: some View {
        TabView {
            RecordTab(model: model)
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .accessibilityIdentifier("nav-tab-record")

            RecordingsListView(model: model)
                .tabItem {
                    Label("Recordings", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("nav-tab-recordings")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .accessibilityIdentifier("nav-tab-settings")
        }
        .onAppear {
            model.initCrystalRuntime()
            model.requestPermission()
        }
    }
}

// MARK: - Record tab

private struct RecordTab: View {
    @ObservedObject var model: AudioRecorderModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 36) {
                timerSection
                waveformPlaceholder
                recordButton
                statusSection
                Spacer()
            }
            .padding()
            .navigationTitle("Scribe")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MM:SS elapsed timer
    private var timerSection: some View {
        Text(model.elapsedTimeString)
            .font(.system(size: 64, design: .monospaced))
            .foregroundStyle(model.isRecording ? .red : .secondary)
            .animation(.easeInOut(duration: 0.2), value: model.isRecording)
            .padding(.top, 24)
            .accessibilityIdentifier("7.1-timer-display")
    }

    // Waveform placeholder shown during recording
    private var waveformPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 80)

            if model.isRecording {
                HStack(spacing: 3) {
                    ForEach(0..<30, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 3, height: CGFloat.random(in: 8...60))
                    }
                }
                .animation(.easeInOut(duration: 0.4).repeatForever(), value: model.isRecording)
            } else {
                Text("Waveform")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }

    // Large record / stop button
    private var recordButton: some View {
        Button(action: model.toggleRecording) {
            ZStack {
                Circle()
                    .fill(model.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 112, height: 112)

                Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(model.isRecording ? .red : .blue)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(model.isRecording ? 1.08 : 1.0)
        .animation(.spring(duration: 0.25), value: model.isRecording)
        .disabled(!model.permissionGranted)
        .accessibilityLabel(model.isRecording ? "Stop recording" : "Start recording")
        .accessibilityIdentifier("7.1-record-button")
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(model.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("7.1-status-text")

            if !model.permissionGranted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - View model

@MainActor
final class AudioRecorderModel: ObservableObject {
    @Published var isRecording = false
    @Published var statusText = "Ready to record"
    @Published var elapsedTimeString = "0:00"
    @Published var permissionGranted = false
    @Published var savedRecordings: [String] = []

    private var elapsedSeconds = 0
    private var timer: Timer?
    private var currentOutputPath = ""

    // MARK: - Lifecycle

    func initCrystalRuntime() {
        let result = scribe_init()
        if result != 0 {
            statusText = "Crystal runtime init failed (\(result))"
        }
    }

    func requestPermission(completion: (() -> Void)? = nil) {
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .granted {
            self.permissionGranted = true
            self.statusText = "Ready to record"
            completion?()
            return
        }

        session.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.permissionGranted = granted
                self.statusText = granted
                    ? "Ready to record"
                    : "Microphone access required — tap 'Open Settings'"
                completion?()
            }
        }
    }

    // MARK: - Recording control

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard permissionGranted else {
            statusText = "Microphone permission not granted"
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("recording_\(timestamp).wav")
        currentOutputPath = url.path

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            statusText = "Audio session error: \(error.localizedDescription)"
            return
        }

        let result = scribe_start_recording(currentOutputPath)
        guard result == 0 else {
            statusText = "Failed to start recording (error \(result))"
            return
        }

        isRecording = true
        elapsedSeconds = 0
        elapsedTimeString = "0:00"
        statusText = "Recording…"

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                let m = self.elapsedSeconds / 60
                let s = self.elapsedSeconds % 60
                self.elapsedTimeString = String(format: "%d:%02d", m, s)
            }
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil

        let result = scribe_stop_recording()
        isRecording = false
        elapsedTimeString = "0:00"

        if result == 0 {
            statusText = "Saved: \(URL(fileURLWithPath: currentOutputPath).lastPathComponent)"
            savedRecordings.insert(currentOutputPath, at: 0)
        } else {
            statusText = "Stop failed (error \(result))"
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
