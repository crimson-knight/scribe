import Foundation
import Speech
import AVFoundation

// MARK: - Speech transcription service

/// Wraps Apple's Speech framework (SFSpeechRecognizer) for on-device transcription.
/// Provides live partial results during dictation and silence detection for auto-stop.
@MainActor
final class SpeechTranscriptionService: ObservableObject {

    @Published var transcribedText = ""
    @Published var isTranscribing = false
    @Published var errorMessage: String? = nil
    @Published var didAutoStop = false
    @Published var isAuthorized = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private var maxDurationTimer: Timer?
    private var silenceTimeout: TimeInterval = 3.0

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                let authorized = status == .authorized
                self?.isAuthorized = authorized
                if !authorized {
                    self?.errorMessage = "Speech recognition permission is required."
                }
                completion(authorized)
            }
        }
    }

    // MARK: - Transcription control

    /// Start live transcription with optional silence and max duration timeouts.
    func startTranscription(silenceTimeout: TimeInterval = 3.0, maxDuration: TimeInterval = 60.0) {
        self.silenceTimeout = silenceTimeout
        didAutoStop = false
        errorMessage = nil
        transcribedText = ""

        // Check authorization first
        requestAuthorization { [weak self] authorized in
            guard authorized else { return }
            self?.beginRecognition(maxDuration: maxDuration)
        }
    }

    /// Stop transcription and finalize.
    func stopTranscription() {
        stopEngine()
    }

    // MARK: - Private - Recognition

    private func beginRecognition(maxDuration: TimeInterval) {
        // Clean up any previous session
        stopEngine()

        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        // Prefer on-device recognition when available
        let request = SFSpeechAudioBufferRecognitionRequest()
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        // Set up audio engine input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.stopEngine()
                    }
                }

                if let error {
                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // User cancelled - not an error
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    self.stopEngine()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isTranscribing = true
            startSilenceTimer()
            startMaxDurationTimer(maxDuration: maxDuration)
        } catch {
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            stopEngine()
        }
    }

    // MARK: - Private - Timers

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.isTranscribing {
                    self.didAutoStop = true
                    self.stopEngine()
                }
            }
        }
    }

    private func resetSilenceTimer() {
        startSilenceTimer()
    }

    private func startMaxDurationTimer(maxDuration: TimeInterval) {
        maxDurationTimer?.invalidate()
        maxDurationTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.isTranscribing {
                    self.didAutoStop = true
                    self.stopEngine()
                }
            }
        }
    }

    // MARK: - Private - Cleanup

    private func stopEngine() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isTranscribing = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
