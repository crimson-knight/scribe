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
    fun scribe_terminate_app(app : Void*) : Void

    # Window
    fun scribe_create_window(x : Float64, y : Float64, w : Float64, h : Float64,
                             style_mask : UInt64) : Void*
    fun scribe_set_window_title(window : Void*, title : UInt8*) : Void
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

    # GCD async dispatch (avoids blocked Crystal fiber scheduler — GAP-19)
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

    # Whisper transcription (C wrapper — avoids FullParams struct mismatch, GAP-21)
    fun scribe_whisper_init(model_path : UInt8*) : Void*
    fun scribe_whisper_free(ctx : Void*) : Void
    fun scribe_whisper_transcribe(ctx : Void*, samples : Float32*, n_samples : Int32,
                                   language : UInt8*, n_threads : Int32) : UInt8*
    fun scribe_whisper_free_result(text : UInt8*) : Void

    # ObjC runtime (for selector lookup)
    fun sel_registerName(name : UInt8*) : Void*
  end

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

  module App
    # Keep references alive for the event loop
    @@app : Void* = Pointer(Void).null
    @@status_item : Void* = Pointer(Void).null
    @@record_menu_item : Void* = Pointer(Void).null
    @@capture : Scribe::ProcessManagers::StartAudioCapture? = nil
    @@recording_indicator : Void* = Pointer(Void).null
    @@output_dir : String = ""
    @@whisper_ctx : Void* = Pointer(Void).null

    def self.run
      @@output_dir = ENV["SCRIBE_OUTPUT_DIR"]? || File.join(ENV["HOME"]? || "/tmp", "Scribe")

      # Ensure output directory exists
      Dir.mkdir_p(@@output_dir) unless Dir.exists?(@@output_dir)

      @@capture = Scribe::ProcessManagers::StartAudioCapture.new(output_directory: @@output_dir)

      # Load whisper model via C wrapper (avoids struct layout mismatch — GAP-21)
      model_path = find_whisper_model
      if model_path
        puts "[Scribe] Loading whisper model: #{model_path}"
        @@whisper_ctx = LibScribePlatform.scribe_whisper_init(model_path.to_unsafe)
        if @@whisper_ctx.null?
          STDERR.puts "[Scribe] Failed to load whisper model"
          @@whisper_ctx = Pointer(Void).null
        else
          puts "[Scribe] Whisper model loaded successfully"
        end
      else
        STDERR.puts "[Scribe] Warning: No whisper model found — transcription disabled"
        STDERR.puts "[Scribe] Place ggml-base.en.bin in ~/Library/Application Support/Scribe/models/"
      end

      # Install paste cycle callback — fires after clipboard restore completes
      LibScribePlatform.scribe_install_paste_cycle_callback(->(success : Int32) {
        App.on_paste_cycle_complete(success)
      })

      # Create NSApplication as accessory (menu bar only, no dock icon)
      @@app = LibScribePlatform.scribe_shared_application
      LibScribePlatform.scribe_set_activation_policy_accessory(@@app)

      # Create status bar item with microphone icon
      @@status_item = LibScribePlatform.scribe_create_status_item
      LibScribePlatform.scribe_set_status_item_image(@@status_item, "mic".to_unsafe)
      LibScribePlatform.scribe_set_status_item_title(@@status_item, "Scribe".to_unsafe)

      # Build the menu
      menu = LibScribePlatform.scribe_create_menu("Scribe".to_unsafe)

      # Install menu item callback handler
      LibScribePlatform.scribe_install_menu_callback(->(item_tag : UInt32) {
        case item_tag
        when MENU_TAG_TOGGLE_RECORDING
          App.toggle_recording
        end
      })
      menu_target = LibScribePlatform.scribe_get_menu_target
      menu_clicked_sel = LibScribePlatform.sel_registerName("menuItemClicked:".to_unsafe)

      # Record toggle menu item — wired to callback target
      @@record_menu_item = LibScribePlatform.scribe_add_menu_item(menu, "Start Recording".to_unsafe, "".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_tag(@@record_menu_item, MENU_TAG_TOGGLE_RECORDING)
      LibScribePlatform.scribe_set_menu_item_action(@@record_menu_item, menu_clicked_sel)
      LibScribePlatform.scribe_set_menu_item_target(@@record_menu_item, menu_target)

      LibScribePlatform.scribe_add_menu_separator(menu)

      # Output directory info
      dir_item = LibScribePlatform.scribe_add_menu_item(menu, "Output: #{@@output_dir}".to_unsafe, "".to_unsafe)

      LibScribePlatform.scribe_add_menu_separator(menu)

      # Quit item — use terminate: action on NSApp
      quit_item = LibScribePlatform.scribe_add_menu_item(menu, "Quit Scribe".to_unsafe, "q".to_unsafe)
      terminate_sel = LibScribePlatform.sel_registerName("terminate:".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_action(quit_item, terminate_sel)
      LibScribePlatform.scribe_set_menu_item_target(quit_item, @@app)

      LibScribePlatform.scribe_set_status_item_menu(@@status_item, menu)

      # Create the floating recording indicator (hidden until recording starts)
      @@recording_indicator = LibScribePlatform.scribe_create_recording_indicator

      # Register global keyboard shortcut: Option+Shift+R
      register_hotkeys

      puts "Scribe is running in the menu bar."
      puts "Output directory: #{@@output_dir}"
      puts "Press Option+Shift+R to toggle recording."
      puts "Click the menu bar icon or press Cmd+Q to quit."

      # Run the event loop (blocks until app terminates)
      LibScribePlatform.scribe_activate_app(@@app)
      LibScribePlatform.scribe_run_app(@@app)
    end

    private def self.register_hotkeys
      # Install the Carbon hotkey event handler.
      # Pass the proc literal directly — Crystal converts non-closure procs
      # to C function pointers at call sites. No GC concern for bare fn ptrs.
      status = LibScribePlatform.scribe_hotkey_install_handler(->(hotkey_id : UInt32) {
        case hotkey_id
        when HOTKEY_TOGGLE_RECORDING
          App.toggle_recording
        end
      })
      if status != 0
        STDERR.puts "[Scribe] Warning: Failed to install hotkey handler (status: #{status})"
        return
      end

      # Register Option+Shift+R for toggle recording
      hotkey_ref = Pointer(Void).null
      status = LibScribePlatform.scribe_hotkey_register(
        HOTKEY_TOGGLE_RECORDING,
        OPTION_KEY | SHIFT_KEY,
        VK_R,
        pointerof(hotkey_ref)
      )

      if status == 0
        puts "[Scribe] Registered hotkey: Option+Shift+R (toggle recording)"
      else
        STDERR.puts "[Scribe] Warning: Failed to register hotkey (status: #{status})"
      end
    end

    # Track state for the async transcription flow
    @@last_audio_path : String? = nil
    @@last_transcript : String? = nil

    def self.toggle_recording
      if cap = @@capture
        if cap.recording?
          cap.stop
          update_status_recording(false)
          audio_path = cap.output_path
          puts "[Scribe] Recording stopped. Saved to: #{audio_path}"

          if audio_path && !@@whisper_ctx.null?
            @@last_audio_path = audio_path
            LibScribePlatform.scribe_update_recording_indicator_text(
              @@recording_indicator, "Transcribing...".to_unsafe
            )
            LibScribePlatform.scribe_show_recording_indicator(@@recording_indicator)

            # Run whisper on a GCD background thread (NOT Crystal spawn — GAP-19)
            LibScribePlatform.scribe_dispatch_background(
              ->{ App.do_transcribe },
              ->{ App.on_transcription_done }
            )
          elsif @@whisper_ctx.null?
            puts "[Scribe] No whisper model loaded — transcription skipped"
          end
        else
          cap.perform
          update_status_recording(true)
          puts "[Scribe] Recording started..."
        end
      end
    end

    # Runs on GCD background thread — do the heavy whisper work here
    def self.do_transcribe
      audio_path = @@last_audio_path
      return unless audio_path
      return if @@whisper_ctx.null?

      begin
        # Read WAV file and convert to float32 PCM at 16kHz mono
        samples = read_wav_as_float32(audio_path)
        unless samples
          @@last_transcript = nil
          puts "[Scribe] Failed to read WAV file"
          return
        end

        puts "[Scribe] Transcribing #{samples.size} samples (#{samples.size / 16000.0}s)..."

        # Call C wrapper — builds FullParams with correct struct layout (GAP-21)
        result_ptr = LibScribePlatform.scribe_whisper_transcribe(
          @@whisper_ctx,
          samples.to_unsafe,
          samples.size.to_i32,
          "en".to_unsafe,
          4 # n_threads
        )

        if result_ptr.null?
          @@last_transcript = nil
          puts "[Scribe] Transcription failed (whisper returned null)"
        else
          text = String.new(result_ptr).strip
          LibScribePlatform.scribe_whisper_free_result(result_ptr)
          @@last_transcript = text
          puts "[Scribe] Transcription complete: #{text.size} chars"
        end
      rescue ex
        @@last_transcript = nil
        puts "[Scribe] Transcription error: #{ex.message}"
      end
    end

    # Runs on main thread after whisper completes
    def self.on_transcription_done
      transcript = @@last_transcript

      if transcript && !transcript.blank?
        # Save transcript file
        if audio_path = @@last_audio_path
          save_transcript(transcript, audio_path)
        end

        # Clipboard paste cycle
        LibScribePlatform.scribe_update_recording_indicator_text(
          @@recording_indicator, "Pasting...".to_unsafe
        )
        LibScribePlatform.scribe_clipboard_paste_cycle(transcript.to_unsafe)
      elsif transcript && transcript.blank?
        puts "[Scribe] Transcription was empty"
        LibScribePlatform.scribe_update_recording_indicator_text(
          @@recording_indicator, "Empty transcription".to_unsafe
        )
        LibScribePlatform.scribe_hide_recording_indicator(@@recording_indicator)
      else
        LibScribePlatform.scribe_update_recording_indicator_text(
          @@recording_indicator, "Transcription failed".to_unsafe
        )
        LibScribePlatform.scribe_hide_recording_indicator(@@recording_indicator)
      end
    end

    private def self.save_transcript(text : String, audio_path : String)
      timestamp = Time.local.to_s("%Y-%m-%d_%H-%M-%S")
      filename = "scribe_#{timestamp}.md"
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

    # Called on main thread when paste cycle (paste + clipboard restore) completes
    def self.on_paste_cycle_complete(success : Int32)
      if success == 1
        puts "[Scribe] Paste cycle complete — auto-pasted and clipboard restored"
        LibScribePlatform.scribe_update_recording_indicator_text(
          @@recording_indicator, "Done!".to_unsafe
        )
      else
        puts "[Scribe] Auto-paste not available — transcript copied to clipboard"
        puts "[Scribe] Press Cmd+V to paste. Check terminal for Accessibility status."
        LibScribePlatform.scribe_update_recording_indicator_text(
          @@recording_indicator, "Copied! Cmd+V to paste".to_unsafe
        )
      end
      LibScribePlatform.scribe_hide_recording_indicator(@@recording_indicator)
    end

    # Find the whisper model file. Search order:
    # 1. Inside .app bundle: Contents/Resources/ggml-base.en.bin
    # 2. User App Support: ~/Library/Application Support/Scribe/models/ggml-base.en.bin
    private def self.find_whisper_model : String?
      # Check bundle resources (for self-contained .app distribution)
      bundle_path = File.join(
        File.dirname(File.dirname(Process.executable_path || "")),
        "Resources", "ggml-base.en.bin"
      )
      return bundle_path if File.exists?(bundle_path)

      # Check user App Support directory
      app_support_path = File.join(
        ENV["HOME"]? || "/tmp",
        "Library/Application Support/Scribe/models/ggml-base.en.bin"
      )
      return app_support_path if File.exists?(app_support_path)

      nil
    end

    # Read a WAV file and return float32 PCM samples at 16kHz mono.
    # whisper.cpp requires WHISPER_SAMPLE_RATE (16000) Hz mono float32.
    private def self.read_wav_as_float32(path : String) : Slice(Float32)?
      begin
        data = File.read(path).to_slice

        # Parse WAV header (minimal — we know our recorder outputs 16-bit PCM WAV)
        return nil if data.size < 44
        return nil unless String.new(data[0, 4]) == "RIFF"
        return nil unless String.new(data[8, 4]) == "WAVE"

        # Read format info
        channels = (data[22].to_u16 | (data[23].to_u16 << 8))
        sample_rate = (data[24].to_u32 | (data[25].to_u32 << 8) | (data[26].to_u32 << 16) | (data[27].to_u32 << 24))
        bits_per_sample = (data[34].to_u16 | (data[35].to_u16 << 8))

        puts "[Scribe] WAV: #{sample_rate}Hz, #{channels}ch, #{bits_per_sample}bit"

        # Find data chunk
        offset = 12
        data_offset = 0
        data_size = 0_u32
        while offset < data.size - 8
          chunk_id = String.new(data[offset, 4])
          chunk_size = (data[offset + 4].to_u32 | (data[offset + 5].to_u32 << 8) |
                        (data[offset + 6].to_u32 << 16) | (data[offset + 7].to_u32 << 24))
          if chunk_id == "data"
            data_offset = offset + 8
            data_size = chunk_size
            break
          end
          offset += 8 + chunk_size
        end

        return nil if data_offset == 0 || data_size == 0

        # Convert to float32
        if bits_per_sample == 16
          n_samples = data_size // 2
          samples = Slice(Float32).new(n_samples.to_i32)
          n_samples.times do |i|
            byte_offset = data_offset + i * 2
            raw = (data[byte_offset].to_i16 | (data[byte_offset + 1].to_i16 << 8))
            samples[i] = raw.to_f32 / 32768.0_f32
          end
        elsif bits_per_sample == 32
          # Assume float32 PCM
          n_samples = data_size // 4
          samples = Slice(Float32).new(n_samples.to_i32)
          n_samples.times do |i|
            byte_offset = data_offset + i * 4
            samples[i] = data[byte_offset, 4].unsafe_as(Float32)
          end
        else
          puts "[Scribe] Unsupported bit depth: #{bits_per_sample}"
          return nil
        end

        # Downmix stereo to mono if needed
        if channels == 2
          mono = Slice(Float32).new(samples.size // 2)
          (samples.size // 2).times do |i|
            mono[i] = (samples[i * 2] + samples[i * 2 + 1]) / 2.0_f32
          end
          samples = mono
        end

        # Resample to 16kHz if needed (simple linear interpolation)
        if sample_rate != 16000
          ratio = 16000.0 / sample_rate.to_f64
          new_size = (samples.size * ratio).to_i32
          resampled = Slice(Float32).new(new_size)
          new_size.times do |i|
            src_pos = i.to_f64 / ratio
            src_idx = src_pos.to_i32
            frac = (src_pos - src_idx).to_f32
            if src_idx + 1 < samples.size
              resampled[i] = samples[src_idx] * (1.0_f32 - frac) + samples[src_idx + 1] * frac
            elsif src_idx < samples.size
              resampled[i] = samples[src_idx]
            end
          end
          samples = resampled
          puts "[Scribe] Resampled #{sample_rate}Hz → 16000Hz (#{samples.size} samples)"
        end

        samples
      rescue ex
        puts "[Scribe] Failed to read WAV: #{ex.message}"
        nil
      end
    end

    private def self.update_status_recording(is_recording : Bool)
      if is_recording
        # Keep mic icon (recognizable) but use filled variant to indicate active state
        LibScribePlatform.scribe_set_status_item_image(@@status_item, "mic.fill".to_unsafe)
        LibScribePlatform.scribe_set_status_item_title(@@status_item, "REC".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_title(@@record_menu_item, "Stop Recording".to_unsafe)
        # Show the floating recording indicator
        LibScribePlatform.scribe_show_recording_indicator(@@recording_indicator)
      else
        LibScribePlatform.scribe_set_status_item_image(@@status_item, "mic".to_unsafe)
        LibScribePlatform.scribe_set_status_item_title(@@status_item, "Scribe".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_title(@@record_menu_item, "Start Recording".to_unsafe)
        # Hide the floating recording indicator
        LibScribePlatform.scribe_hide_recording_indicator(@@recording_indicator)
      end
    end
  end
end

{% end %}
