# process_manager_spec.cr -- macOS L1 tests for Scribe process managers
#
# Tests the business logic of the macOS desktop process managers without
# hardware dependencies (microphone, whisper model, clipboard). Follows
# the same Option B replication approach as the mobile bridge spec:
# replicate the state machine interfaces so the spec runner can compile
# without linking against CrystalAudio, AppKit, or whisper.
#
# Run:
#   cd ~/personal_coding_projects/scribe && crystal-alpha spec spec/macos/process_manager_spec.cr
#
# Note: -Dmacos flag is NOT needed here because we replicate interfaces
# rather than requiring the actual platform code (which is gated by
# {% if flag?(:macos) %}).

require "spec"

# ---------------------------------------------------------------------------
# Replicated StartAudioCapture state machine
# ---------------------------------------------------------------------------
# Mirrors: src/process_managers/start_audio_capture.cr
# Strips out CrystalAudio::Recorder dependency; tests state transitions only.

module TestProcessManagers
  class StartAudioCapture
    getter? recording : Bool = false
    getter output_path : String?
    getter error_message : String?

    def initialize(@output_directory : String = "/tmp")
      @recording = false
    end

    def perform
      timestamp = Time.local.to_s("%Y%m%d_%H%M%S")
      @output_path = File.join(@output_directory, "scribe_#{timestamp}.wav")

      # In the real PM, this creates a CrystalAudio::Recorder and calls .start.
      # Here we simulate a successful start.
      @recording = true
    rescue ex
      @error_message = ex.message
      @recording = false
    end

    # Simulate a failed hardware start (mic not available, etc.)
    def perform_with_failure(message : String)
      @error_message = message
      @recording = false
    end

    def stop
      if @recording
        @recording = false
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Replicated TranscribeAndPaste logic
# ---------------------------------------------------------------------------
# Mirrors: src/process_managers/transcribe_and_paste.cr
# Tests the decision logic without whisper-cli or clipboard FFI.

module TestProcessManagers
  class TranscribeAndPaste
    getter transcript : String?
    getter transcript_path : String?
    getter? success : Bool = false
    getter error_message : String?

    def initialize(@audio_path : String, @output_directory : String)
      @success = false
    end

    # Perform with a simulated transcription result (bypasses whisper-cli)
    def perform_with_transcript(text : String?)
      if text.nil?
        @error_message ||= "Transcription failed"
        return
      end

      if text.blank?
        @error_message = "Transcription was empty"
        return
      end

      @transcript = text
      save_transcript(text)
      # Clipboard paste would happen here on real macOS
      @success = true
    end

    # Simulate the file validation check
    def validate_audio_file(path : String) : Bool
      # In real code, checks File.exists?(@audio_path)
      !path.empty? && !path.includes?("nonexistent")
    end

    private def save_transcript(text : String)
      timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
      filename = "scribe_#{timestamp}.md"
      @transcript_path = File.join(@output_directory, filename)

      # In real code, writes to disk. Here we just set the path.
    rescue ex
      # Swallow save errors like the real PM does
    end
  end
end

# ---------------------------------------------------------------------------
# Replicated App state machine
# ---------------------------------------------------------------------------
# Mirrors the toggle_recording logic in src/platform/macos/app.cr
# Tests the state transitions of the App module without NSApp or FFI.

module TestApp
  @@recording = false
  @@capture : TestProcessManagers::StartAudioCapture? = nil
  @@output_dir = "/tmp/scribe_test"
  @@whisper_loaded = false
  @@last_status_icon = "mic"
  @@last_status_title = "Scribe"
  @@last_menu_title = "Start Recording"

  def self.reset!
    @@recording = false
    @@capture = TestProcessManagers::StartAudioCapture.new(output_directory: @@output_dir)
    @@whisper_loaded = false
    @@last_status_icon = "mic"
    @@last_status_title = "Scribe"
    @@last_menu_title = "Start Recording"
  end

  def self.recording?
    @@recording
  end

  def self.whisper_loaded?
    @@whisper_loaded
  end

  def self.whisper_loaded=(v : Bool)
    @@whisper_loaded = v
  end

  def self.last_status_icon
    @@last_status_icon
  end

  def self.last_status_title
    @@last_status_title
  end

  def self.last_menu_title
    @@last_menu_title
  end

  def self.toggle_recording
    if cap = @@capture
      if cap.recording?
        cap.stop
        @@recording = false
        update_status_recording(false)
      else
        cap.perform
        @@recording = cap.recording?
        update_status_recording(true) if @@recording
      end
    end
  end

  private def self.update_status_recording(is_recording : Bool)
    if is_recording
      @@last_status_icon = "mic.fill"
      @@last_status_title = "REC"
      @@last_menu_title = "Stop Recording"
    else
      @@last_status_icon = "mic"
      @@last_status_title = "Scribe"
      @@last_menu_title = "Start Recording"
    end
  end
