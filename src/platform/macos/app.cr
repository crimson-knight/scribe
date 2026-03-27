{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # FFI bindings for scribe_platform_bridge.m
  lib LibScribePlatform
    # Application lifecycle
    fun scribe_shared_application : Void*
    fun scribe_set_activation_policy_regular(app : Void*) : Void
    fun scribe_set_activation_policy_accessory(app : Void*) : Void
    fun scribe_activate_app(app : Void*) : Void
    fun scribe_run_app(app : Void*) : Void
    fun scribe_bring_window_to_front_async(window : Void*) : Void
    fun scribe_terminate_app(app : Void*) : Void

    # Window
    fun scribe_create_window(x : Float64, y : Float64, w : Float64, h : Float64,
                             style_mask : UInt64) : Void*
    fun scribe_set_window_title(window : Void*, title : UInt8*) : Void
    fun scribe_set_window_level(window : Void*, level : Int32) : Void
    fun scribe_set_content_view(window : Void*, view : Void*) : Void
    fun scribe_center_window(window : Void*) : Void
    fun scribe_make_key_and_order_front(window : Void*) : Void
    fun scribe_close_window(window : Void*) : Void
    fun scribe_show_window(window : Void*) : Void

    # Status item (menu bar)
    fun scribe_create_status_item : Void*
    fun scribe_set_status_item_title(item : Void*, title : UInt8*) : Void
    fun scribe_set_status_item_image(item : Void*, system_name : UInt8*) : Void

    # Menu
    fun scribe_create_menu(title : UInt8*) : Void*
    fun scribe_set_status_item_menu(item : Void*, menu : Void*) : Void
    fun scribe_add_menu_item(menu : Void*, title : UInt8*, key : UInt8*) : Void*
    fun scribe_add_menu_separator(menu : Void*) : Void
    fun scribe_set_menu_item_action(item : Void*, sel : Void*) : Void
    fun scribe_set_menu_item_target(item : Void*, target : Void*) : Void
    fun scribe_set_menu_item_title(item : Void*, title : UInt8*) : Void

    # Submenu & menu item management (Section 15b)
    fun scribe_set_menu_item_submenu(item : Void*, submenu : Void*) : Void
    fun scribe_remove_all_menu_items(menu : Void*) : Void
    fun scribe_set_menu_item_enabled(item : Void*, enabled : Int32) : Void

    # Recording indicator panel
    fun scribe_create_recording_indicator : Void*
    fun scribe_show_recording_indicator(window : Void*) : Void
    fun scribe_hide_recording_indicator(window : Void*) : Void
    fun scribe_update_recording_indicator_text(window : Void*, text : UInt8*) : Void

    # Menu item callbacks
    alias MenuItemCallback = (UInt32) -> Void
    fun scribe_install_menu_callback(callback : MenuItemCallback) : Void
    fun scribe_get_menu_target : Void*
    fun scribe_set_menu_item_tag(item : Void*, tag : UInt32) : Void

    # Global keyboard shortcuts (Carbon)
    alias HotkeyCallback = (UInt32) -> Void
    fun scribe_hotkey_install_handler(callback : HotkeyCallback) : Int32
    fun scribe_hotkey_register(hotkey_id : UInt32, modifier_flags : UInt32,
                               key_code : UInt32, out_ref : Void**) : Int32
    fun scribe_hotkey_unregister(ref : Void*) : Int32

    # GCD async dispatch (avoids blocked Crystal fiber scheduler -- GAP-19)
    alias BackgroundWorkFn = -> Void
    alias MainThreadCallbackFn = -> Void
    fun scribe_dispatch_background(work : BackgroundWorkFn, callback : MainThreadCallbackFn) : Void

    # Clipboard
    fun scribe_clipboard_read : UInt8*
    fun scribe_clipboard_write(text : UInt8*) : Int32
    fun scribe_clipboard_free(ptr : UInt8*) : Void

    # Accessibility permission check
    fun scribe_accessibility_check(prompt : Int32) : Int32

    # Clipboard paste cycle (GCD-timed, non-blocking)
    alias PasteCycleCallback = (Int32) -> Void
    fun scribe_install_paste_cycle_callback(callback : PasteCycleCallback) : Void
    fun scribe_clipboard_paste_cycle(text : UInt8*) : Void

    # Whisper transcription (C wrapper -- avoids FullParams struct mismatch, GAP-21)
    fun scribe_whisper_init(model_path : UInt8*) : Void*
    fun scribe_whisper_free(ctx : Void*) : Void
    fun scribe_whisper_transcribe(ctx : Void*, samples : Float32*, n_samples : Int32,
                                   language : UInt8*, n_threads : Int32) : UInt8*
    fun scribe_whisper_free_result(text : UInt8*) : Void

    # HTTP file download via NSURLSession (Section 12)
    alias DownloadProgressCallback = (Int64, Int64) -> Void
    alias DownloadCompletionCallback = (Int32, UInt8*) -> Void
    fun scribe_download_file(url : UInt8*, dest_path : UInt8*,
                              progress_callback : DownloadProgressCallback,
                              completion_callback : DownloadCompletionCallback) : Void

    # Notifications (Section 13 -- UNUserNotificationCenter)
    fun scribe_notifications_request_auth : Void
    fun scribe_notification_send(title : UInt8*, body : UInt8*, identifier : UInt8*) : Void

    # FSEvents file watching (Section 14 -- iCloud Sync, Epic 12)
    alias FSEventsCallback = (UInt8*, UInt32) -> Void
    fun scribe_fsevents_start(path : UInt8*, callback : FSEventsCallback) : Void*
    fun scribe_fsevents_stop(stream : Void*) : Void

    # Launch at Login (Section 15 — SMAppService, macOS 13.0+)
    fun scribe_launch_at_login_status : Int32
    fun scribe_launch_at_login_enable : Int32
    fun scribe_launch_at_login_disable : Int32

    # Folder picker (Section 16 — NSOpenPanel)
    fun scribe_choose_folder(title : UInt8*) : UInt8*
    fun scribe_choose_file(title : UInt8*) : UInt8*
    fun scribe_free_string(str : UInt8*) : Void

    # System colors (Section 17 — adaptive Light/Dark mode)
    fun scribe_get_label_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_secondary_label_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_tertiary_label_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_control_accent_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_window_background_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_system_green_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_system_red_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_system_yellow_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_separator_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_get_link_color(r : Float64*, g : Float64*, b : Float64*, a : Float64*) : Void
    fun scribe_open_url(url : UInt8*) : Void
    fun scribe_accessibility_announce(text : UInt8*) : Void

    # Screen Recording permission (Section 17b)
    fun scribe_screen_capture_check : Int32
    fun scribe_screen_capture_request : Int32

    # Open System Settings (Section 18 — permission flows)
    fun scribe_open_system_settings(url : UInt8*) : Void

    # App Restart (Section 19b — relaunch after permission changes)
    fun scribe_restart_app : Void

    # NSStackView edge insets (Section 20 — padding for VStack/HStack)
    fun scribe_stackview_set_edge_insets(stackview : Void*,
                                          top : Float64, left : Float64,
                                          bottom : Float64, right : Float64) : Void

    # ObjC runtime (for selector lookup)
    fun sel_registerName(name : UInt8*) : Void*
  end

  # Helper module: resolve macOS semantic system colors at runtime.
  # These adapt automatically to Light/Dark mode.
  module SystemColors
    def self.label : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_label_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.secondary_label : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_secondary_label_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.tertiary_label : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_tertiary_label_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.accent : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_control_accent_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.system_green : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_system_green_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.system_red : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_system_red_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.system_yellow : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_system_yellow_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.separator : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_separator_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end

    def self.link : ::UI::Color
      r = 0.0_f64; g = 0.0_f64; b = 0.0_f64; a = 1.0_f64
      LibScribePlatform.scribe_get_link_color(pointerof(r), pointerof(g), pointerof(b), pointerof(a))
      ::UI::Color.new(r, g, b, a)
    end
  end

  # (crystal_ui_callback_dispatch is defined at global scope below — Crystal requires `fun` at top level)

  # Carbon modifier flags
  CMD_KEY     = 0x0100_u32
  SHIFT_KEY   = 0x0200_u32
  OPTION_KEY  = 0x0800_u32
  CONTROL_KEY = 0x1000_u32

  # Carbon virtual key codes
  VK_R = 0x0F_u32
  VK_S = 0x01_u32

  # Hotkey IDs
  HOTKEY_TOGGLE_RECORDING = 1_u32

  # Menu item tags (identify which menu item was clicked)
  MENU_TAG_TOGGLE_RECORDING = 1_u32

  # Slim orchestrator: delegates to focused manager modules.
  # Extracted from the original 506-line monolith (Story 8.4).
  module App
    # Shared state -- held here, passed to managers as needed
    @@app : Void* = Pointer(Void).null
    @@status_item : Void* = Pointer(Void).null
    @@record_menu_item : Void* = Pointer(Void).null
    @@capture : Scribe::ProcessManagers::StartAudioCapture? = nil

    # Public accessor for capture state (used by settings view to prevent model change during recording)
    def self.current_capture : Scribe::ProcessManagers::StartAudioCapture?
      @@capture
    end

    @@settings_window : Void* = Pointer(Void).null
    @@settings_view : ::UI::VStack? = nil
    @@settings_renderer : ::UI::AppKit::Renderer? = nil
    @@settings_native_view : ::UI::NativeView? = nil
    @@about_window : Void* = Pointer(Void).null
    @@about_native_view : ::UI::NativeView? = nil
    @@wizard_window : Void* = Pointer(Void).null
    @@wizard_native_view : ::UI::NativeView? = nil
    @@wizard_step : Int32 = 0
    @@recording_indicator : Void* = Pointer(Void).null
    @@output_dir : String = ""
    @@whisper_ctx : Void* = Pointer(Void).null

    # Track state for the async transcription flow
    @@last_audio_path : String? = nil
    @@last_mic_path : String? = nil
    @@last_transcript : String? = nil
    @@last_meeting_transcript : String? = nil
    @@last_transcribe_error : String? = nil
    @@file_transcription_in_progress : Bool = false

    # Track state for post-processing (class vars needed — can't send closures to C)
    @@pp_command : String = ""
    @@pp_transcript_path : String = ""
    @@pp_transcript_dir : String = ""
    @@pp_output : String = ""
    @@pp_exit_code : Int32 = 0

    def self.run
      # First: initialize application (DB, settings, dirs)
      init = Scribe::ProcessManagers::InitializeApplication.new
      init.perform

      # Check for crashed recording from previous session
      repair = Scribe::ProcessManagers::RepairOrphanedRecordings.new
      repair.perform
      if repair.had_crash?
        repair.repaired_files.each do |path|
          puts "[Scribe] Recovered recording: #{path}"
        end
      end

      # Use settings-backed output dir (falls back to ENV override if set)
      @@output_dir = ENV["SCRIBE_OUTPUT_DIR"]? || Scribe::Settings::Manager.output_dir

      # Ensure output directory exists
      Dir.mkdir_p(@@output_dir) unless Dir.exists?(@@output_dir)

      @@capture = Scribe::ProcessManagers::StartAudioCapture.new(output_directory: @@output_dir)

      # Install model management event handlers (Epic 9)
      install_model_event_handlers

      # Install inbox event handlers (Epic 11)
      install_inbox_event_handlers

      # Install notification event handlers (Epic 13)
      install_notification_event_handlers

      # Load whisper model via WhisperBridge (uses DiscoverWhisperModel PM internally)
      @@whisper_ctx = WhisperBridge.load_model

      # If model not found, trigger download (MODEL_MISSING event was already emitted
      # by the discovery PM inside WhisperBridge.load_model)

      # Install paste cycle callback -- fires after clipboard restore completes
      LibScribePlatform.scribe_install_paste_cycle_callback(->(success : Int32) {
        App.on_paste_cycle_complete(success)
      })

      # Create NSApplication as accessory (menu bar only, no dock icon)
      @@app = LibScribePlatform.scribe_shared_application
      LibScribePlatform.scribe_set_activation_policy_accessory(@@app)

      # Setup menu bar and menu via MenuManager
      @@status_item, @@record_menu_item = MenuManager.setup(@@app, @@output_dir)

      # Create the floating recording indicator (hidden until recording starts)
      @@recording_indicator = IndicatorManager.create_indicator

      # Load recording modes and register per-mode keyboard shortcuts
      Scribe::ProcessManagers::RecordingModeManager.load
      HotkeyManager.register_from_modes(Scribe::ProcessManagers::RecordingModeManager.modes)

      # Sync settings changes to runtime state
      install_settings_sync_handlers

      # Start iCloud file watcher if sync is enabled (Epic 12)
      install_icloud_sync_handlers

      puts "Scribe is running in the menu bar."
      puts "Output directory: #{@@output_dir}"
      puts "Press #{Scribe::Settings::Manager.shortcut_key.upcase.gsub("+", "+")} to toggle recording."
      puts "Click the menu bar icon or press Cmd+Q to quit."

      # Show first-run wizard if not completed
      if Scribe::Settings::Manager.get("wizard_completed") != "true"
        show_wizard(0)
      end

      # Run the event loop (blocks until app terminates)
      LibScribePlatform.scribe_activate_app(@@app)
      LibScribePlatform.scribe_run_app(@@app)
    end

    # Wire up event handlers for model discovery, download, verification (Epic 9)
    private def self.install_model_event_handlers
      # When model is missing, auto-download it
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_MISSING) do |data|
        model_name = data["model_name"]? || "ggml-base.en.bin"
        puts "[Scribe] Model missing -- initiating download of #{model_name}"
        downloader = Scribe::ProcessManagers::DownloadWhisperModel.new(model_name: model_name)
        downloader.perform
      end

      # Show download progress in the indicator AND store for preferences display
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_DOWNLOAD_PROGRESS) do |data|
        pct = data["percent"]? || "0"
        bytes = (data["bytes_downloaded"]? || "0").to_i64
        total = (data["total_bytes"]? || "0").to_i64
        mb_done = bytes / (1024 * 1024)
        mb_total = total > 0 ? total / (1024 * 1024) : 0
        progress_text = "#{pct}% (#{mb_done}/#{mb_total} MB)"
        unless @@recording_indicator.null?
          IndicatorManager.show(@@recording_indicator, "Downloading model: #{progress_text}")
        end
        # Store for preferences view to display
        Scribe::Settings::Manager.set("model_download_progress", progress_text)
      end

      # When download completes, verify integrity then load model.
      # NOTE: C callbacks can't capture local vars (GAP-17), so the completion
      # event may not carry path/model_name. Derive from settings instead.
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_DOWNLOAD_COMPLETE) do |data|
        model_name = data["model_name"]? || Scribe::Settings::Manager.whisper_model_name
        home = ENV["HOME"]? || "/tmp"
        path = data["path"]? || File.join(home, "Library/Application Support/Scribe/models", model_name)
        Scribe::Settings::Manager.set("model_download_progress", "") # Clear progress
        puts "[Scribe] Download complete, verifying integrity..."
        unless @@recording_indicator.null?
          IndicatorManager.show(@@recording_indicator, "Verifying model...")
        end
        verifier = Scribe::ProcessManagers::VerifyModelIntegrity.new(
          model_path: path, model_name: model_name
        )
        verifier.perform
      end

      # When model verified after download, notify and refresh preferences.
      # DO NOT reload whisper context at runtime — Metal cleanup crashes.
      # Model will load on next app restart.
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_VERIFIED) do |data|
        path = data["path"]?
        puts "[Scribe] Model downloaded and verified: #{path}"
        unless @@recording_indicator.null?
          IndicatorManager.show(@@recording_indicator, "Model downloaded! Restart to activate.")
          IndicatorManager.hide(@@recording_indicator)
        end
        LibScribePlatform.scribe_notification_send(
          "Model Downloaded".to_unsafe,
          "Model downloaded successfully. Restart Scribe to activate it.".to_unsafe,
          "model-ready".to_unsafe
        )
        reopen_settings unless @@settings_window.null?
      end

      # When download fails, log, notify, and refresh preferences
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_DOWNLOAD_FAILED) do |data|
        error = data["error"]? || "unknown error"
        STDERR.puts "[Scribe] Model download failed: #{error}"
        Scribe::Settings::Manager.set("model_download_progress", "") # Clear progress
        unless @@recording_indicator.null?
          IndicatorManager.show(@@recording_indicator, "Download failed")
          IndicatorManager.hide(@@recording_indicator)
        end
        show_error("Model download failed: #{error}")
        reopen_settings unless @@settings_window.null?
      end

      # When model corrupted, trigger re-download
      Scribe::Events::EventBus.on(Scribe::Events::MODEL_CORRUPTED) do |data|
        model_name = data["model_name"]? || "ggml-base.en.bin"
        STDERR.puts "[Scribe] Model corrupted, triggering re-download..."
        # Clear the stored hash so next verification stores a fresh one
        Scribe::Settings::Manager.set("model_hash_#{model_name}", "")
        downloader = Scribe::ProcessManagers::DownloadWhisperModel.new(model_name: model_name)
        downloader.perform
      end

      # When model setting changes: update menu, download if needed, reload
      Scribe::Events::EventBus.on(Scribe::Events::SETTINGS_CHANGED) do |data|
        if data["key"]? == "whisper_model_name"
          model_name = data["value"]? || "ggml-base.en.bin"
          MenuManager.update_model_info(model_name)

          # Check if model exists, download if not
          home = ENV["HOME"]? || "/tmp"
          model_path = File.join(home, "Library/Application Support/Scribe/models", model_name)
          if File.exists?(model_path)
            # Model exists — DO NOT reload at runtime.
            # whisper.cpp's Metal GPU cleanup (ggml_metal_rsets_free) crashes
            # when freeing a context at arbitrary times. The new model will be
            # loaded on next app restart.
            puts "[Scribe] Model #{model_name} is available. Will load on next restart."
            LibScribePlatform.scribe_notification_send(
              "Model Changed".to_unsafe,
              "Switched to #{model_name}. Restart Scribe to activate.".to_unsafe,
              "model-changed".to_unsafe
            )
            reopen_settings unless @@settings_window.null?
          else
            # Model not found — trigger download
            puts "[Scribe] Model not found, downloading: #{model_name}"
            downloader = Scribe::ProcessManagers::DownloadWhisperModel.new(model_name: model_name)
            downloader.perform
          end
        end
      end
    end

    # Toggle recording for a specific mode (by hotkey ID).
    def self.toggle_recording_for_mode(hotkey_id : UInt32)
      mode = Scribe::ProcessManagers::RecordingModeManager.find_by_hotkey_id(hotkey_id)
      unless mode
        puts "[Scribe] Unknown mode hotkey ID: #{hotkey_id}"
        return
      end

      if cap = @@capture
        if cap.recording?
          # Stop recording (uses whatever mode was active when recording started)
          cap.stop
          IndicatorManager.update_status_recording(@@status_item, @@record_menu_item, @@recording_indicator, false)
          audio_path = cap.output_path
          puts "[Scribe] Recording stopped (#{Scribe::ProcessManagers::RecordingModeManager.active_mode.name}). Saved to: #{audio_path}"

          if audio_path && !@@whisper_ctx.null?
            @@last_audio_path = audio_path
            @@last_mic_path = cap.mic_output_path
            IndicatorManager.show(@@recording_indicator, "Transcribing...")

            LibScribePlatform.scribe_dispatch_background(
              ->{ App.do_transcribe },
              ->{ App.on_transcription_done }
            )
          end
        else
          # Start recording in this mode
          Scribe::ProcessManagers::RecordingModeManager.set_active(mode.name)

          # Check Screen Recording permission if system audio is needed
          if mode.system_audio
            if LibScribePlatform.scribe_screen_capture_check == 0
              LibScribePlatform.scribe_screen_capture_request
              if LibScribePlatform.scribe_screen_capture_check == 0
                show_error("Screen Recording permission required for system audio. Grant it in System Settings → Privacy → Screen Recording.")
                LibScribePlatform.scribe_open_system_settings(
                  "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture".to_unsafe
                )
                return
              end
            end
          end

          mode_dir = mode.resolved_output_dir(@@output_dir)
          Dir.mkdir_p(mode_dir) unless Dir.exists?(mode_dir)

          @@capture = Scribe::ProcessManagers::StartAudioCapture.new(
            output_directory: mode_dir,
            system_audio: mode.system_audio
          )
          @@capture.not_nil!.perform
          IndicatorManager.update_status_recording(@@status_item, @@record_menu_item, @@recording_indicator, true)
          puts "[Scribe] Recording started (#{mode.name})..."
        end
      end
    end

    def self.toggle_recording
      if cap = @@capture
        if cap.recording?
          cap.stop
          IndicatorManager.update_status_recording(@@status_item, @@record_menu_item, @@recording_indicator, false)
          audio_path = cap.output_path
          puts "[Scribe] Recording stopped. Saved to: #{audio_path}"

          if audio_path && !@@whisper_ctx.null?
            @@last_audio_path = audio_path
            @@last_mic_path = cap.mic_output_path
            IndicatorManager.show(@@recording_indicator, "Transcribing...")

            # Run whisper on a GCD background thread (NOT Crystal spawn -- GAP-19)
            LibScribePlatform.scribe_dispatch_background(
              ->{ App.do_transcribe },
              ->{ App.on_transcription_done }
            )
          elsif @@whisper_ctx.null?
            puts "[Scribe] No whisper model loaded -- transcription skipped"
          end
        else
          cap.perform
          IndicatorManager.update_status_recording(@@status_item, @@record_menu_item, @@recording_indicator, true)
          puts "[Scribe] Recording started..."
        end
      end
    end

    # Runs on GCD background thread -- do the heavy whisper work here
    def self.do_transcribe
      @@last_transcript = nil
      @@last_meeting_transcript = nil
      @@last_transcribe_error = nil

      begin
        active = Scribe::ProcessManagers::RecordingModeManager.active_mode
        if active.system_audio && (mic_path = @@last_mic_path)
          @@last_transcript = WhisperBridge.transcribe(@@whisper_ctx, mic_path)
          if system_path = @@last_audio_path
            @@last_meeting_transcript = WhisperBridge.transcribe(@@whisper_ctx, system_path)
          end
        else
          audio_path = @@last_audio_path
          return unless audio_path
          @@last_transcript = WhisperBridge.transcribe(@@whisper_ctx, audio_path)
        end
      rescue ex
        @@last_transcribe_error = ex.message || "Unknown transcription error"
        STDERR.puts "[Scribe] Transcription error: #{@@last_transcribe_error}"
      end
    end

    # Runs on main thread after whisper completes
    def self.on_transcription_done
      is_file = @@file_transcription_in_progress
      @@file_transcription_in_progress = false

      # Check for errors first
      if error = @@last_transcribe_error
        show_error("Transcription failed: #{error}")
        return
      end

      transcript = @@last_transcript

      if transcript && !transcript.blank?
        # Save transcript file
        if audio_path = @@last_audio_path
          save_transcript(transcript, audio_path)
        end

        if is_file
          # File transcription: copy to clipboard, send notification, DON'T touch indicator
          LibScribePlatform.scribe_clipboard_write(transcript.to_unsafe)
          LibScribePlatform.scribe_notification_send(
            "Transcription Complete".to_unsafe,
            "Copied to clipboard. #{transcript.size} characters.".to_unsafe,
            "transcription-done".to_unsafe
          )
          puts "[Scribe] File transcription complete — copied to clipboard"
        elsif Scribe::ProcessManagers::RecordingModeManager.active_mode.system_audio && @@last_mic_path
          # System audio mode: save full meeting transcript, run post-processing
          if meeting_transcript = @@last_meeting_transcript
            save_meeting_transcript(meeting_transcript)
          end
          IndicatorManager.update_text(@@recording_indicator, "#{Scribe::ProcessManagers::RecordingModeManager.active_mode.name} saved!")
          IndicatorManager.hide(@@recording_indicator)
          run_post_processing
        else
          # Dictation/standard mode: paste or just save based on auto_paste setting
          active = Scribe::ProcessManagers::RecordingModeManager.active_mode
          if active.auto_paste
            IndicatorManager.update_text(@@recording_indicator, "Pasting...")
            LibScribePlatform.scribe_clipboard_paste_cycle(transcript.to_unsafe)
          else
            # Save only — copy to clipboard but don't auto-paste
            LibScribePlatform.scribe_clipboard_write(transcript.to_unsafe)
            IndicatorManager.update_text(@@recording_indicator, "Saved & copied to clipboard")
            IndicatorManager.hide(@@recording_indicator)
          end
          # Run post-processing if configured on this mode
          if !active.post_process.empty?
            run_post_processing
          end
        end

        # Refresh recent transcripts menu
        MenuManager.refresh_transcripts(@@output_dir)
      elsif transcript && transcript.blank?
        show_error("No speech detected in the audio")
      else
        show_error("Transcription failed")
      end
    end

    private def self.save_transcript(text : String, audio_path : String)
      timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
      # Use the input audio filename as base for the transcript name
      audio_base = File.basename(audio_path, File.extname(audio_path))
      filename = if audio_base.starts_with?("scribe_") || audio_base.starts_with?("converted_")
                   "scribe_#{timestamp}.md"
                 else
                   "#{audio_base}_#{timestamp}.md"
                 end
      path = File.join(@@output_dir, filename)

      content = String.build do |io|
        io << "---\n"
        io << "date: #{Time.local.to_s("%Y-%m-%d %H:%M:%S")}\n"
        io << "audio: #{File.basename(audio_path)}\n"
        io << "---\n\n"
        io << text
        io << "\n"
      end

      File.write(path, content)
      puts "[Scribe] Saved transcript: #{path}"
    rescue ex
      STDERR.puts "[Scribe] Failed to save transcript: #{ex.message}"
    end

    private def self.save_meeting_transcript(text : String)
      timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
      filename = "meeting_#{timestamp}.md"
      transcript_dir = Scribe::Settings::Manager.transcript_save_dir

      content = String.build do |io|
        io << "---\n"
        io << "type: meeting\n"
        io << "date: #{Time.local.to_s("%Y-%m-%d %H:%M:%S")}\n"
        io << "---\n\n"
        io << text
        io << "\n"
      end

      Dir.mkdir_p(transcript_dir) unless Dir.exists?(transcript_dir)
      path = File.join(transcript_dir, filename)
      File.write(path, content)
      puts "[Scribe] Saved meeting transcript: #{path}"
    rescue ex
      STDERR.puts "[Scribe] Failed to save meeting transcript: #{ex.message}"
    end

    private def self.run_post_processing
      active = Scribe::ProcessManagers::RecordingModeManager.active_mode
      # Use mode's post_process command, fall back to global setting
      command = active.post_process.empty? ? Scribe::Settings::Manager.post_process_command : active.post_process
      return if command.empty?

      mode_dir = active.resolved_output_dir(@@output_dir)
      transcript_dir = Scribe::Settings::Manager.transcript_save_dir

      # Find the most recent transcript
      transcript_files = Dir.glob(File.join(transcript_dir, "*.md")).sort_by { |f|
        File.info(f).modification_time rescue Time.utc
      }.reverse
      transcript_path = transcript_files.first?
      return unless transcript_path

      puts "[Scribe] Running post-processing (#{active.name}): #{command} #{transcript_path}"

      # Store in class vars — C callbacks can't capture local vars (GAP-19)
      @@pp_command = command
      @@pp_transcript_path = transcript_path
      @@pp_transcript_dir = mode_dir

      LibScribePlatform.scribe_dispatch_background(
        ->{ App.do_post_processing },
        ->{ App.on_post_processing_done }
      )
    end

    # Runs on GCD background thread — executes the post-processing command and logs output
    def self.do_post_processing
      @@pp_output = ""
      @@pp_exit_code = 0
      begin
        output = IO::Memory.new
        error = IO::Memory.new
        start_time = Time.utc
        status = Process.run(
          @@pp_command,
          args: [@@pp_transcript_path],
          output: output,
          error: error,
          shell: true,
          chdir: @@pp_transcript_dir
        )
        duration = (Time.utc - start_time).total_seconds
        @@pp_exit_code = status.exit_code

        # Write log file
        log_dir = File.join(Scribe::Settings::Manager.app_support_dir, "logs")
        Dir.mkdir_p(log_dir) unless Dir.exists?(log_dir)
        log_path = File.join(log_dir, "post_process_#{Time.local.to_s("%Y%m%d_%H%M%S")}.log")
        File.write(log_path, String.build { |io|
          io << "Command: #{@@pp_command} #{@@pp_transcript_path}\n"
          io << "Working Dir: #{@@pp_transcript_dir}\n"
          io << "Exit Code: #{status.exit_code}\n"
          io << "Duration: #{duration.round(1)}s\n"
          io << "\n--- STDOUT ---\n#{output.to_s}\n"
          io << "\n--- STDERR ---\n#{error.to_s}\n"
        })

        @@pp_output = status.success? ? "completed (#{duration.round(1)}s)" : "failed (exit #{status.exit_code})"
        puts "[Scribe] Post-processing #{@@pp_output}. Log: #{log_path}"
      rescue ex
        @@pp_exit_code = -1
        @@pp_output = "error: #{ex.message}"
        STDERR.puts "[Scribe] Post-processing error: #{ex.message}"
      end
    end

    # Runs on main thread after post-processing completes
    def self.on_post_processing_done
      if @@pp_exit_code == 0
        LibScribePlatform.scribe_notification_send(
          "Post-Processing Complete".to_unsafe,
          @@pp_output.to_unsafe,
          "post-process-done".to_unsafe
        )
      else
        show_error("Post-processing #{@@pp_output}")
      end
    end

    # Called on main thread when paste cycle (paste + clipboard restore) completes
    # Show an error message via indicator + macOS notification.
    # The indicator stays visible for 3 seconds (does NOT auto-hide immediately).
    def self.show_error(message : String)
      puts "[Scribe] Error: #{message}"
      IndicatorManager.show(@@recording_indicator, message)
      LibScribePlatform.scribe_notification_send(
        "Scribe".to_unsafe,
        message.to_unsafe,
        "scribe-error".to_unsafe
      )
      # Hide after a delay — don't hide immediately or the user will never see it
      # Use a 3-second delayed hide via GCD
      LibScribePlatform.scribe_dispatch_background(
        ->{ sleep 3 },
        ->{ IndicatorManager.hide(@@recording_indicator) }
      )
    end

    def self.on_paste_cycle_complete(success : Int32)
      if success == 1
        puts "[Scribe] Paste cycle complete -- auto-pasted and clipboard restored"
        IndicatorManager.update_text(@@recording_indicator, "Done!")
      else
        puts "[Scribe] Auto-paste not available -- transcript copied to clipboard"
        puts "[Scribe] Press Cmd+V to paste. Check terminal for Accessibility status."
        IndicatorManager.update_text(@@recording_indicator, "Copied! Cmd+V to paste")
      end
      IndicatorManager.hide(@@recording_indicator)

      # Refresh the recent transcripts menu after each recording
      MenuManager.refresh_transcripts(@@output_dir)
    end

    # Copy a recent transcript's content to clipboard by index.
    def self.copy_transcript(index : UInt32)
      idx = index.to_i32
      path = MenuManager.transcript_path(idx)
      unless path
        puts "[Scribe] No transcript at index #{idx}"
        return
      end

      begin
        content = File.read(path)
        # Strip YAML frontmatter if present
        if content.starts_with?("---\n")
          end_marker = content.index("---\n", 4)
          if end_marker
            content = content[(end_marker + 4)..]
          end
        end
        content = content.strip

        LibScribePlatform.scribe_clipboard_write(content.to_unsafe)
        IndicatorManager.show(@@recording_indicator, "Copied to clipboard!")
        IndicatorManager.hide(@@recording_indicator)
        puts "[Scribe] Copied transcript: #{File.basename(path)}"
      rescue ex
        STDERR.puts "[Scribe] Failed to copy transcript: #{ex.message}"
      end
    end

    # Open a file picker and transcribe the selected audio file.
    # Supports WAV natively. M4A/MP3/AIFF/CAF/FLAC are converted to WAV via afconvert.
    def self.transcribe_file
      path_ptr = LibScribePlatform.scribe_choose_file("Select Audio File to Transcribe".to_unsafe)
      return if path_ptr.null?

      path = String.new(path_ptr)
      LibScribePlatform.scribe_free_string(path_ptr)

      unless File.exists?(path)
        show_error("File not found: #{File.basename(path)}")
        return
      end

      if File.size(path) < 10
        show_error("File is too small to be a valid audio file")
        return
      end

      if @@whisper_ctx.null?
        show_error("No whisper model loaded — cannot transcribe")
        return
      end

      # Check if the file is already WAV or needs conversion
      is_wav = false
      begin
        File.open(path, "rb") do |f|
          magic = Bytes.new(4)
          f.read(magic)
          is_wav = String.new(magic) == "RIFF"
        end
      rescue
      end

      wav_path = path
      unless is_wav
        # Convert to WAV using macOS afconvert (supports M4A, MP3, AIFF, CAF, FLAC)
        ext = File.extname(path).downcase.lstrip('.')
        puts "[Scribe] Converting #{ext.upcase} to WAV via afconvert..."

        # Send notification — do NOT use the recording indicator (might be recording)
        LibScribePlatform.scribe_notification_send(
          "Scribe".to_unsafe,
          "Converting #{File.basename(path)} to WAV...".to_unsafe,
          "converting".to_unsafe
        )

        wav_path = File.join(@@output_dir, "converted_#{File.basename(path, File.extname(path))}.wav")
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run(
          "/usr/bin/afconvert",
          args: [path, wav_path, "-f", "WAVE", "-d", "LEI16"],
          output: output,
          error: error
        )

        unless status.success?
          show_error("Could not convert #{ext.upcase}: #{error.to_s.lines.first? || "unknown error"}")
          return
        end

        puts "[Scribe] Converted to: #{wav_path}"
      end

      # Store state for transcription — do NOT touch the recording indicator
      @@last_audio_path = wav_path
      @@last_mic_path = nil
      @@file_transcription_in_progress = true
      puts "[Scribe] Transcribing: #{File.basename(wav_path)}"

      LibScribePlatform.scribe_notification_send(
        "Scribe".to_unsafe,
        "Transcribing #{File.basename(path)}...".to_unsafe,
        "transcribing".to_unsafe
      )

      LibScribePlatform.scribe_dispatch_background(
        ->{ App.do_transcribe },
        ->{ App.on_transcription_done }
      )
    end

    # Open the About Scribe window
    def self.open_about
      puts "[Scribe] Opening About..."
      LibScribePlatform.scribe_set_activation_policy_regular(@@app)

      window = LibScribePlatform.scribe_create_window(0.0, 0.0, 340.0, 380.0, 3_u64)
      LibScribePlatform.scribe_set_window_title(window, "About Scribe".to_unsafe)

      view = Scribe::UI::AboutView.build
      renderer = ::UI::AppKit::Renderer.new
      native_view = renderer.render(view)

      about_ptr = native_view.handle.ptr!
      LibScribePlatform.scribe_stackview_set_edge_insets(about_ptr, 24.0, 24.0, 24.0, 24.0)
      LibScribePlatform.scribe_set_content_view(window, about_ptr)
      LibScribePlatform.scribe_center_window(window)
      LibScribePlatform.scribe_make_key_and_order_front(window)
      LibScribePlatform.scribe_activate_app(@@app)

      # Store references to prevent GC
      @@about_window = window
      @@about_native_view = native_view
    end

    # Open the settings/preferences window
    def self.open_settings
      puts "[Scribe] Opening settings..."

      # If settings window already exists, just bring it to front
      unless @@settings_window.null?
        LibScribePlatform.scribe_set_activation_policy_regular(@@app)
        LibScribePlatform.scribe_make_key_and_order_front(@@settings_window)
        LibScribePlatform.scribe_activate_app(@@app)
        return
      end

      begin
        LibScribePlatform.scribe_set_activation_policy_regular(@@app)

        # NSWindowStyleMask: titled(1) | closable(2) | miniaturizable(4) = 7
        @@settings_window = LibScribePlatform.scribe_create_window(0.0, 0.0, 480.0, 520.0, 7_u64)
        LibScribePlatform.scribe_set_window_title(@@settings_window, "Scribe Preferences".to_unsafe)

        @@settings_view = Scribe::UI::SettingsView.build
        @@settings_renderer = ::UI::AppKit::Renderer.new
        @@settings_native_view = @@settings_renderer.not_nil!.render(@@settings_view.not_nil!)

        settings_ptr = @@settings_native_view.not_nil!.handle.ptr!
        LibScribePlatform.scribe_stackview_set_edge_insets(settings_ptr, 20.0, 20.0, 20.0, 20.0)
        LibScribePlatform.scribe_set_content_view(@@settings_window, settings_ptr)
        LibScribePlatform.scribe_center_window(@@settings_window)
        LibScribePlatform.scribe_make_key_and_order_front(@@settings_window)

        # Activate AFTER window is created and ordered front
        LibScribePlatform.scribe_activate_app(@@app)

        # DO NOT set back to accessory — macOS will close the window.
        # The dock icon shows while settings is open (standard macOS behavior).
      rescue ex
        STDERR.puts "[Scribe] Settings window error: #{ex.message}"
        STDERR.puts ex.backtrace.join("\n") if ex.backtrace?
      end
    end

    # Refresh settings window content without closing/reopening the window.
    # Rebuilds the view tree and replaces the content view in-place.
    def self.reopen_settings
      unless @@settings_window.null?
        # Rebuild view and replace content — no window close/reopen = no flicker
        @@settings_view = Scribe::UI::SettingsView.build
        @@settings_renderer = ::UI::AppKit::Renderer.new
        @@settings_native_view = @@settings_renderer.not_nil!.render(@@settings_view.not_nil!)
        settings_ptr = @@settings_native_view.not_nil!.handle.ptr!
        LibScribePlatform.scribe_stackview_set_edge_insets(settings_ptr, 20.0, 20.0, 20.0, 20.0)
        LibScribePlatform.scribe_set_content_view(@@settings_window, settings_ptr)
      else
        open_settings
      end
    end

    # Show the setup wizard — creates window on first call
    def self.show_wizard(step : Int32)
      @@wizard_step = step
      puts "[Scribe] Showing wizard step #{step}"

      # Switch to regular activation policy so we can show windows
      LibScribePlatform.scribe_set_activation_policy_regular(@@app)

      # Create wizard window on first call only
      if @@wizard_window.null?
        # titled(1) + closable(2) = 3
        @@wizard_window = LibScribePlatform.scribe_create_window(0.0, 0.0, 520.0, 440.0, 3_u64)
        LibScribePlatform.scribe_set_window_title(@@wizard_window, "Welcome to Scribe".to_unsafe)
        # Use floating window level so the wizard appears above all other windows
        # regardless of app activation state. This is the same approach the
        # recording indicator uses (NSStatusWindowLevel) but at a lower level.
        LibScribePlatform.scribe_set_window_level(@@wizard_window, 3) # NSFloatingWindowLevel = 3
        LibScribePlatform.scribe_center_window(@@wizard_window)
      end

      # Build and render the step view
      view = Scribe::UI::SetupWizardView.build(step)
      renderer = ::UI::AppKit::Renderer.new
      @@wizard_native_view = renderer.render(view)

      # Apply padding via NSStackView edgeInsets
      native_ptr = @@wizard_native_view.not_nil!.handle.ptr!
      LibScribePlatform.scribe_stackview_set_edge_insets(native_ptr, 32.0, 40.0, 32.0, 40.0)

      # Set content and bring to front
      LibScribePlatform.scribe_set_content_view(@@wizard_window, native_ptr)
      LibScribePlatform.scribe_make_key_and_order_front(@@wizard_window)

      # Schedule async activation — fires after the NSApp run loop has started.
      # This is critical: activation before the run loop has no effect.
      LibScribePlatform.scribe_bring_window_to_front_async(@@wizard_window)
    end

    # Update wizard to a specific step (replaces content, keeps window)
    def self.wizard_update_step(step : Int32)
      show_wizard(step)
    end

    # Advance to the next wizard step
    def self.wizard_next_step
      show_wizard(@@wizard_step + 1)
    end

    # Finish the wizard and return to menu bar mode
    def self.wizard_finish
      unless @@wizard_window.null?
        LibScribePlatform.scribe_close_window(@@wizard_window)
        @@wizard_window = Pointer(Void).null
      end
      @@wizard_native_view = nil
      LibScribePlatform.scribe_set_activation_policy_accessory(@@app)
      puts "[Scribe] Wizard complete — running in menu bar"
    end

    # Wire up event handlers for inbox thread status updates (Epic 11.6)
    private def self.install_inbox_event_handlers
      # When CLI processing completes, update the linked inbox thread
      Scribe::Events::EventBus.on(Scribe::Events::CLI_COMPLETED) do |data|
        job_id_str = data["job_id"]?
        result_text = data["result"]?
        duration = data["duration_seconds"]?

        if job_id_str
          job_id = job_id_str.to_i64 rescue 0_i64
          next if job_id == 0

          # Find the message linked to this processing job
          messages = Scribe::Models::InboxMessage.all
          linked_message = messages.find { |m| m.processing_job_id == job_id }

          if linked_message
            thread_id = linked_message.thread_id
            threads = Scribe::Models::InboxThread.all
            thread = threads.find { |t| (t.id || 0_i64) == thread_id }

            if thread && result_text
              # Create assistant message
              now = Time.utc
              assistant_msg = Scribe::Models::InboxMessage.new
              assistant_msg.thread_id = thread_id
              assistant_msg.message_uuid = UUID.random.to_s
              assistant_msg.role = "assistant"
              assistant_msg.content = result_text
              assistant_msg.processing_job_id = job_id
              assistant_msg.created_at = now
              assistant_msg.save rescue nil

              # Append to thread file
              Scribe::Services::ThreadFileService.append_message(thread.file_path, assistant_msg)

              # Update thread status
              thread.current_status = "completed"
              thread.unread = 1
              thread.updated_at = now
              thread.save rescue nil

              # Emit thread response ready
              Scribe::Events::EventBus.emit(
                Scribe::Events::THREAD_RESPONSE_READY,
                Scribe::Events::EventData.new(
                  thread_uuid: thread.thread_uuid,
                  duration_seconds: duration || "0"
                )
              )

              puts "[Scribe] Thread #{thread.thread_uuid} completed with response"
            end
          end
        end
      end

      # When CLI processing fails, update the linked inbox thread
      Scribe::Events::EventBus.on(Scribe::Events::CLI_FAILED) do |data|
        job_id_str = data["job_id"]?

        if job_id_str
          job_id = job_id_str.to_i64 rescue 0_i64
          next if job_id == 0

          messages = Scribe::Models::InboxMessage.all
          linked_message = messages.find { |m| m.processing_job_id == job_id }

          if linked_message
            thread_id = linked_message.thread_id
            threads = Scribe::Models::InboxThread.all
            thread = threads.find { |t| (t.id || 0_i64) == thread_id }

            if thread
              thread.current_status = "failed"
              thread.updated_at = Time.utc
              thread.save rescue nil

              Scribe::Events::EventBus.emit(
                Scribe::Events::THREAD_UPDATED,
                Scribe::Events::EventData.new(
                  thread_uuid: thread.thread_uuid,
                  status: "failed"
                )
              )

              STDERR.puts "[Scribe] Thread #{thread.thread_uuid} processing failed"
            end
          end
        end
      end
    end

    # Wire up notification delivery for agent responses and failures (Epic 13.1)
    private def self.install_notification_event_handlers
      # Notify when agent response is ready
      Scribe::Events::EventBus.on(Scribe::Events::THREAD_RESPONSE_READY) do |data|
        thread_uuid = data["thread_uuid"]?
        next unless thread_uuid

        # Look up thread to get title
        threads = Scribe::Models::InboxThread.all
        thread = threads.find { |t| t.thread_uuid == thread_uuid }
        next unless thread

        # Get latest assistant message for notification body
        messages = Scribe::Models::InboxMessage.all
        assistant_msg = messages.select { |m| m.thread_id == (thread.id || 0_i64) && m.role == "assistant" }.last?

        body = if assistant_msg
                 content = assistant_msg.content
                 content.size > 100 ? content[0, 100] + "..." : content
               else
                 "Response ready"
               end

        pm = Scribe::Notifications::DeliverNotification.new(
          title: thread.title,
          body: body,
          identifier: thread_uuid
        )
        pm.perform

        # Update badge count
        BadgeManager.update_badge(@@status_item)

        # Write completion marker for iOS detection (Epic 13.5)
        Scribe::Services::ThreadFileService.write_completion_marker(thread.file_path, Time.utc)
      end

      # Notify when CLI processing fails (if thread_uuid available)
      Scribe::Events::EventBus.on(Scribe::Events::CLI_FAILED) do |data|
        thread_uuid = data["thread_uuid"]?
        error_msg = data["error"]? || "Processing failed"

        if thread_uuid
          threads = Scribe::Models::InboxThread.all
          thread = threads.find { |t| t.thread_uuid == thread_uuid }
          title = thread ? thread.title : "Scribe"
        else
          title = "Scribe"
        end

        pm = Scribe::Notifications::DeliverNotification.new(
          title: "Processing Failed",
          body: "#{title}: #{error_msg}",
          identifier: thread_uuid || "cli-failed-#{Time.utc.to_unix}"
        )
        pm.perform
      end

      # Update badge when a thread is read (Epic 13.2)
      Scribe::Events::EventBus.on(Scribe::Events::THREAD_READ) do |data|
        BadgeManager.update_badge(@@status_item)
      end
    end

    # Sync settings changes to runtime state (output_dir, etc.)
    private def self.install_settings_sync_handlers
      Scribe::Events::EventBus.on(Scribe::Events::SETTINGS_CHANGED) do |data|
        key = data["key"]?
        case key
        when "output_dir"
          new_dir = Scribe::Settings::Manager.output_dir
          Dir.mkdir_p(new_dir) unless Dir.exists?(new_dir)
          @@output_dir = new_dir
          @@capture = Scribe::ProcessManagers::StartAudioCapture.new(output_directory: @@output_dir)
          MenuManager.update_output_dir(Scribe::Settings::Manager.display_path(@@output_dir))
          puts "[Scribe] Output directory updated to: #{@@output_dir}"
        end
      end
    end

    # Start iCloud file watcher and wire up re-index on file changes (Epic 12)
    private def self.install_icloud_sync_handlers
      unless Scribe::Settings::Manager.icloud_sync_enabled?
        puts "[Scribe] iCloud sync disabled -- skipping file watcher"
        return
      end

      # Run initial re-index to pick up any changes synced while app was closed
      inbox_path = Scribe::Settings::Manager.inbox_storage_path
      reindexer = Scribe::Sync::ReIndexThreadFiles.new(inbox_path: inbox_path)
      reindexer.perform
      puts "[Scribe] Initial re-index: #{reindexer.files_scanned} files, #{reindexer.threads_created} new, #{reindexer.threads_updated} updated, #{reindexer.threads_removed} removed"

      # Start watching the iCloud base directory for file changes
      icloud_base = Scribe::Settings::Manager.icloud_base_path
      FileWatcher.start(icloud_base)

      # When a file changes, trigger re-index
      Scribe::Events::EventBus.on(Scribe::Events::ICLOUD_FILE_CHANGED) do |data|
        change_type = data["change_type"]? || "unknown"
        path = data["path"]? || ""
        puts "[Scribe] iCloud file #{change_type}: #{path}"

        # Re-index to sync DB with file system
        reindex = Scribe::Sync::ReIndexThreadFiles.new(inbox_path: inbox_path)
        reindex.perform
      end
    end
  end
end

{% end %}

# Export the callback dispatch function for CrystalActionDispatcher ObjC class.
# Must be at global scope — Crystal `fun` exports can't be inside modules.
# Called from ObjC when a button is clicked — routes to CallbackRegistry.
{% if flag?(:macos) %}
fun crystal_ui_callback_dispatch(callback_id : UInt64) : Void
  ::UI::CallbackRegistry.call(callback_id)
end
{% end %}
