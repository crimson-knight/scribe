require "json"

module Scribe::ProcessManagers
  # Manages recording modes — user-definable profiles with per-mode
  # keyboard shortcuts, output directories, audio sources, and post-processing.
  module RecordingModeManager
    @@modes = [] of Scribe::Models::RecordingMode
    @@active_mode_name : String = "Dictation"

    DEFAULT_MODES = [
      Scribe::Models::RecordingMode.new(
        name: "Dictation",
        shortcut: "option+shift+r",
        system_audio: false,
        auto_paste: true
      ),
      Scribe::Models::RecordingMode.new(
        name: "Meeting",
        shortcut: "option+shift+m",
        system_audio: true,
        auto_paste: false
      ),
    ]

    # Load modes from settings. Falls back to defaults if empty or corrupt.
    def self.load
      json = Scribe::Settings::Manager.get("recording_modes_json")
      if json.empty?
        @@modes = DEFAULT_MODES.dup
        save(@@modes)
      else
        begin
          @@modes = Array(Scribe::Models::RecordingMode).from_json(json)
          if @@modes.empty?
            @@modes = DEFAULT_MODES.dup
            save(@@modes)
          end
        rescue ex
          STDERR.puts "[ModeManager] Failed to parse modes JSON: #{ex.message}"
          @@modes = DEFAULT_MODES.dup
          save(@@modes)
        end
      end
      @@active_mode_name = @@modes.first.name
      puts "[ModeManager] Loaded #{@@modes.size} modes: #{@@modes.map(&.name).join(", ")}"
    end

    # Save modes to settings.
    def self.save(modes : Array(Scribe::Models::RecordingMode))
      @@modes = modes
      Scribe::Settings::Manager.set("recording_modes_json", modes.to_json)
    end

    # Get all modes.
    def self.modes : Array(Scribe::Models::RecordingMode)
      @@modes
    end

    # Get the currently active mode.
    def self.active_mode : Scribe::Models::RecordingMode
      @@modes.find { |m| m.name == @@active_mode_name } || @@modes.first? || DEFAULT_MODES.first
    end

    # Set the active mode by name.
    def self.set_active(name : String)
      @@active_mode_name = name
    end

    # Find a mode by hotkey ID (IDs are 10 + index in the modes array).
    def self.find_by_hotkey_id(id : UInt32) : Scribe::Models::RecordingMode?
      idx = id.to_i32 - 10
      @@modes[idx]? if idx >= 0 && idx < @@modes.size
    end

    # Add a new mode.
    def self.add_mode(mode : Scribe::Models::RecordingMode)
      @@modes << mode
      save(@@modes)
    end

    # Remove a mode by name (won't remove the last mode).
    def self.remove_mode(name : String) : Bool
      return false if @@modes.size <= 1
      @@modes.reject! { |m| m.name == name }
      save(@@modes)
      true
    end

    # Update a mode by name.
    def self.update_mode(old_name : String, mode : Scribe::Models::RecordingMode)
      idx = @@modes.index { |m| m.name == old_name }
      if idx
        @@modes[idx] = mode
        save(@@modes)
      end
    end
  end
end