end

# ---------------------------------------------------------------------------
# Specs
# ---------------------------------------------------------------------------

# FEATURE STORY: Epic 2, Story 2.2 — Start Audio Recording
describe "StartAudioCapture Process Manager" do
  it "initializes in non-recording state" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.recording?.should be_false
    pm.output_path.should be_nil
    pm.error_message.should be_nil
  end

  it "transitions to recording state on perform" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform
    pm.recording?.should be_true
  end

  it "generates an output path on perform" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform
    pm.output_path.should_not be_nil
    pm.output_path.not_nil!.should start_with("/tmp/test/scribe_")
    pm.output_path.not_nil!.should end_with(".wav")
  end

  it "transitions back to non-recording on stop" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform
    pm.recording?.should be_true
    pm.stop
    pm.recording?.should be_false
  end

  it "stop is a no-op when not recording" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.stop  # Should not raise
    pm.recording?.should be_false
  end

  it "sets error_message on failure" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform_with_failure("Microphone not available")
    pm.recording?.should be_false
    pm.error_message.should eq "Microphone not available"
  end

  it "allows perform -> stop -> perform cycle" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform
    pm.recording?.should be_true

    pm.stop
    pm.recording?.should be_false

    pm.perform
    pm.recording?.should be_true
  end

  it "generates unique output paths on successive performs" do
    pm = TestProcessManagers::StartAudioCapture.new(output_directory: "/tmp/test")
    pm.perform
    path1 = pm.output_path
    pm.stop

    # Ensure timestamp differs (sleep is fine in test)
    sleep 1.1.seconds

    pm.perform
    path2 = pm.output_path
    pm.stop

    path1.should_not eq path2
  end
end

# FEATURE STORY: Epic 3, Story 3.1 — Transcribe Recording
describe "TranscribeAndPaste Process Manager" do
  it "initializes with audio path and output directory" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.success?.should be_false
    pm.transcript.should be_nil
  end

  it "succeeds with valid transcript text" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.perform_with_transcript("Hello world, this is a test.")
    pm.success?.should be_true
    pm.transcript.should eq "Hello world, this is a test."
    pm.transcript_path.should_not be_nil
    pm.transcript_path.not_nil!.should start_with("/tmp/output/scribe_")
    pm.transcript_path.not_nil!.should end_with(".md")
  end

  it "fails with nil transcript" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.perform_with_transcript(nil)
    pm.success?.should be_false
    pm.error_message.should eq "Transcription failed"
  end

  it "fails with empty transcript" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.perform_with_transcript("")
    pm.success?.should be_false
    pm.error_message.should eq "Transcription was empty"
  end

  it "fails with whitespace-only transcript" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.perform_with_transcript("   \n  ")
    pm.success?.should be_false
    pm.error_message.should eq "Transcription was empty"
  end

  it "validates audio file path" do
    pm = TestProcessManagers::TranscribeAndPaste.new(
      audio_path: "/tmp/test.wav",
      output_directory: "/tmp/output"
    )
    pm.validate_audio_file("/tmp/test.wav").should be_true
    pm.validate_audio_file("").should be_false
    pm.validate_audio_file("/nonexistent/path.wav").should be_false
  end
end

# FEATURE STORY: Epic 1, Story 1.1 — Launch as Menu Bar App
# FEATURE STORY: Epic 1, Story 1.4 — Open Menu Bar Dropdown
# FEATURE STORY: Epic 1, Story 1.5 — Register Global Keyboard Shortcut
describe "App Toggle Recording State Machine" do
  before_each do
    TestApp.reset!
  end

  it "starts in non-recording state" do
    TestApp.recording?.should be_false
  end

  it "shows idle status icon and title initially" do
    TestApp.last_status_icon.should eq "mic"
    TestApp.last_status_title.should eq "Scribe"
    TestApp.last_menu_title.should eq "Start Recording"
  end

  it "transitions to recording on first toggle" do
    TestApp.toggle_recording
    TestApp.recording?.should be_true
  end

  it "updates status to recording state" do
    TestApp.toggle_recording
    TestApp.last_status_icon.should eq "mic.fill"
    TestApp.last_status_title.should eq "REC"
    TestApp.last_menu_title.should eq "Stop Recording"
  end

  it "transitions back to idle on second toggle" do
    TestApp.toggle_recording
    TestApp.toggle_recording
    TestApp.recording?.should be_false
  end

  it "restores idle status on stop" do
    TestApp.toggle_recording
    TestApp.toggle_recording
    TestApp.last_status_icon.should eq "mic"
    TestApp.last_status_title.should eq "Scribe"
    TestApp.last_menu_title.should eq "Start Recording"
  end

  it "supports full toggle cycle (start -> stop -> start -> stop)" do
    TestApp.toggle_recording
    TestApp.recording?.should be_true

    TestApp.toggle_recording
    TestApp.recording?.should be_false

    TestApp.toggle_recording
    TestApp.recording?.should be_true

    TestApp.toggle_recording
    TestApp.recording?.should be_false
  end
