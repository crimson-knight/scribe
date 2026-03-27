{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Manages whisper model loading, transcription, and model path search.
  # Extracted from app.cr (Story 8.4).
  module WhisperBridge
    # Load the whisper model. Returns a context pointer (or null on failure).
    # Uses DiscoverWhisperModel PM for path resolution (Story 9.1).
    def self.load_model : Void*
      model_name = Scribe::Settings::Manager.get("whisper_model_name")
      model_name = "ggml-base.en.bin" if model_name.empty?

      discovery = Scribe::ProcessManagers::DiscoverWhisperModel.new(model_name: model_name)
      discovery.perform

      if discovery.model_found? && (model_path = discovery.model_path)
        puts "[Scribe] Loading whisper model: #{model_path}"
        ctx = LibScribePlatform.scribe_whisper_init(model_path.to_unsafe)
        if ctx.null?
          STDERR.puts "[Scribe] Failed to load whisper model"
          return Pointer(Void).null
        else
          puts "[Scribe] Whisper model loaded successfully"
          return ctx
        end
      else
        STDERR.puts "[Scribe] Warning: No whisper model found -- transcription disabled"
        STDERR.puts "[Scribe] Place ggml-base.en.bin in ~/Library/Application Support/Scribe/models/"
        return Pointer(Void).null
      end
    end

    # Run whisper transcription on the given audio file.
    # This method runs on a GCD background thread -- do not touch UI.
    # Returns the transcript text, or nil on failure.
    def self.transcribe(whisper_ctx : Void*, audio_path : String) : String?
      return nil if whisper_ctx.null?

      begin
        # Read WAV file and convert to float32 PCM at 16kHz mono
        samples = AudioProcessor.read_wav_as_float32(audio_path)
        unless samples
          puts "[Scribe] Failed to read WAV file"
          return nil
        end

        puts "[Scribe] Transcribing #{samples.size} samples (#{samples.size / 16000.0}s)..."

        # Call C wrapper -- builds FullParams with correct struct layout (GAP-21)
        result_ptr = LibScribePlatform.scribe_whisper_transcribe(
          whisper_ctx,
          samples.to_unsafe,
          samples.size.to_i32,
          "en".to_unsafe,
          4 # n_threads
        )

        if result_ptr.null?
          puts "[Scribe] Transcription failed (whisper returned null)"
          return nil
        else
          text = String.new(result_ptr).strip
          LibScribePlatform.scribe_whisper_free_result(result_ptr)
          puts "[Scribe] Transcription complete: #{text.size} chars"
          return text
        end
      rescue ex
        puts "[Scribe] Transcription error: #{ex.message}"
        return nil
      end
    end

    # Find the whisper model file. Search order:
    # 1. Inside .app bundle: Contents/Resources/ggml-base.en.bin
    # 2. User App Support: ~/Library/Application Support/Scribe/models/ggml-base.en.bin
    def self.find_whisper_model : String?
      # Check bundle resources (for self-contained .app distribution)
      bundle_path = File.join(
        File.dirname(File.dirname(Process.executable_path || "")),
        "Resources", "ggml-base.en.bin"
      )
      return bundle_path if File.exists?(bundle_path)

      # Check user App Support directory
      app_support_path = File.join(
        ENV["HOME"]? || "/tmp",
        "Library/Application Support/Scribe/models/ggml-base.en.bin"
      )
      return app_support_path if File.exists?(app_support_path)

      nil
    end
  end
end

{% end %}
