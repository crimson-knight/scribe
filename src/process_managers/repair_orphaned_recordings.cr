require "json"

module Scribe::ProcessManagers
  # Process Manager: RepairOrphanedRecordings
  #
  # Detects whether the previous session crashed mid-recording by checking
  # for a lockfile left behind by StartAudioCapture. If found, repairs
  # the WAV header(s) so the audio can be transcribed.
  #
  # WAV files written by ExtAudioFile contain valid PCM data on disk even
  # after a crash — only the header's size fields may be wrong because
  # ExtAudioFileDispose() never ran. This PM fixes those fields.
  #
  # FSDD Pattern: PERFORM process manager (startup recovery)
  class RepairOrphanedRecordings
    getter repaired_files = [] of String
    getter? had_crash : Bool = false

    def perform
      lockfile = StartAudioCapture.lockfile_path
      return unless File.exists?(lockfile)

      begin
        data = JSON.parse(File.read(lockfile))
      rescue ex
        STDERR.puts "[RepairOrphanedRecordings] Invalid lockfile: #{ex.message}"
        File.delete(lockfile) rescue nil
        return
      end

      # Check if the PID in the lockfile is still running
      pid = data["pid"]?.try(&.as_s.to_i64) || 0_i64
      if pid > 0 && process_running?(pid)
        puts "[RepairOrphanedRecordings] PID #{pid} is still running — not a crash"
        return
      end

      # Crash detected
      @had_crash = true
      mode = data["mode"]?.try(&.as_s) || "dictation"
      output_path = data["output_path"]?.try(&.as_s) || ""
      mic_output_path = data["mic_output_path"]?.try(&.as_s) || ""

      puts "[RepairOrphanedRecordings] Crash detected (PID #{pid}, mode: #{mode})"

      # Repair WAV files
      [output_path, mic_output_path].each do |path|
        next if path.empty?
        next unless File.exists?(path)

        if repair_wav_header(path)
          @repaired_files << path
          puts "[RepairOrphanedRecordings] Repaired: #{path}"
        end
      end

      # Clean up lockfile
      File.delete(lockfile) rescue nil
    end

    # Repair a WAV file's header by setting the correct data and RIFF sizes.
    # Returns true if the file was repaired, false if skipped or invalid.
    def repair_wav_header(path : String) : Bool
      file_size = File.size(path)
      return false if file_size < 44 # Too small for a valid WAV

      File.open(path, "r+b") do |f|
        # Verify RIFF magic
        magic = Bytes.new(4)
        f.read(magic)
        return false unless String.new(magic) == "RIFF"

        # Read current RIFF size
        current_riff_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        expected_riff_size = (file_size - 8).to_u32

        # Skip to data chunk size at offset 40
        f.seek(40)
        current_data_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        expected_data_size = (file_size - 44).to_u32

        # Check if repair is needed
        if current_riff_size == expected_riff_size && current_data_size == expected_data_size
          puts "[RepairOrphanedRecordings] #{File.basename(path)} — header already correct"
          return false
        end

        # Repair: write correct sizes
        f.seek(4)
        f.write_bytes(expected_riff_size, IO::ByteFormat::LittleEndian)
        f.seek(40)
        f.write_bytes(expected_data_size, IO::ByteFormat::LittleEndian)

        puts "[RepairOrphanedRecordings] #{File.basename(path)} — repaired header (data: #{expected_data_size} bytes)"
      end

      true
    end

    private def process_running?(pid : Int64) : Bool
      # Send signal 0 to check if process exists
      LibC.kill(pid.to_i32, 0) == 0
    end
  end
end
