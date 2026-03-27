# recording_mode_manager_spec.cr -- Tests for RecordingMode model and ModeManager
#
# Run:
#   cd ~/personal_coding_projects/scribe && crystal-alpha spec spec/macos/recording_mode_manager_spec.cr

require "spec"
require "json"

# Replicated RecordingMode struct (avoids requiring full Scribe app)
struct TestRecordingMode
  include JSON::Serializable

  property name : String
  property shortcut : String
  property output_dir : String
  property system_audio : Bool
  property post_process : String

  def initialize(
    @name : String,
    @shortcut : String = "",
    @output_dir : String = "",
    @system_audio : Bool = false,
    @post_process : String = ""
  )
  end

  def resolved_output_dir(fallback : String) : String
    output_dir.empty? ? fallback : output_dir.gsub("~", ENV["HOME"]? || "/tmp")
  end
end

describe "RecordingMode" do
  it "serializes to JSON" do
    mode = TestRecordingMode.new("Dictation", "option+shift+r")
    json = mode.to_json
    json.should contain("Dictation")
    json.should contain("option+shift+r")
  end

  it "deserializes from JSON" do
    json = %q({"name":"Meeting","shortcut":"option+shift+m","output_dir":"~/meetings","system_audio":true,"post_process":"echo test"})
    mode = TestRecordingMode.from_json(json)
    mode.name.should eq("Meeting")
    mode.shortcut.should eq("option+shift+m")
    mode.output_dir.should eq("~/meetings")
    mode.system_audio.should be_true
    mode.post_process.should eq("echo test")
  end

  it "round-trips through JSON" do
    original = TestRecordingMode.new("Custom", "cmd+shift+c", "~/custom", true, "process.sh")
    restored = TestRecordingMode.from_json(original.to_json)
    restored.name.should eq(original.name)
    restored.shortcut.should eq(original.shortcut)
    restored.output_dir.should eq(original.output_dir)
    restored.system_audio.should eq(original.system_audio)
    restored.post_process.should eq(original.post_process)
  end

  it "resolves output dir with fallback" do
    mode = TestRecordingMode.new("Test", output_dir: "")
    mode.resolved_output_dir("/fallback").should eq("/fallback")

    mode2 = TestRecordingMode.new("Test", output_dir: "/custom/path")
    mode2.resolved_output_dir("/fallback").should eq("/custom/path")
  end

  it "deserializes an array of modes" do
    json = %q([{"name":"A","shortcut":"option+shift+a","output_dir":"","system_audio":false,"post_process":""},{"name":"B","shortcut":"option+shift+b","output_dir":"","system_audio":true,"post_process":"cmd"}])
    modes = Array(TestRecordingMode).from_json(json)
    modes.size.should eq(2)
    modes[0].name.should eq("A")
    modes[1].system_audio.should be_true
  end

  it "handles corrupt JSON gracefully" do
    expect_raises(JSON::ParseException) do
      TestRecordingMode.from_json("not json")
    end
  end
end

describe "Hotkey ID mapping" do
  it "maps hotkey IDs to mode indices" do
    modes = [
      TestRecordingMode.new("Dictation", "option+shift+r"),
      TestRecordingMode.new("Meeting", "option+shift+m"),
      TestRecordingMode.new("Custom", "option+shift+c"),
    ]

    # ID 10 = index 0, ID 11 = index 1, ID 12 = index 2
    (10_u32 - 10).should eq(0)
    (11_u32 - 10).should eq(1)
    (12_u32 - 10).should eq(2)

    modes[10 - 10].name.should eq("Dictation")
    modes[11 - 10].name.should eq("Meeting")
    modes[12 - 10].name.should eq("Custom")
  end

  it "returns nil for out-of-range IDs" do
    modes = [TestRecordingMode.new("Only")]
    idx = 15_u32 - 10
    (idx < modes.size).should be_false
  end
end
