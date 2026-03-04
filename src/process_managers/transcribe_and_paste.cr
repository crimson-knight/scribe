module Scribe::ProcessManagers
  # Process Manager: TranscribeAndPaste
  #
  # After recording stops:
  # 1. Transcribe WAV file via whisper-cli (local, no API)
  # 2. Save transcript as .md file alongside the audio
  # 3. Clipboard cycle: save current → write transcript → paste → restore
  #
  # FSDD Pattern: PERFORM process manager (non-RESTful, system-initiated after recording)
  class TranscribeAndPaste
    WHISPER_CLI = "whisper-cli"
    MODEL_PATH  = File.join(
      ENV["HOME"]? || "/tmp",
      "Library/Application Support/Scribe/models/ggml-base.en.bin"
    )

    getter transcript : String?
    getter transcript_path : String?
    getter? success : Bool = false
    getter error_message : String?

    def initialize(@audio_path : String, @output_directory : String)
      @success = false
    end

    def perform
      # Step 1: Transcribe
      @transcript = transcribe_audio
      unless @transcript
        @error_message ||= "Transcription failed"
        return
      end

      transcript_text = @transcript.not_nil!
      if transcript_text.blank?
        @error_message = "Transcription was empty"
        return
      end

      puts "[TranscribeAndPaste] Transcript: #{transcript_text.size} chars"

      # Step 2: Save transcript file
      save_transcript(transcript_text)

      # Step 3: Clipboard cycle (save → write → paste → restore)
      clipboard_paste(transcript_text)

      @success = true
    end

    private def transcribe_audio : String?
      unless File.exists?(@audio_path)
        @error_message = "Audio file not found: #{@audio_path}"
        return nil
      end

      unless File.exists?(MODEL_PATH)
        @error_message = "Whisper model not found: #{MODEL_PATH}"
        return nil
      end

      puts "[TranscribeAndPaste] Transcribing #{@audio_path}..."

      # Run whisper-cli: outputs plain text to stdout with --no-prints
      args = [
        "--model", MODEL_PATH,
        "--file", @audio_path,
        "--no-prints",
        "--no-timestamps",
        "--language", "en",
        "--threads", "4",
      ]

      begin
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run(WHISPER_CLI, args, output: output, error: error)

        if status.success?
          text = output.to_s.strip
          puts "[TranscribeAndPaste] Whisper completed successfully"
          text
        else
          @error_message = "Whisper exited with #{status.exit_code}: #{error.to_s.strip}"
          STDERR.puts "[TranscribeAndPaste] #{@error_message}"
          nil
        end
      rescue ex
        @error_message = "Failed to run whisper-cli: #{ex.message}"
        STDERR.puts "[TranscribeAndPaste] #{@error_message}"
        nil
      end
    end

    private def save_transcript(text : String)
      timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
      filename = "scribe_#{timestamp}.md"
      @transcript_path = File.join(@output_directory, filename)

      content = String.build do |io|
        io << "---\n"
        io << "date: #{Time.local.to_s("%Y-%m-%d %H:%M:%S")}\n"
        io << "audio: #{File.basename(@audio_path)}\n"
        io << "---\n\n"
        io << text
        io << "\n"
      end

      File.write(@transcript_path.not_nil!, content)
      puts "[TranscribeAndPaste] Saved transcript: #{@transcript_path}"
    rescue ex
      STDERR.puts "[TranscribeAndPaste] Failed to save transcript: #{ex.message}"
    end

    private def clipboard_paste(text : String)
      {% if flag?(:macos) %}
        # Save current clipboard
        saved = Scribe::Platform::MacOS::Clipboard.read || ""

        # Write transcript to clipboard
        unless Scribe::Platform::MacOS::Clipboard.write(text)
          STDERR.puts "[TranscribeAndPaste] Failed to write to clipboard"
          return
        end

        # Small delay to let clipboard settle
        sleep 50.milliseconds

        # Simulate Cmd+V paste
        if Scribe::Platform::MacOS::Clipboard.simulate_paste
          puts "[TranscribeAndPaste] Pasted transcript via Cmd+V"
        else
          puts "[TranscribeAndPaste] Paste simulation failed (need Accessibility permission?)"
          puts "[TranscribeAndPaste] Transcript is on your clipboard — Cmd+V manually"
          return # Don't restore clipboard if paste failed — user still has transcript
        end

        # Wait for paste to be consumed, then restore original clipboard
        sleep 300.milliseconds
        Scribe::Platform::MacOS::Clipboard.write(saved)
        puts "[TranscribeAndPaste] Clipboard restored"
      {% end %}
    end
  end
end
