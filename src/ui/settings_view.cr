{% if flag?(:macos) %}

module Scribe::UI::SettingsView
  @@editing_mode_name : String? = nil

  def self.build : ::UI::VStack
    if editing = @@editing_mode_name
      build_mode_editor(editing)
    else
      build_main
    end
  end

  def self.edit_mode(name : String?)
    @@editing_mode_name = name
  end

  private def self.build_main : ::UI::VStack
    primary = Scribe::Platform::MacOS::SystemColors.label
    secondary = Scribe::Platform::MacOS::SystemColors.secondary_label
    tertiary = Scribe::Platform::MacOS::SystemColors.tertiary_label

    root = ::UI::VStack.new(spacing: 20.0)

    # --- Audio Save Location (GroupBox) ---
    audio_group = ::UI::GroupBox.new("Audio Save Location")
    audio_dir_row = ::UI::HStack.new(spacing: 8.0)
    audio_dir_label = ::UI::Label.new(Scribe::Settings::Manager.display_path(Scribe::Settings::Manager.output_dir))
    audio_dir_label.font = ::UI::Font.new(size: 13.0, weight: :regular)
    audio_dir_label.text_color = secondary
    audio_dir_label.accessibility_label = "Current audio save location: #{Scribe::Settings::Manager.display_path(Scribe::Settings::Manager.output_dir)}"
    audio_dir_row << audio_dir_label
    audio_browse_btn = ::UI::Button.new("Browse...") {
      path_ptr = Scribe::Platform::MacOS::LibScribePlatform.scribe_choose_folder("Choose Audio Save Location".to_unsafe)
      unless path_ptr.null?
        path = String.new(path_ptr)
        Scribe::Platform::MacOS::LibScribePlatform.scribe_free_string(path_ptr)
        Scribe::Settings::Manager.set("output_dir", path)
        Scribe::Platform::MacOS::App.reopen_settings
      end
      nil
    }
    audio_browse_btn.accessibility_label = "Browse for audio save location"
    audio_dir_row << audio_browse_btn
    audio_group << audio_dir_row
    root << audio_group

    # --- Recording Modes ---
    root << section_header("Recording Modes:", primary)

    modes = Scribe::ProcessManagers::RecordingModeManager.modes
    active_name = Scribe::ProcessManagers::RecordingModeManager.active_mode.name

    modes.each do |mode|
      mode_row = ::UI::HStack.new(spacing: 8.0)

      name_label = ::UI::Label.new(mode.name)
      name_label.font = ::UI::Font.new(size: 13.0, weight: :semibold)
      name_label.text_color = primary
      name_label.accessibility_label = "#{mode.name} recording mode"
      mode_row << name_label

      shortcut_label = ::UI::Label.new(mode.shortcut.upcase.gsub("+", "+"))
      shortcut_label.font = ::UI::Font.new(size: 11.0, weight: :regular, family: "monospace")
      shortcut_label.text_color = tertiary
      shortcut_label.accessibility_label = "Keyboard shortcut: #{mode.shortcut}"
      mode_row << shortcut_label

      mode_row << ::UI::Spacer.new

      mode_name = mode.name
      edit_btn = ::UI::Button.new("Edit") {
        Scribe::UI::SettingsView.edit_mode(mode_name)
        Scribe::Platform::MacOS::App.reopen_settings
        nil
      }
      edit_btn.accessibility_label = "Edit #{mode_name} recording mode"
      mode_row << edit_btn

      root << mode_row

      summary = ::UI::Label.new(mode.summary)
      summary.font = ::UI::Font.new(size: 10.0, weight: :regular)
      summary.text_color = tertiary
      root << summary
    end

    add_btn = ::UI::Button.new("+ Add Mode") {
      new_mode = Scribe::Models::RecordingMode.new(name: "New Mode", shortcut: "option+shift+n")
      Scribe::ProcessManagers::RecordingModeManager.add_mode(new_mode)
      Scribe::Platform::MacOS::HotkeyManager.register_from_modes(Scribe::ProcessManagers::RecordingModeManager.modes)
      Scribe::UI::SettingsView.edit_mode("New Mode")
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    add_btn.accessibility_label = "Add a new recording mode"
    root << add_btn

    # --- Startup (GroupBox + Toggle) ---
    startup_group = ::UI::GroupBox.new("Startup")
    login_status = Scribe::Platform::MacOS::LibScribePlatform.scribe_launch_at_login_status == 1
    login_toggle = ::UI::Toggle.new("Launch at Login", is_on: login_status)
    login_toggle.accessibility_label = login_status ? "Launch at Login: enabled" : "Launch at Login: disabled"
    login_toggle.on_change = ->(new_state : Bool) {
      if new_state
        Scribe::Platform::MacOS::LibScribePlatform.scribe_launch_at_login_enable
        Scribe::Settings::Manager.set("launch_at_login", "true")
      else
        Scribe::Platform::MacOS::LibScribePlatform.scribe_launch_at_login_disable
        Scribe::Settings::Manager.set("launch_at_login", "false")
      end
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    startup_group << login_toggle

    # Show in Dock toggle
    dock_status = Scribe::Settings::Manager.get("show_dock_icon") == "true"
    dock_toggle = ::UI::Toggle.new("Show in Dock", is_on: dock_status)
    dock_toggle.accessibility_label = dock_status ? "Show in Dock: enabled" : "Show in Dock: disabled"
    dock_toggle.on_change = ->(new_state : Bool) {
      Scribe::Settings::Manager.set("show_dock_icon", new_state ? "true" : "false")
      if new_state
        Scribe::Platform::MacOS::LibScribePlatform.scribe_set_activation_policy_regular(Scribe::Platform::MacOS::App.app_ref)
      else
        Scribe::Platform::MacOS::LibScribePlatform.scribe_set_activation_policy_accessory(Scribe::Platform::MacOS::App.app_ref)
      end
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    startup_group << dock_toggle

    dock_note = footnote("Show Scribe in the Dock for easy access when the menu bar icon is hidden.", secondary)
    startup_group << dock_note

    root << startup_group

    # --- Whisper Model (GroupBox + PopUpButton + Save + Delete) ---
    model_group = ::UI::GroupBox.new("Whisper Model")

    current_model = Scribe::Settings::Manager.whisper_model_name
    model_keys = ["ggml-tiny.en.bin", "ggml-base.en.bin", "ggml-small.en.bin", "ggml-medium.en.bin", "ggml-large-v3.bin"]
    model_labels = [
      "Tiny (75 MB) — Fastest",
      "Base (142 MB) — Good quality",
      "Small (466 MB) — Better",
      "Medium (1.5 GB) — Great",
      "Large v3 (3 GB) — Best, multilingual",
    ]

    display_idx = @@pending_model_idx >= 0 ? @@pending_model_idx : (model_keys.index(current_model) || 1).to_i32
    display_model = model_keys[display_idx]? || current_model

    model_picker = ::UI::PopUpButton.new(items: model_labels, selected_index: display_idx)
    model_picker.accessibility_label = "Select whisper transcription model"
    model_picker.on_change = ->(idx : Int32) {
      @@pending_model_idx = idx
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    model_group << model_picker

    # Status for the displayed model
    model_dir = File.join(Scribe::Settings::Manager.app_support_dir, "models")
    is_downloaded = File.exists?(File.join(model_dir, display_model))
    is_active = display_model == current_model

    # Show download progress if a download is active
    download_progress = Scribe::Settings::Manager.get("model_download_progress")
    if !download_progress.empty? && download_progress != "0"
      progress_label = ::UI::Label.new("⏳ Downloading: #{download_progress}")
      progress_label.font = ::UI::Font.new(size: 12.0, weight: :medium)
      progress_label.text_color = Scribe::Platform::MacOS::SystemColors.accent
      progress_label.accessibility_label = "Download progress: #{download_progress}"
      model_group << progress_label
    else
      status_text = if is_active && is_downloaded
                      "✓ Downloaded and active"
                    elsif is_downloaded
                      "✓ Downloaded — click Apply to switch"
                    else
                      "⬇ Not downloaded — click Apply to download and switch"
                    end
      status_label = ::UI::Label.new(status_text)
      status_label.font = ::UI::Font.new(size: 12.0, weight: :medium)
      status_label.text_color = is_downloaded ? Scribe::Platform::MacOS::SystemColors.system_green : secondary
      status_label.accessibility_label = "Model status: #{status_text}"
      model_group << status_label
    end

    # Action buttons row
    model_btn_row = ::UI::HStack.new(spacing: 12.0)

    # Delete button — only for downloaded models that are NOT currently active
    if is_downloaded && !is_active
      display_model_copy = display_model
      display_label = model_labels[display_idx]? || display_model
      delete_btn = ::UI::Button.new("Delete Model") {
        if @@confirm_delete_model
          # Second click = confirmed — delete the file
          m_dir = File.join(Scribe::Settings::Manager.app_support_dir, "models")
          file_path = File.join(m_dir, display_model_copy)
          File.delete(file_path) if File.exists?(file_path)
          @@confirm_delete_model = false
          Scribe::Platform::MacOS::LibScribePlatform.scribe_notification_send(
            "Model Deleted".to_unsafe,
            "#{display_label} has been removed. You can download it again later.".to_unsafe,
            "model-deleted".to_unsafe
          )
          Scribe::Platform::MacOS::App.reopen_settings
        else
          # First click = show confirmation
          @@confirm_delete_model = true
          Scribe::Platform::MacOS::App.reopen_settings
        end
        nil
      }
      delete_btn.accessibility_label = "Delete this model from disk"
      model_btn_row << delete_btn
    end

    # Show confirmation message if pending delete
    if @@confirm_delete_model && is_downloaded && !is_active
      confirm_label = ::UI::Label.new("Are you sure? Click Delete again to confirm. You can always re-download later.")
      confirm_label.font = ::UI::Font.new(size: 12.0, weight: :medium)
      confirm_label.text_color = Scribe::Platform::MacOS::SystemColors.system_yellow
      confirm_label.accessibility_label = "Confirm model deletion — click Delete Model again to proceed"
      model_group << confirm_label
    end

    model_btn_row << ::UI::Spacer.new

    # Apply button
    model_save_btn = ::UI::Button.new("Apply Model") {
      if cap = Scribe::Platform::MacOS::App.current_capture
        if cap.recording?
          Scribe::Platform::MacOS::App.show_error("Stop recording before changing the model")
          next nil
        end
      end

      @@confirm_delete_model = false
      pending = @@pending_model_idx
      if pending >= 0 && pending < model_keys.size
        new_model = model_keys[pending]
        if new_model != Scribe::Settings::Manager.whisper_model_name
          Scribe::Settings::Manager.set("whisper_model_name", new_model)
          @@pending_model_idx = -1

          m_dir = File.join(Scribe::Settings::Manager.app_support_dir, "models")
          needs_download = !File.exists?(File.join(m_dir, new_model))

          if needs_download
            Scribe::Settings::Manager.set("model_download_progress", "Starting...")
            Scribe::Platform::MacOS::LibScribePlatform.scribe_notification_send(
              "Downloading Model".to_unsafe,
              "Downloading #{model_labels[pending]}. Progress shown in Preferences.".to_unsafe,
              "model-download".to_unsafe
            )
          else
            Scribe::Platform::MacOS::LibScribePlatform.scribe_notification_send(
              "Model Changed".to_unsafe,
              "Switched to #{model_labels[pending]}. Active on next transcription.".to_unsafe,
              "model-changed".to_unsafe
            )
          end
        end
      end
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    model_save_btn.accessibility_label = "Apply selected whisper model"
    model_btn_row << model_save_btn
    model_group << model_btn_row

    model_note = ::UI::Label.new("Select a model and click Apply. Larger models are more accurate but slower.")
    model_note.font = ::UI::Font.new(size: 12.0, weight: :regular)
    model_note.text_color = secondary
    model_group << model_note
    root << model_group

    root << ::UI::Spacer.new
    root
  end

  private def self.build_mode_editor(mode_name : String) : ::UI::VStack
    primary = Scribe::Platform::MacOS::SystemColors.label
    secondary = Scribe::Platform::MacOS::SystemColors.secondary_label
    tertiary = Scribe::Platform::MacOS::SystemColors.tertiary_label

    mode = Scribe::ProcessManagers::RecordingModeManager.modes.find { |m| m.name == mode_name }
    unless mode
      @@editing_mode_name = nil
      return build_main
    end

    root = ::UI::VStack.new(spacing: 14.0)

    back_btn = ::UI::Button.new("← Back to Settings") {
      Scribe::UI::SettingsView.edit_mode(nil)
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    back_btn.accessibility_label = "Go back to main settings"
    root << back_btn

    title = ::UI::Label.new("Edit Mode: #{mode.name}")
    title.font = ::UI::Font.new(size: 17.0, weight: :semibold)
    title.text_color = primary
    title.accessibility_label = "Editing recording mode: #{mode.name}"
    root << title

    # Name
    root << section_header("Name:", primary)
    name_field = ::UI::TextField.new("Mode name")
    name_field.text = mode.name
    name_field.accessibility_label = "Name for this recording mode"
    root << name_field

    # Shortcut
    root << section_header("Keyboard Shortcut:", primary)
    shortcut_field = ::UI::TextField.new("e.g. option+shift+r")
    shortcut_field.text = mode.shortcut
    shortcut_field.accessibility_label = "Keyboard shortcut for this recording mode"
    root << shortcut_field
    root << footnote("Format: option+shift+KEY, cmd+shift+KEY, etc.", secondary)

    # Output Directory
    root << section_header("Output Directory:", primary)
    dir_display = mode.output_dir.empty? ? "(uses global)" : Scribe::Settings::Manager.display_path(mode.output_dir.gsub("~", ENV["HOME"]? || "/tmp"))
    dir_label = ::UI::Label.new(dir_display)
    dir_label.font = ::UI::Font.new(size: 13.0, weight: :regular)
    dir_label.text_color = secondary
    dir_label.accessibility_label = "Current output directory: #{dir_display}"
    root << dir_label
    dir_field = ::UI::TextField.new("Leave empty to use global output folder")
    dir_field.text = mode.output_dir
    dir_field.accessibility_label = "Output directory path for this mode"
    root << dir_field

    # Audio Source
    root << section_header("Audio Source:", primary)
    audio_label = mode.system_audio ? "● Mic + System Audio" : "● Mic Only"
    audio_btn = ::UI::Button.new(audio_label) {
      nil
    }
    audio_btn.accessibility_label = mode.system_audio ? "Audio source: Mic plus System Audio, click to toggle" : "Audio source: Mic Only, click to toggle"
    root << audio_btn
    root << footnote("System Audio captures all sound output. Requires Screen Recording permission.", secondary)

    # Auto-Paste
    root << section_header("After Transcription:", primary)
    paste_label = mode.auto_paste ? "● Auto-paste to active app" : "● Save only (no paste)"
    paste_btn = ::UI::Button.new(paste_label) {
      nil
    }
    paste_btn.accessibility_label = mode.auto_paste ? "Auto-paste enabled, click to toggle" : "Save only, click to toggle"
    root << paste_btn

    # Post-Processing
    root << section_header("Post-Processing Command:", primary)
    pp_field = ::UI::TextField.new("e.g. claude -p 'Summarize' --output-format text")
    pp_field.text = mode.post_process
    pp_field.accessibility_label = "Post-processing command for this mode"
    root << pp_field
    root << footnote("Runs from the output folder. Transcript path is the first argument.", secondary)

    # Edit state tracking
    @@edit_name = mode.name
    @@edit_shortcut = mode.shortcut
    @@edit_output_dir = mode.output_dir
    @@edit_system_audio = mode.system_audio
    @@edit_auto_paste = mode.auto_paste
    @@edit_post_process = mode.post_process

    name_field.on_change = ->(val : String) { @@edit_name = val; nil }
    shortcut_field.on_change = ->(val : String) { @@edit_shortcut = val; nil }
    dir_field.on_change = ->(val : String) { @@edit_output_dir = val; nil }
    pp_field.on_change = ->(val : String) { @@edit_post_process = val; nil }

    # Toggle audio source
    audio_btn.on_tap = ->() {
      @@edit_system_audio = !@@edit_system_audio
      save_pending_edits_and_reopen(mode_name)
      nil
    }

    # Toggle auto-paste
    paste_btn.on_tap = ->() {
      @@edit_auto_paste = !@@edit_auto_paste
      save_pending_edits_and_reopen(mode_name)
      nil
    }

    # Buttons
    btn_row = ::UI::HStack.new(spacing: 12.0)

    if Scribe::ProcessManagers::RecordingModeManager.modes.size > 1
      delete_btn = ::UI::Button.new("Delete") {
        Scribe::ProcessManagers::RecordingModeManager.remove_mode(mode_name)
        Scribe::Platform::MacOS::HotkeyManager.register_from_modes(Scribe::ProcessManagers::RecordingModeManager.modes)
        Scribe::UI::SettingsView.edit_mode(nil)
        Scribe::Platform::MacOS::App.reopen_settings
        nil
      }
      delete_btn.accessibility_label = "Delete this recording mode"
      btn_row << delete_btn
    end

    btn_row << ::UI::Spacer.new

    cancel_btn = ::UI::Button.new("Cancel") {
      Scribe::UI::SettingsView.edit_mode(nil)
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    cancel_btn.accessibility_label = "Cancel editing"
    btn_row << cancel_btn

    save_btn = ::UI::Button.new("Save") {
      updated = Scribe::Models::RecordingMode.new(
        name: @@edit_name,
        shortcut: @@edit_shortcut,
        output_dir: @@edit_output_dir,
        system_audio: @@edit_system_audio,
        auto_paste: @@edit_auto_paste,
        post_process: @@edit_post_process
      )
      Scribe::ProcessManagers::RecordingModeManager.update_mode(mode_name, updated)
      Scribe::Platform::MacOS::HotkeyManager.register_from_modes(Scribe::ProcessManagers::RecordingModeManager.modes)
      Scribe::UI::SettingsView.edit_mode(nil)
      Scribe::Platform::MacOS::App.reopen_settings
      nil
    }
    save_btn.accessibility_label = "Save changes"
    save_btn.key_equivalent = "\r"
    btn_row << save_btn

    root << btn_row
    root << ::UI::Spacer.new
    root
  end

  # Edit state class vars
  @@edit_name : String = ""
  @@edit_shortcut : String = ""
  @@edit_output_dir : String = ""
  @@edit_system_audio : Bool = false
  @@edit_auto_paste : Bool = true
  @@edit_post_process : String = ""
  @@pending_model_idx : Int32 = -1
  @@confirm_delete_model : Bool = false

  private def self.save_pending_edits_and_reopen(mode_name : String)
    updated = Scribe::Models::RecordingMode.new(
      name: @@edit_name,
      shortcut: @@edit_shortcut,
      output_dir: @@edit_output_dir,
      system_audio: @@edit_system_audio,
      auto_paste: @@edit_auto_paste,
      post_process: @@edit_post_process
    )
    Scribe::ProcessManagers::RecordingModeManager.update_mode(mode_name, updated)
    Scribe::UI::SettingsView.edit_mode(@@edit_name)
    Scribe::Platform::MacOS::App.reopen_settings
  end

  private def self.section_header(text : String, color : ::UI::Color) : ::UI::Label
    label = ::UI::Label.new(text)
    label.font = ::UI::Font.new(size: 13.0, weight: :bold)
    label.text_color = color
    label
  end

  private def self.footnote(text : String, color : ::UI::Color) : ::UI::Label
    label = ::UI::Label.new(text)
    label.font = ::UI::Font.new(size: 12.0, weight: :regular)
    label.text_color = color
    label
  end
end

{% end %}
