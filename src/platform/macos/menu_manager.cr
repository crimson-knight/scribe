{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Menu item tags for identifying callbacks
  MENU_TAG_SETTINGS         = 2_u32
  MENU_TAG_TRANSCRIBE_FILE  = 3_u32
  MENU_TAG_ABOUT            = 4_u32
  MENU_TAG_TRANSCRIPT_BASE  = 100_u32

  # Manages the NSStatusItem, menu construction, and callback wiring.
  module MenuManager
    @@model_menu_item : Void* = Pointer(Void).null
    @@dir_menu_item : Void* = Pointer(Void).null
    @@transcripts_submenu : Void* = Pointer(Void).null
    @@transcripts_parent_item : Void* = Pointer(Void).null
    @@recent_transcript_paths = [] of String
    @@menu_target : Void* = Pointer(Void).null
    @@menu_clicked_sel : Void* = Pointer(Void).null

    # Build the status bar item and dropdown menu.
    def self.setup(app : Void*, output_dir : String) : {Void*, Void*}
      status_item = LibScribePlatform.scribe_create_status_item
      LibScribePlatform.scribe_set_status_item_image(status_item, "mic".to_unsafe)
      LibScribePlatform.scribe_set_status_item_title(status_item, "Scribe".to_unsafe)

      menu = LibScribePlatform.scribe_create_menu("Scribe".to_unsafe)

      # Install menu item callback handler
      LibScribePlatform.scribe_install_menu_callback(->(item_tag : UInt32) {
        case item_tag
        when MENU_TAG_TOGGLE_RECORDING
          App.toggle_recording
        when MENU_TAG_SETTINGS
          App.open_settings
        when MENU_TAG_TRANSCRIBE_FILE
          App.transcribe_file
        when MENU_TAG_ABOUT
          App.open_about
        when MENU_TAG_TRANSCRIPT_BASE..(MENU_TAG_TRANSCRIPT_BASE + 5)
          App.copy_transcript(item_tag - MENU_TAG_TRANSCRIPT_BASE)
        end
      })
      @@menu_target = LibScribePlatform.scribe_get_menu_target
      @@menu_clicked_sel = LibScribePlatform.sel_registerName("menuItemClicked:".to_unsafe)

      # Record toggle
      record_menu_item = LibScribePlatform.scribe_add_menu_item(menu, "Start Recording".to_unsafe, "".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_tag(record_menu_item, MENU_TAG_TOGGLE_RECORDING)
      LibScribePlatform.scribe_set_menu_item_action(record_menu_item, @@menu_clicked_sel)
      LibScribePlatform.scribe_set_menu_item_target(record_menu_item, @@menu_target)

      # Preferences (Cmd+,)
      prefs_item = LibScribePlatform.scribe_add_menu_item(menu, "Preferences...".to_unsafe, ",".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_tag(prefs_item, MENU_TAG_SETTINGS)
      LibScribePlatform.scribe_set_menu_item_action(prefs_item, @@menu_clicked_sel)
      LibScribePlatform.scribe_set_menu_item_target(prefs_item, @@menu_target)

      # Transcribe Audio File...
      transcribe_item = LibScribePlatform.scribe_add_menu_item(menu, "Transcribe Audio File...".to_unsafe, "".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_tag(transcribe_item, MENU_TAG_TRANSCRIBE_FILE)
      LibScribePlatform.scribe_set_menu_item_action(transcribe_item, @@menu_clicked_sel)
      LibScribePlatform.scribe_set_menu_item_target(transcribe_item, @@menu_target)

      LibScribePlatform.scribe_add_menu_separator(menu)

      # Recent Transcripts submenu
      @@transcripts_parent_item = LibScribePlatform.scribe_add_menu_item(menu, "Recent Transcripts".to_unsafe, "".to_unsafe)
      @@transcripts_submenu = LibScribePlatform.scribe_create_menu("Recent Transcripts".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_submenu(@@transcripts_parent_item, @@transcripts_submenu)
      refresh_transcripts(output_dir)

      LibScribePlatform.scribe_add_menu_separator(menu)

      # Output directory info
      display_dir = Scribe::Settings::Manager.display_path(output_dir)
      @@dir_menu_item = LibScribePlatform.scribe_add_menu_item(menu, "Output: #{display_dir}".to_unsafe, "".to_unsafe)

      # Whisper model info
      model_name = Scribe::Settings::Manager.whisper_model_name
      model_title = ModelInfo.menu_title(model_name)
      @@model_menu_item = LibScribePlatform.scribe_add_menu_item(menu, model_title.to_unsafe, "".to_unsafe)

      LibScribePlatform.scribe_add_menu_separator(menu)

      # About Scribe
      about_item = LibScribePlatform.scribe_add_menu_item(menu, "About Scribe".to_unsafe, "".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_tag(about_item, MENU_TAG_ABOUT)
      LibScribePlatform.scribe_set_menu_item_action(about_item, @@menu_clicked_sel)
      LibScribePlatform.scribe_set_menu_item_target(about_item, @@menu_target)

      # Quit (Cmd+Q)
      quit_item = LibScribePlatform.scribe_add_menu_item(menu, "Quit Scribe".to_unsafe, "q".to_unsafe)
      terminate_sel = LibScribePlatform.sel_registerName("terminate:".to_unsafe)
      LibScribePlatform.scribe_set_menu_item_action(quit_item, terminate_sel)
      LibScribePlatform.scribe_set_menu_item_target(quit_item, app)

      LibScribePlatform.scribe_set_status_item_menu(status_item, menu)

      {status_item, record_menu_item}
    end

    # Update the output directory display in the menu.
    def self.update_output_dir(display_dir : String)
      unless @@dir_menu_item.null?
        LibScribePlatform.scribe_set_menu_item_title(@@dir_menu_item, "Output: #{display_dir}".to_unsafe)
      end
    end

    # Update the model menu item title.
    def self.update_model_info(model_name : String)
      unless @@model_menu_item.null?
        title = ModelInfo.menu_title(model_name)
        LibScribePlatform.scribe_set_menu_item_title(@@model_menu_item, title.to_unsafe)
      end
    end

    # Refresh the "Recent Transcripts" submenu from the output directory.
    def self.refresh_transcripts(output_dir : String)
      return if @@transcripts_submenu.null?

      # Clear existing items
      LibScribePlatform.scribe_remove_all_menu_items(@@transcripts_submenu)
      @@recent_transcript_paths.clear

      # Scan for recent .md transcript files
      pattern = File.join(output_dir, "*.md")
      files = Dir.glob(pattern).sort_by { |f| File.info(f).modification_time rescue Time.utc }.reverse
      recent = files.first(6)

      if recent.empty?
        empty_item = LibScribePlatform.scribe_add_menu_item(@@transcripts_submenu, "(no transcripts yet)".to_unsafe, "".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_enabled(empty_item, 0)
        return
      end

      recent.each_with_index do |path, idx|
        @@recent_transcript_paths << path
        # Show filename without extension as menu item title
        title = File.basename(path, ".md")
        tag = MENU_TAG_TRANSCRIPT_BASE + idx.to_u32
        item = LibScribePlatform.scribe_add_menu_item(@@transcripts_submenu, title.to_unsafe, "".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_tag(item, tag)
        LibScribePlatform.scribe_set_menu_item_action(item, @@menu_clicked_sel)
        LibScribePlatform.scribe_set_menu_item_target(item, @@menu_target)
      end
    end

    # Get the file path for a transcript by index (0-5).
    def self.transcript_path(index : Int32) : String?
      @@recent_transcript_paths[index]? if index >= 0 && index < @@recent_transcript_paths.size
    end
  end
end

{% end %}
