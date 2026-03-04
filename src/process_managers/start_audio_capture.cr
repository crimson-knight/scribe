require "crystal_audio"

module Scribe::ProcessManagers
  # Process Manager: StartAudioCapture
  #
  # Starts recording audio from the microphone and saves to a WAV file.
  # Uses crystal-audio's Recorder directly — no custom audio abstraction.
  #
  # FSDD Pattern: PERFORM process manager (non-RESTful, user-initiated action)
  class StartAudioCapture
    getter recorder : CrystalAudio::Recorder?
    getter? recording : Bool = false
    getter output_path : String?
    getter error_message : String?

    def initialize(@output_directory : String = "/tmp")
      @recording = false
    end

    def perform
      timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
      @output_path = File.join(@output_directory, "scribe_#{timestamp}.wav")

      begin
        @recorder = CrystalAudio::Recorder.new(
          source: CrystalAudio::RecordingSource::Microphone,
          output_path: @output_path.not_nil!
        )
        @recorder.not_nil!.start
        @recording = true
        puts "[StartAudioCapture] Recording to #{@output_path}"
      rescue ex
        @error_message = ex.message
        @recording = false
        STDERR.puts "[StartAudioCapture] Failed: #{ex.message}"
      end
    end

    def stop
      if @recording && @recorder
        @recorder.not_nil!.stop
        @recording = false
        puts "[StartAudioCapture] Stopped. Saved to #{@output_path}"
      end
    end
  end
end
