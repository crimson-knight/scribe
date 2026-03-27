require "crystal_audio"
require "json"

module Scribe::ProcessManagers
  # Process Manager: StartAudioCapture
  #
  # Starts recording audio. In dictation mode, records microphone only.
  # In meeting mode, records both microphone and system audio simultaneously.
  # Uses crystal-audio's Recorder directly — no custom audio abstraction.
  #
  # Writes a lockfile on start, deletes on stop. If the app crashes mid-recording,
  # the lockfile survives and RepairOrphanedRecordings can recover the WAV file.
  #
  # FSDD Pattern: PERFORM process manager (non-RESTful, user-initiated action)
  class StartAudioCapture
    LOCKFILE_NAME = ".recording_lock"

    getter recorder : CrystalAudio::Recorder?
    getter? recording : Bool = false
    getter output_path : String?
    getter mic_output_path : String?
    getter error_message : String?

    def initialize(@output_directory : String = "/tmp", @system_audio : Bool = false)
      @recording = false
    end

    def perform
      timestamp = Time.local.to_s("%Y%m%d_%H%M%S")

      if @system_audio
        @output_path = File.join(@output_directory, "scribe_meeting_#{timestamp}_system.wav")
        @mic_output_path = File.join(@output_directory, "scribe_meeting_#{timestamp}_mic.wav")

        begin
          @recorder = CrystalAudio::Recorder.new(
            source: CrystalAudio::RecordingSource::Both,
            output_path: @output_path.not_nil!,
            mic_output_path: @mic_output_path.not_nil!
          )
          @recorder.not_nil!.start
          @recording = true
          write_lockfile
          puts "[StartAudioCapture] Meeting mode — recording to #{@output_path} + #{@mic_output_path}"
        rescue ex
          @error_message = ex.message
          @recording = false
          STDERR.puts "[StartAudioCapture] Failed: #{ex.message}"
        end
      else
        @output_path = File.join(@output_directory, "scribe_#{timestamp}.wav")

        begin
          @recorder = CrystalAudio::Recorder.new(
            source: CrystalAudio::RecordingSource::Microphone,
            output_path: @output_path.not_nil!
          )
          @recorder.not_nil!.start
          @recording = true
          write_lockfile
          puts "[StartAudioCapture] Dictation mode — recording to #{@output_path}"
        rescue ex
          @error_message = ex.message
          @recording = false
          STDERR.puts "[StartAudioCapture] Failed: #{ex.message}"
        end
      end
    end

    def stop
      if @recording && @recorder
        @recorder.not_nil!.stop
        @recording = false
        delete_lockfile
        puts "[StartAudioCapture] Stopped. Saved to #{@output_path}"
      end
    end

    def self.lockfile_path : String
      File.join(Scribe::Settings::Manager.app_support_dir, LOCKFILE_NAME)
    end

    private def write_lockfile
      data = {
        "pid"             => Process.pid.to_s,
        "started_at"      => Time.utc.to_rfc3339,
        "output_path"     => @output_path || "",
        "mic_output_path" => @mic_output_path || "",
        "mode"            => Scribe::Settings::Manager.recording_mode,
      }
      File.write(self.class.lockfile_path, data.to_json)
    rescue ex
      STDERR.puts "[StartAudioCapture] Warning: failed to write lockfile: #{ex.message}"
    end

    private def delete_lockfile
      path = self.class.lockfile_path
      File.delete(path) if File.exists?(path)
    rescue ex
      STDERR.puts "[StartAudioCapture] Warning: failed to delete lockfile: #{ex.message}"
    end
  end
end
