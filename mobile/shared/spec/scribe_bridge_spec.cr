# scribe_bridge_spec.cr — State machine tests for the Scribe mobile bridge
#
# The actual bridge (scribe_bridge.cr) cannot be required directly in specs because:
#   1. It defines `fun main` which conflicts with the spec runner's main
#   2. It requires crystal_audio which needs hardware (mic, audio frameworks)
#   3. It uses LibTrace.crystal_trace which needs the trace_helper.o C extension
#
# Instead, we replicate the Bridge module's state machine and test the same
# logic that the C API functions use. This validates the state transitions,
# guard clauses, and return code contracts without hardware dependencies.
#
# Run: cd ~/personal_coding_projects/scribe/mobile/shared && crystal-alpha spec spec/scribe_bridge_spec.cr -Dmacos
#
# If the bridge is refactored to extract the state machine into a separate file
# (e.g., bridge_state.cr), these specs can require that directly instead.

require "spec"

# ---------------------------------------------------------------------------
# Replicated Bridge state machine (mirrors private module Bridge in scribe_bridge.cr)
# ---------------------------------------------------------------------------
# This is a faithful copy of the state management from scribe_bridge.cr.
# Any changes to the bridge's state logic MUST be reflected here.

private module BridgeState
  @@initialized : Bool = false
  @@recording : Bool = false
  @@has_recorder : Bool = false
  @@has_player : Bool = false

  def self.initialized? : Bool
    @@initialized
  end

  def self.initialized=(v : Bool)
    @@initialized = v
  end

  def self.recording? : Bool
    @@recording
  end

  def self.recording=(v : Bool)
    @@recording = v
  end

  def self.has_recorder? : Bool
    @@has_recorder
  end

  def self.has_recorder=(v : Bool)
    @@has_recorder = v
  end

  def self.has_player? : Bool
    @@has_player
  end

  def self.has_player=(v : Bool)
    @@has_player = v
  end

  def self.reset!
    @@initialized = false
    @@recording = false
    @@has_recorder = false
    @@has_player = false
  end
end

# ---------------------------------------------------------------------------
# Replicated C API logic (mirrors the fun declarations in scribe_bridge.cr)
# ---------------------------------------------------------------------------
# These methods replicate the return-code logic of the bridge's C functions.
# Hardware-dependent operations (Recorder.new, Player.new, etc.) are replaced
# with state flag mutations.

module BridgeAPI
  # Mirrors: fun scribe_init : LibC::Int
  def self.init : Int32
    BridgeState.initialized = true
    0_i32
  rescue
    -1_i32
  end

  # Mirrors: fun scribe_is_recording : LibC::Int
  def self.is_recording : Int32
    BridgeState.recording? ? 1_i32 : 0_i32
  end

  # Mirrors: fun scribe_start_recording(output_path) : LibC::Int
  # In the real bridge, this creates a CrystalAudio::Recorder and calls .start
  # Here we simulate the state changes without hardware.
  def self.start_recording(output_path : String) : Int32
    if BridgeState.recording?
      return -1_i32
    end

    # Simulate successful recorder creation and start
    BridgeState.has_recorder = true
    BridgeState.recording = true
    0_i32
  rescue
    BridgeState.recording = false
    BridgeState.has_recorder = false
    -1_i32
  end

  # Mirrors: fun scribe_stop_recording : LibC::Int
  def self.stop_recording : Int32
    return -1_i32 unless BridgeState.recording?

    # Simulate recorder.stop
    BridgeState.has_recorder = false
    BridgeState.recording = false
    0_i32
  rescue
    -1_i32
  end

  # Mirrors: fun scribe_start_playback(file_path) : LibC::Int
  # In the real bridge, this stops any existing player, creates a new one, plays.
  def self.start_playback(file_path : String) : Int32
    # Stop any in-progress playback before starting new (mirrors bridge behavior)
    BridgeState.has_player = false

    # Simulate successful player creation and play
    BridgeState.has_player = true
    0_i32
  rescue
    -1_i32
  end

  # Mirrors: fun scribe_stop_playback : LibC::Int
  def self.stop_playback : Int32
    BridgeState.has_player = false
    0_i32
  rescue
    -1_i32
  end
end

# ---------------------------------------------------------------------------
# Specs
# ---------------------------------------------------------------------------

