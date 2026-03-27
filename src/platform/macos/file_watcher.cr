{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # FileWatcher wraps macOS FSEvents to monitor a directory for file changes.
  # Used for iCloud sync: detects when files are created, modified, or deleted
  # by other devices syncing via iCloud Drive.
  #
  # Events are dispatched on the main thread (via GCD in the ObjC bridge)
  # and emitted through the Scribe EventBus.
  #
  # FSDD: Epic 12.2
  module FileWatcher
    # FSEvent flag constants (from CoreServices/FSEvents.h)
    FLAG_ITEM_CREATED  = 0x00000100_u32
    FLAG_ITEM_REMOVED  = 0x00000200_u32
    FLAG_ITEM_MODIFIED = 0x00001000_u32
    FLAG_ITEM_RENAMED  = 0x00000800_u32

    @@stream : Void* = Pointer(Void).null
    @@watching : Bool = false

    # Start watching a directory path for file-level changes.
    # Emits ICLOUD_FILE_CHANGED events via EventBus when files change.
    def self.start(path : String)
      if @@watching
        puts "[FileWatcher] Already watching -- stop first"
        return
      end

      unless Dir.exists?(path)
        puts "[FileWatcher] Directory does not exist: #{path}"
        return
      end

      @@stream = LibScribePlatform.scribe_fsevents_start(
        path.to_unsafe,
        ->(file_path : UInt8*, flags : UInt32) {
          FileWatcher.on_file_changed(file_path, flags)
        }
      )

      if @@stream.null?
        STDERR.puts "[FileWatcher] Failed to start FSEventStream"
      else
        @@watching = true
        puts "[FileWatcher] Watching: #{path}"
      end
    end

    # Stop watching for file changes.
    def self.stop
      return unless @@watching

      LibScribePlatform.scribe_fsevents_stop(@@stream)
      @@stream = Pointer(Void).null
      @@watching = false
      puts "[FileWatcher] Stopped"
    end

    # Whether the watcher is currently active.
    def self.watching? : Bool
      @@watching
    end

    # Called from the FSEvents callback (on main thread via GCD).
    # Determines the change type and emits an event.
    def self.on_file_changed(path_ptr : UInt8*, flags : UInt32)
      path = String.new(path_ptr)

      # Only care about .md files (thread files)
      return unless path.ends_with?(".md")

      change_type = determine_change_type(flags)
      puts "[FileWatcher] #{change_type}: #{path}"

      Scribe::Events::EventBus.emit(
        Scribe::Events::ICLOUD_FILE_CHANGED,
        Scribe::Events::EventData.new(
          path: path,
          change_type: change_type,
          flags: flags.to_s
        )
      )
    end

    # Map FSEvent flags to a human-readable change type string.
    private def self.determine_change_type(flags : UInt32) : String
      if flags & FLAG_ITEM_CREATED != 0
        "created"
      elsif flags & FLAG_ITEM_REMOVED != 0
        "deleted"
      elsif flags & FLAG_ITEM_RENAMED != 0
        "renamed"
      elsif flags & FLAG_ITEM_MODIFIED != 0
        "modified"
      else
        "unknown"
      end
    end
  end
end

{% end %}
