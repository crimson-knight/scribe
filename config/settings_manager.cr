module Scribe::Settings
  # Manages application settings backed by the ApplicationSetting model.
  # Settings are cached in memory for fast access and persisted to SQLite.
  module Manager
    DEFAULTS = {
      "output_dir"            => "~/Documents/Scribe",
      "shortcut_key"          => "option+shift+r",
      "whisper_model_path"    => "auto",
      "whisper_model_name"    => "ggml-base.en.bin",
      "auto_transcribe"       => "true",
      "inbox_storage_path"    => "~/Library/Application Support/Scribe/inbox",
      "icloud_sync_enabled"   => "auto",
      "work_hours_enabled"    => "false",
      "work_hours_start"      => "09:00",
      "work_hours_end"        => "18:00",
      "work_hours_days"       => "1,2,3,4,5",
      "max_concurrent_jobs"   => "1",
      "recording_mode"        => "dictation",
      "post_process_command"  => "",
      "launch_at_login"       => "false",
      "transcript_save_dir"   => "",
      "wizard_completed"      => "false",
      "recording_modes_json"  => "",
      "log_retention_days"    => "30",
      "show_dock_icon"        => "false",
    }

    @@cache = {} of String => String
    @@loaded = false

    # Load all settings from DB, creating defaults for any missing keys.
    def self.load
      return if @@loaded

      DEFAULTS.each do |key, default_value|
        existing = Scribe::Models::ApplicationSetting.find_by(key: key)
        if existing
          @@cache[key] = existing.value
        else
          setting = Scribe::Models::ApplicationSetting.new
          setting.key = key
          setting.value = default_value
          setting.save
          @@cache[key] = default_value
        end
      end

      @@loaded = true
    end

    # Get a setting value (returns cached value, or default, or empty string).
    def self.get(key : String) : String
      @@cache[key]? || DEFAULTS[key]? || ""
    end

    # Set a setting value (persists to DB and updates cache).
    def self.set(key : String, value : String)
      existing = Scribe::Models::ApplicationSetting.find_by(key: key)
      if existing
        existing.value = value
        existing.save
      else
        setting = Scribe::Models::ApplicationSetting.new
        setting.key = key
        setting.value = value
        setting.save
      end
      @@cache[key] = value

      Scribe::Events::EventBus.emit(
        Scribe::Events::SETTINGS_CHANGED,
        Scribe::Events::EventData.new(key: key, value: value)
      )
    end

    # Convenience: resolved Application Support directory.
    def self.app_support_dir : String
      File.join(ENV["HOME"]? || "/tmp", "Library/Application Support/Scribe")
    end

    # Convenience: resolved output directory path (~ expanded).
    def self.output_dir : String
      get("output_dir").gsub("~", ENV["HOME"]? || "/tmp")
    end

    # Convenience: whether to auto-transcribe after recording.
    def self.auto_transcribe? : Bool
      get("auto_transcribe") == "true"
    end

    # Convenience: whisper model path setting.
    def self.whisper_model_path : String
      get("whisper_model_path")
    end

    # Convenience: keyboard shortcut string.
    def self.shortcut_key : String
      get("shortcut_key")
    end

    # Convenience: whisper model filename (e.g. "ggml-base.en.bin").
    def self.whisper_model_name : String
      get("whisper_model_name")
    end

    # Convenience: resolved inbox storage path (~ expanded).
    def self.inbox_storage_path : String
      get("inbox_storage_path").gsub("~", ENV["HOME"]? || "/tmp")
    end

    # Convenience: iCloud base path for Scribe data.
    def self.icloud_base_path : String
      home = ENV["HOME"]? || "/tmp"
      File.join(home, "Library/Mobile Documents/com~apple~CloudDocs/Scribe")
    end

    # Convenience: whether work hours scheduling is enabled (Epic 13.3).
    def self.work_hours_enabled? : Bool
      get("work_hours_enabled") == "true"
    end

    # Convenience: work hours start time string (e.g. "09:00").
    def self.work_hours_start : String
      get("work_hours_start")
    end

    # Convenience: work hours end time string (e.g. "18:00").
    def self.work_hours_end : String
      get("work_hours_end")
    end

    # Convenience: work hours allowed days as comma-separated ISO weekdays.
    def self.work_hours_days : String
      get("work_hours_days")
    end

    # Convenience: max concurrent CLI jobs (Epic 13.4).
    def self.max_concurrent_jobs : Int32
      get("max_concurrent_jobs").to_i32 rescue 1
    end

    # Convenience: current recording mode ("dictation" or "meeting").
    def self.recording_mode : String
      get("recording_mode")
    end

    # Convenience: whether meeting mode is active.
    def self.meeting_mode? : Bool
      recording_mode == "meeting"
    end

    # Convenience: post-processing CLI command (empty = disabled).
    def self.post_process_command : String
      get("post_process_command")
    end

    # Convenience: whether launch at login is enabled.
    def self.launch_at_login? : Bool
      get("launch_at_login") == "true"
    end

    # Convenience: resolved transcript save directory (~ expanded).
    # Falls back to output_dir when empty.
    def self.transcript_save_dir : String
      val = get("transcript_save_dir")
      if val.empty?
        output_dir
      else
        val.gsub("~", ENV["HOME"]? || "/tmp")
      end
    end

    # Convenience: whether iCloud sync is enabled.
    # "auto" mode checks if iCloud Drive parent directory exists.
    def self.icloud_sync_enabled? : Bool
      value = get("icloud_sync_enabled")
      case value
      when "true"
        true
      when "false"
        false
      else
        # Auto-detect: check if iCloud Drive container directory exists
        home = ENV["HOME"]? || "/tmp"
        icloud_container = File.join(home, "Library/Mobile Documents/com~apple~CloudDocs")
        Dir.exists?(icloud_container)
      end
    end

    # Display helper: shorten paths by replacing home directory with ~.
    def self.display_path(path : String) : String
      home = ENV["HOME"]? || ""
      if !home.empty? && path.starts_with?(home)
        "~" + path[home.size..]
      else
        path
      end
    end
  end
end