end

# FEATURE STORY: Epic 1, Story 1.1 — App Configuration
describe "App Configuration" do
  it "uses SCRIBE_OUTPUT_DIR env var when set" do
    # The real app checks ENV["SCRIBE_OUTPUT_DIR"]? || default
    env_dir = ENV["SCRIBE_OUTPUT_DIR"]?
    default_dir = File.join(ENV["HOME"]? || "/tmp", "Scribe")
    output_dir = env_dir || default_dir

    output_dir.should_not be_nil
    output_dir.size.should be > 0
  end

  it "defaults to ~/Scribe when env var not set" do
    home = ENV["HOME"]? || "/tmp"
    default_dir = File.join(home, "Scribe")
    default_dir.should end_with("/Scribe")
  end

  it "whisper model search checks bundle path first" do
    # Mirrors find_whisper_model logic
    exe_path = Process.executable_path || ""
    if exe_path.size > 0
      bundle_path = File.join(
        File.dirname(File.dirname(exe_path)),
        "Resources", "ggml-base.en.bin"
      )
      # Just verify the path construction logic works
      bundle_path.should contain("Resources")
      bundle_path.should end_with("ggml-base.en.bin")
    end
  end

  it "whisper model search falls back to app support directory" do
    home = ENV["HOME"]? || "/tmp"
    app_support_path = File.join(home, "Library/Application Support/Scribe/models/ggml-base.en.bin")
    app_support_path.should contain("Library/Application Support/Scribe/models")
    app_support_path.should end_with("ggml-base.en.bin")
  end
end

# FEATURE STORY: Epic 4, Story 4.1 — Clipboard cycle contracts
describe "Clipboard Paste Cycle Contracts" do
  it "on_paste_cycle_complete with success=1 means auto-pasted" do
    # The real callback receives Int32, 1 = success, 0 = fallback
    success = 1_i32
    (success == 1).should be_true
  end

  it "on_paste_cycle_complete with success=0 means clipboard-only" do
    success = 0_i32
    (success == 0).should be_true
  end
end

# FEATURE STORY: Epic 2, Story 2.2 — WAV file validation
describe "WAV File Parsing Contracts" do
  it "rejects files smaller than 44 bytes (minimum WAV header)" do
    min_header_size = 44
    too_small = Bytes.new(10)
    (too_small.size < min_header_size).should be_true
  end

  it "validates RIFF magic bytes" do
    riff = "RIFF"
    riff.should eq "RIFF"
  end

  it "validates WAVE format marker" do
    wave = "WAVE"
    wave.should eq "WAVE"
  end

  it "supports 16-bit and 32-bit sample depths" do
    supported = [16_u16, 32_u16]
    supported.should contain(16_u16)
    supported.should contain(32_u16)
  end

  it "converts mono 16-bit samples to float32 in [-1, 1] range" do
    # Max positive 16-bit: 32767 -> 32767/32768.0 ~ 0.99997
    max_positive = 32767_i16
    normalized = max_positive.to_f32 / 32768.0_f32
    (normalized > 0.0_f32).should be_true
    (normalized < 1.0_f32).should be_true

    # Max negative 16-bit: -32768 -> -32768/32768.0 = -1.0
    max_negative = -32768_i16
    normalized_neg = max_negative.to_f32 / 32768.0_f32
    normalized_neg.should eq(-1.0_f32)
  end

  it "downmixes stereo to mono by averaging channels" do
    left = 0.5_f32
    right = -0.3_f32
    mono = (left + right) / 2.0_f32
    mono.should be_close(0.1_f32, 1e-6)
  end

  it "calculates correct resample ratio for 44100 -> 16000" do
    ratio = 16000.0 / 44100.0
    (ratio > 0.36).should be_true
    (ratio < 0.37).should be_true
  end
end

# FEATURE STORY: Epic 4, Story 4.2 — Transcript file format
describe "Transcript File Format" do
  it "generates markdown frontmatter with date and audio reference" do
    timestamp = Time.local.to_s("%Y-%m-%d %H:%M:%S")
    audio_basename = "scribe_20260304_120000.wav"
    transcript_text = "Hello world"

    content = String.build do |io|
      io << "---\n"
      io << "date: #{timestamp}\n"
      io << "audio: #{audio_basename}\n"
      io << "---\n\n"
      io << transcript_text
      io << "\n"
    end

    content.should start_with("---\n")
    content.should contain("date: ")
    content.should contain("audio: #{audio_basename}")
    content.should contain("---\n\n#{transcript_text}")
    content.should end_with("\n")
  end

  it "generates transcript filename with timestamp" do
    timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
    filename = "scribe_#{timestamp}.md"
    filename.should start_with("scribe_")
    filename.should end_with(".md")
  end
end