describe "Scribe Bridge State Machine" do
  before_each do
    BridgeState.reset!
  end

  describe "initialization" do
    # FEATURE STORY: Epic 7, Stories 7.1-7.4 (all platforms need initialization)
    it "returns 0 on successful init" do
      BridgeAPI.init.should eq 0
    end

    it "sets initialized flag" do
      BridgeState.initialized?.should be_false
      BridgeAPI.init
      BridgeState.initialized?.should be_true
    end

    it "is idempotent (double init is safe)" do
      BridgeAPI.init.should eq 0
      BridgeAPI.init.should eq 0
    end
  end

  describe "recording state machine" do
    # FEATURE STORY: Epic 7, Story 7.1 (iOS Record), Story 7.2 (Android Record)
    it "reports not recording initially" do
      BridgeAPI.is_recording.should eq 0
    end

    it "gracefully rejects stop when not recording" do
      BridgeAPI.stop_recording.should eq -1
    end

    it "transitions to recording state on start" do
      BridgeAPI.start_recording("/tmp/test.wav").should eq 0
      BridgeAPI.is_recording.should eq 1
      BridgeState.has_recorder?.should be_true
    end

    it "rejects double start (already recording)" do
      BridgeAPI.start_recording("/tmp/test.wav").should eq 0
      BridgeAPI.start_recording("/tmp/test2.wav").should eq -1
    end

    it "still reports recording after rejected double start" do
      BridgeAPI.start_recording("/tmp/test.wav")
      BridgeAPI.start_recording("/tmp/test2.wav")
      BridgeAPI.is_recording.should eq 1
    end

    it "transitions back to not-recording on stop" do
      BridgeAPI.start_recording("/tmp/test.wav")
      BridgeAPI.stop_recording.should eq 0
      BridgeAPI.is_recording.should eq 0
      BridgeState.has_recorder?.should be_false
    end

    it "rejects stop after already stopped" do
      BridgeAPI.start_recording("/tmp/test.wav")
      BridgeAPI.stop_recording.should eq 0
      BridgeAPI.stop_recording.should eq -1
    end

    it "allows start → stop → start cycle" do
      BridgeAPI.start_recording("/tmp/test1.wav").should eq 0
      BridgeAPI.is_recording.should eq 1

      BridgeAPI.stop_recording.should eq 0
      BridgeAPI.is_recording.should eq 0

      BridgeAPI.start_recording("/tmp/test2.wav").should eq 0
      BridgeAPI.is_recording.should eq 1
    end
  end

  describe "playback state machine" do
    # FEATURE STORY: Epic 7, Story 7.3 (iOS Recordings), Story 7.4 (Android Recordings)
    it "gracefully handles stop when nothing is playing" do
      BridgeAPI.stop_playback.should eq 0
    end

    it "starts playback successfully" do
      BridgeAPI.start_playback("/tmp/test.wav").should eq 0
      BridgeState.has_player?.should be_true
    end

    it "stops playback successfully" do
      BridgeAPI.start_playback("/tmp/test.wav")
      BridgeAPI.stop_playback.should eq 0
      BridgeState.has_player?.should be_false
    end

    it "allows starting new playback while already playing (replaces)" do
      BridgeAPI.start_playback("/tmp/test1.wav").should eq 0
      BridgeAPI.start_playback("/tmp/test2.wav").should eq 0
      BridgeState.has_player?.should be_true
    end

    it "allows stop after replacement playback" do
      BridgeAPI.start_playback("/tmp/test1.wav")
      BridgeAPI.start_playback("/tmp/test2.wav")
      BridgeAPI.stop_playback.should eq 0
      BridgeState.has_player?.should be_false
    end
  end

  describe "recording and playback independence" do
    # FEATURE STORY: Epic 7, Stories 7.1-7.4 (cross-cutting concern)
    it "allows recording and playback simultaneously" do
      BridgeAPI.start_recording("/tmp/rec.wav").should eq 0
      BridgeAPI.start_playback("/tmp/play.wav").should eq 0
      BridgeAPI.is_recording.should eq 1
      BridgeState.has_player?.should be_true
    end

    it "stopping playback does not affect recording" do
      BridgeAPI.start_recording("/tmp/rec.wav")
      BridgeAPI.start_playback("/tmp/play.wav")
      BridgeAPI.stop_playback
      BridgeAPI.is_recording.should eq 1
    end

    it "stopping recording does not affect playback" do
      BridgeAPI.start_recording("/tmp/rec.wav")
      BridgeAPI.start_playback("/tmp/play.wav")
      BridgeAPI.stop_recording
      BridgeState.has_player?.should be_true
      BridgeAPI.is_recording.should eq 0
    end
  end

  describe "return code contracts" do
    # FEATURE STORY: Epic 7, Stories 7.1-7.4 (all bridge functions)
    it "init always returns 0 (success) or -1 (error)" do
      result = BridgeAPI.init
      (result == 0 || result == -1).should be_true
    end

    it "is_recording returns only 0 or 1" do
      result = BridgeAPI.is_recording
      (result == 0 || result == 1).should be_true
    end

    it "start_recording returns only 0 or -1" do
      result = BridgeAPI.start_recording("/tmp/test.wav")
      (result == 0 || result == -1).should be_true
    end

    it "stop_recording returns only 0 or -1" do
      result = BridgeAPI.stop_recording
      (result == 0 || result == -1).should be_true
    end

    it "start_playback returns only 0 or -1" do
      result = BridgeAPI.start_playback("/tmp/test.wav")
      (result == 0 || result == -1).should be_true
    end

    it "stop_playback returns only 0 or -1" do
      result = BridgeAPI.stop_playback
      (result == 0 || result == -1).should be_true
    end
  end
end
