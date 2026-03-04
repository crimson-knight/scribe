# scribe_bridge.cr — C API exposed to native host apps
#
# iOS (static library via Swift bridging header):
#   crystal-alpha build shared/scribe_bridge.cr \
#     --target arm64-apple-ios-simulator \
#     --cross-compile --define ios --define shared \
#     -o ios/build/scribe_bridge
#
# Android (shared library via JNI):
#   crystal-alpha build shared/scribe_bridge.cr \
#     --cross-compile --target aarch64-linux-android26 \
#     --define android --release \
#     -o android/build/scribe_bridge

{% unless flag?(:darwin) || flag?(:android) %}
  {% raise "scribe_bridge.cr requires a Darwin (macOS/iOS) or Android target" %}
{% end %}

require "crystal_audio"

# Override Crystal's auto-generated main (unix/main.cr defines one unconditionally).
# Swift provides @main; Crystal's main must be a no-op.
# The _main symbol is also made local via ld -r after cross-compilation.
fun main(argc : Int32, argv : UInt8**) : Int32
  0
end

# C trace helper — writes to stderr with zero Crystal runtime dependency
lib LibTrace
  fun crystal_trace(msg : UInt8*)
end

# ---------------------------------------------------------------------------
# Module-level state
# ---------------------------------------------------------------------------

private module Bridge
  @@initialized : Bool = false
  @@recorder : CrystalAudio::Recorder? = nil
  @@recording : Bool = false
  @@player : CrystalAudio::Player? = nil

  def self.recorder : CrystalAudio::Recorder?
    @@recorder
  end

  def self.recorder=(r : CrystalAudio::Recorder?)
    @@recorder = r
  end

  def self.recording? : Bool
    @@recording
  end

  def self.recording=(v : Bool)
    @@recording = v
  end

  def self.player : CrystalAudio::Player?
    @@player
  end

  def self.player=(p : CrystalAudio::Player?)
    @@player = p
  end

  def self.initialized? : Bool
    @@initialized
  end

  def self.initialized=(v : Bool)
    @@initialized = v
  end
end

# ---------------------------------------------------------------------------
# Public C API — callable from Swift via the bridging header
# ---------------------------------------------------------------------------

fun scribe_init : LibC::Int
  LibTrace.crystal_trace("scribe_init: entered".to_unsafe)

  LibTrace.crystal_trace("scribe_init: calling GC.init".to_unsafe)
  GC.init
  LibTrace.crystal_trace("scribe_init: GC.init done".to_unsafe)

  LibTrace.crystal_trace("scribe_init: calling Crystal.init_runtime".to_unsafe)
  Crystal.init_runtime
  LibTrace.crystal_trace("scribe_init: Crystal.init_runtime done".to_unsafe)

  LibTrace.crystal_trace("scribe_init: calling Thread.current".to_unsafe)
  Thread.current
  LibTrace.crystal_trace("scribe_init: Thread.current done".to_unsafe)

  Bridge.initialized = true
  LibTrace.crystal_trace("scribe_init: complete, returning 0".to_unsafe)
  0
rescue ex
  LibTrace.crystal_trace("scribe_init: EXCEPTION caught!".to_unsafe)
  -1
end

fun scribe_start_recording(output_path : LibC::Char*) : LibC::Int
  LibTrace.crystal_trace("scribe_start_recording: entered".to_unsafe)

  if Bridge.recording?
    LibTrace.crystal_trace("scribe_start_recording: already recording".to_unsafe)
    return -1
  end

  path = String.new(output_path)
  LibTrace.crystal_trace("scribe_start_recording: creating Recorder".to_unsafe)

  rec = CrystalAudio::Recorder.new(
    source:      CrystalAudio::RecordingSource::Microphone,
    output_path: path
  )
  LibTrace.crystal_trace("scribe_start_recording: calling rec.start".to_unsafe)
  rec.start
  LibTrace.crystal_trace("scribe_start_recording: rec.start done".to_unsafe)

  Bridge.recorder = rec
  Bridge.recording = true
  LibTrace.crystal_trace("scribe_start_recording: returning 0".to_unsafe)
  0
rescue ex
  LibTrace.crystal_trace("scribe_start_recording: EXCEPTION caught!".to_unsafe)
  Bridge.recording = false
  Bridge.recorder = nil
  -1
end

fun scribe_stop_recording : LibC::Int
  LibTrace.crystal_trace("scribe_stop_recording: entered".to_unsafe)
  return -1 unless Bridge.recording?

  Bridge.recorder.try(&.stop)
  Bridge.recorder = nil
  Bridge.recording = false
  LibTrace.crystal_trace("scribe_stop_recording: done".to_unsafe)
  0
rescue
  -1
end

fun scribe_is_recording : LibC::Int
  Bridge.recording? ? 1 : 0
end

fun scribe_start_playback(file_path : LibC::Char*) : LibC::Int
  LibTrace.crystal_trace("scribe_start_playback: entered".to_unsafe)

  # Stop any in-progress playback before starting new
  Bridge.player.try(&.stop)
  Bridge.player = nil

  path = String.new(file_path)
  LibTrace.crystal_trace("scribe_start_playback: creating Player".to_unsafe)

  player = CrystalAudio::Player.new
  player.add_track(path)
  player.play

  Bridge.player = player
  LibTrace.crystal_trace("scribe_start_playback: playing".to_unsafe)
  0
rescue
  LibTrace.crystal_trace("scribe_start_playback: EXCEPTION".to_unsafe)
  -1
end

fun scribe_stop_playback : LibC::Int
  LibTrace.crystal_trace("scribe_stop_playback: entered".to_unsafe)
  Bridge.player.try(&.stop)
  Bridge.player = nil
  LibTrace.crystal_trace("scribe_stop_playback: done".to_unsafe)
  0
rescue
  -1
end
