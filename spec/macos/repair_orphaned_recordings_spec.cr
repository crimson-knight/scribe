# repair_orphaned_recordings_spec.cr -- Tests for WAV header repair and crash detection
#
# Tests the crash recovery logic without hardware dependencies.
# Creates real WAV files on disk with intentionally corrupted headers,
# then verifies the repair PM fixes them correctly.
#
# Run:
#   cd ~/personal_coding_projects/scribe && crystal-alpha spec spec/macos/repair_orphaned_recordings_spec.cr

require "spec"
require "json"
require "file_utils"

# Minimal WAV header builder for testing
module TestWavHelper
  SAMPLE_RATE = 44100_u32
  CHANNELS    =     1_u16
  BITS        =    16_u16

  # Build a valid PCM WAV file header + silent PCM data.
  def self.build_wav(duration_seconds : Float64, corrupt_header : Bool = false) : Bytes
    byte_rate = SAMPLE_RATE * CHANNELS * (BITS // 8)
    data_size = (byte_rate * duration_seconds).to_u32
    file_size = data_size + 44

    io = IO::Memory.new
    # RIFF header
    io.write("RIFF".to_slice)
    io.write_bytes(corrupt_header ? 0_u32 : (file_size - 8).to_u32, IO::ByteFormat::LittleEndian)
    io.write("WAVE".to_slice)

    # fmt chunk
    io.write("fmt ".to_slice)
    io.write_bytes(16_u32, IO::ByteFormat::LittleEndian)      # chunk size
    io.write_bytes(1_u16, IO::ByteFormat::LittleEndian)       # PCM format
    io.write_bytes(CHANNELS, IO::ByteFormat::LittleEndian)
    io.write_bytes(SAMPLE_RATE, IO::ByteFormat::LittleEndian)
    io.write_bytes(byte_rate, IO::ByteFormat::LittleEndian)
    io.write_bytes((CHANNELS * BITS // 8).to_u16, IO::ByteFormat::LittleEndian) # block align
    io.write_bytes(BITS, IO::ByteFormat::LittleEndian)

    # data chunk
    io.write("data".to_slice)
    io.write_bytes(corrupt_header ? 0_u32 : data_size, IO::ByteFormat::LittleEndian)

    # PCM data (silence)
    io.write(Bytes.new(data_size, 0_u8))

    io.to_slice.dup
  end
end

# Replicated RepairOrphanedRecordings for spec (no platform dependencies)
class TestRepairOrphanedRecordings
  getter repaired_files = [] of String
  getter? had_crash : Bool = false

  def initialize(@lockfile_path : String, @check_pid : Bool = true)
  end

  def perform
    return unless File.exists?(@lockfile_path)

    begin
      data = JSON.parse(File.read(@lockfile_path))
    rescue
      File.delete(@lockfile_path) rescue nil
      return
    end

    pid = data["pid"]?.try(&.as_s.to_i64) || 0_i64
    if @check_pid && pid > 0 && process_running?(pid)
      return
    end

    @had_crash = true
    output_path = data["output_path"]?.try(&.as_s) || ""
    mic_output_path = data["mic_output_path"]?.try(&.as_s) || ""

    [output_path, mic_output_path].each do |path|
      next if path.empty?
      next unless File.exists?(path)
      if repair_wav_header(path)
        @repaired_files << path
      end
    end

    File.delete(@lockfile_path) rescue nil
  end

  def repair_wav_header(path : String) : Bool
    file_size = File.size(path)
    return false if file_size < 44

    File.open(path, "r+b") do |f|
      magic = Bytes.new(4)
      f.read(magic)
      return false unless String.new(magic) == "RIFF"

      current_riff_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
      expected_riff_size = (file_size - 8).to_u32

      f.seek(40)
      current_data_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
      expected_data_size = (file_size - 44).to_u32

      if current_riff_size == expected_riff_size && current_data_size == expected_data_size
        return false
      end

      f.seek(4)
      f.write_bytes(expected_riff_size, IO::ByteFormat::LittleEndian)
      f.seek(40)
      f.write_bytes(expected_data_size, IO::ByteFormat::LittleEndian)
    end
    true
  end

  private def process_running?(pid : Int64) : Bool
    LibC.kill(pid.to_i32, 0) == 0
  end
end

# ============================================================================
# Specs
# ============================================================================

describe "WAV Header Repair" do
  test_dir = File.join(Dir.tempdir, "scribe_repair_test_#{Process.pid}")

  before_each do
    Dir.mkdir_p(test_dir)
  end

  after_each do
    FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
  end

  describe "#repair_wav_header" do
    it "repairs a WAV file with zeroed size fields" do
      path = File.join(test_dir, "corrupt.wav")
      File.write(path, TestWavHelper.build_wav(1.0, corrupt_header: true))

      repairer = TestRepairOrphanedRecordings.new("", check_pid: false)
      result = repairer.repair_wav_header(path)
      result.should be_true

      # Verify header was fixed
      File.open(path, "rb") do |f|
        f.seek(4)
        riff_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        riff_size.should eq(File.size(path) - 8)

        f.seek(40)
        data_size = f.read_bytes(UInt32, IO::ByteFormat::LittleEndian)
        data_size.should eq(File.size(path) - 44)
      end
    end

    it "does not modify a valid WAV file" do
      path = File.join(test_dir, "valid.wav")
      original = TestWavHelper.build_wav(1.0, corrupt_header: false)
      File.write(path, original)

      repairer = TestRepairOrphanedRecordings.new("", check_pid: false)
      result = repairer.repair_wav_header(path)
      result.should be_false # No repair needed
    end

    it "skips files smaller than 44 bytes" do
      path = File.join(test_dir, "tiny.wav")
      File.write(path, "too small")

      repairer = TestRepairOrphanedRecordings.new("", check_pid: false)
      result = repairer.repair_wav_header(path)
      result.should be_false
    end

    it "skips non-RIFF files" do
      path = File.join(test_dir, "not_wav.wav")
      data = Bytes.new(100, 0_u8)
      data[0] = 'N'.ord.to_u8
      data[1] = 'O'.ord.to_u8
      data[2] = 'P'.ord.to_u8
      data[3] = 'E'.ord.to_u8
      File.write(path, data)

      repairer = TestRepairOrphanedRecordings.new("", check_pid: false)
      result = repairer.repair_wav_header(path)
      result.should be_false
    end
  end

  describe "#perform" do
    it "detects crash when lockfile exists with dead PID" do
      wav_path = File.join(test_dir, "crashed.wav")
      File.write(wav_path, TestWavHelper.build_wav(0.5, corrupt_header: true))

      lockfile = File.join(test_dir, ".recording_lock")
      lock_data = {
        "pid"             => "99999999", # Very unlikely to be running
        "started_at"      => Time.utc.to_rfc3339,
        "output_path"     => wav_path,
        "mic_output_path" => "",
        "mode"            => "dictation",
      }
      File.write(lockfile, lock_data.to_json)

      repairer = TestRepairOrphanedRecordings.new(lockfile)
      repairer.perform

      repairer.had_crash?.should be_true
      repairer.repaired_files.size.should eq(1)
      repairer.repaired_files.first.should eq(wav_path)

      # Lockfile should be cleaned up
      File.exists?(lockfile).should be_false
    end

    it "does not trigger when no lockfile exists" do
      lockfile = File.join(test_dir, ".recording_lock")
      repairer = TestRepairOrphanedRecordings.new(lockfile)
      repairer.perform

      repairer.had_crash?.should be_false
      repairer.repaired_files.should be_empty
    end

    it "does not trigger when lockfile PID is still running" do
      wav_path = File.join(test_dir, "current.wav")
      File.write(wav_path, TestWavHelper.build_wav(0.5, corrupt_header: true))

      lockfile = File.join(test_dir, ".recording_lock")
      lock_data = {
        "pid"             => Process.pid.to_s, # Current process — still running!
        "started_at"      => Time.utc.to_rfc3339,
        "output_path"     => wav_path,
        "mic_output_path" => "",
        "mode"            => "dictation",
      }
      File.write(lockfile, lock_data.to_json)

      repairer = TestRepairOrphanedRecordings.new(lockfile)
      repairer.perform

      repairer.had_crash?.should be_false
    end

    it "repairs both files in meeting mode crash" do
      system_path = File.join(test_dir, "system.wav")
      mic_path = File.join(test_dir, "mic.wav")
      File.write(system_path, TestWavHelper.build_wav(1.0, corrupt_header: true))
      File.write(mic_path, TestWavHelper.build_wav(1.0, corrupt_header: true))

      lockfile = File.join(test_dir, ".recording_lock")
      lock_data = {
        "pid"             => "99999999",
        "started_at"      => Time.utc.to_rfc3339,
        "output_path"     => system_path,
        "mic_output_path" => mic_path,
        "mode"            => "meeting",
      }
      File.write(lockfile, lock_data.to_json)

      repairer = TestRepairOrphanedRecordings.new(lockfile)
      repairer.perform

      repairer.had_crash?.should be_true
      repairer.repaired_files.size.should eq(2)
    end

    it "cleans up lockfile after repair" do
      wav_path = File.join(test_dir, "orphan.wav")
      File.write(wav_path, TestWavHelper.build_wav(0.5, corrupt_header: true))

      lockfile = File.join(test_dir, ".recording_lock")
      File.write(lockfile, {"pid" => "99999999", "output_path" => wav_path, "mic_output_path" => "", "mode" => "dictation"}.to_json)

      repairer = TestRepairOrphanedRecordings.new(lockfile)
      repairer.perform

      File.exists?(lockfile).should be_false
    end
  end
end
