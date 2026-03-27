# Epic 8: Foundation (DB + Events + Settings)

Infrastructure foundation: SQLite persistence via Grant ORM, internal event bus, settings persistence, app.cr monolith refactor, and first-launch setup flow.

---

## Story 8.1: SQLite Database with Grant ORM

**As a System,** I want a persistent SQLite database initialized at launch with Grant ORM models for application settings and processing job tracking
→ **views:** no visible UI change; database created silently at `~/Library/Application Support/Scribe/scribe.db`

**Initiator:** System (application startup)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Database::Setup`
**View Outcome:** Database file created; tables created via Grant migrator; connection available for all models

**Process Manager:**
```
ProcessManager := Scribe::Database::Setup
  INITIALIZE(
    db_path : String = "~/Library/Application Support/Scribe/scribe.db"
  )

  PERFORM:
    ensure_app_support_directory_exists
    establish_grant_connection_to_sqlite
    run_model_migrations_via_grant_migrator
  END

  RESULTS:
    connection_established : Bool = false
    tables_created : Array(String) = [] of String
    error_message : String? = nil
  END
END
```

**Models:**

```crystal
# src/models/application_setting.cr
class Scribe::Models::ApplicationSetting < Grant::Base
  connection primary
  table application_settings

  column id : Int64, primary: true
  column key : String
  column value : String
  column created_at : Time?
  column updated_at : Time?
end

# src/models/processing_job.cr
class Scribe::Models::ProcessingJob < Grant::Base
  connection primary
  table processing_jobs

  column id : Int64, primary: true
  column job_type : String              # "transcription", "ai_processing"
  column input_path : String?
  column output_path : String?
  column current_status : String        # "pending", "running", "completed", "failed", "cancelled"
  column error_message : String?
  column started_at : Time?
  column completed_at : Time?
  column created_at : Time?
  column updated_at : Time?
end
```

**Database Connection Setup (`src/config/database.cr`):**
```crystal
require "grant"
require "../models/**"

module Scribe::Database
  def self.setup
    home = ENV["HOME"]? || "/tmp"
    app_support = File.join(home, "Library/Application Support/Scribe")
    Dir.mkdir_p(app_support) unless Dir.exists?(app_support)
    db_path = File.join(app_support, "scribe.db")

    Grant::ConnectionRegistry.establish_connection(
      database: "primary",
      adapter: Grant::Adapter::Sqlite,
      url: "sqlite3://#{db_path}"
    )

    # Create tables if they don't exist
    Scribe::Models::ApplicationSetting.migrator.create rescue nil
    Scribe::Models::ProcessingJob.migrator.create rescue nil
  end
end
```

**Acceptance Criteria:**
- SQLite database created at `~/Library/Application Support/Scribe/scribe.db`
- Grant connection established with `primary` database name
- `application_settings` table created with id, key, value, timestamps
- `processing_jobs` table created with id, job_type, paths, status, timestamps
- Connection established early in app lifecycle, before any model access
- `make macos` compiles successfully with new models
- Migrations are idempotent (safe to re-run on existing database)

---

## Story 8.2: Internal Event Bus

**As a System,** I want a synchronous pub/sub event bus for decoupled communication between components
→ **views:** no visible UI change; events flow internally between process managers, UI, and platform code

**Initiator:** System (any component emitting an event)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Events::EventBus`
**View Outcome:** Subscribers receive typed event payloads synchronously on the main thread

**Event Bus Implementation (`src/events/event_bus.cr`):**
```crystal
module Scribe::Events
  module EventBus
    alias Handler = Proc(EventData, Nil)

    @@handlers = Hash(String, Array(Handler)).new { |h, k| h[k] = [] of Handler }

    def self.on(event : String, &block : EventData -> Nil)
      @@handlers[event] << block
    end

    def self.emit(event : String, data : EventData = EventData.new)
      if handlers = @@handlers[event]?
        handlers.each { |handler| handler.call(data) }
      end
    end

    def self.clear
      @@handlers.clear
    end

    def self.clear(event : String)
      @@handlers.delete(event)
    end
  end
end
```

**Event Constants and Payload (`src/events/events.cr`):**
```crystal
module Scribe::Events
  # Event name constants
  RECORDING_STARTED   = "recording.started"
  RECORDING_STOPPED   = "recording.stopped"
  TRANSCRIPTION_STARTED  = "transcription.started"
  TRANSCRIPTION_COMPLETE = "transcription.complete"
  TRANSCRIPTION_FAILED   = "transcription.failed"
  PASTE_COMPLETE      = "paste.complete"
  PASTE_FAILED        = "paste.failed"
  SETTINGS_CHANGED    = "settings.changed"
  APP_INITIALIZED     = "app.initialized"
  DB_READY            = "db.ready"

  # Generic event payload — carries typed data via a string-keyed hash
  class EventData
    getter data : Hash(String, String)

    def initialize(@data = {} of String => String)
    end

    def initialize(**kwargs)
      @data = {} of String => String
      kwargs.each { |key, value| @data[key.to_s] = value.to_s }
    end

    def [](key : String) : String
      @data[key]
    end

    def []?(key : String) : String?
      @data[key]?
    end
  end
end
```

**Acceptance Criteria:**
- `EventBus.on("event.name") { |data| ... }` registers handlers
- `EventBus.emit("event.name", data)` dispatches to all registered handlers synchronously
- `EventBus.clear` removes all handlers; `EventBus.clear("event.name")` removes handlers for one event
- Event constants defined for recording, transcription, paste, settings, and app lifecycle
- `EventData` provides typed key-value access via `[]` and `[]?`
- Synchronous dispatch only (main thread safe, no fibers)
- `make macos` compiles successfully

---

## Story 8.3: Settings Persistence

**As a User,** I want my preferences (output directory, keyboard shortcut, whisper model path, auto-transcribe toggle) to persist between app launches
→ **views:** settings take effect immediately; persist across app restarts without re-configuration

**Initiator:** System (app startup reads settings) / User (changes a setting)
**Action Verb:** perform
**Data Model / Process:** `Scribe::Settings::Manager`
**View Outcome:** App behavior reflects persisted settings; hardcoded values in app.cr replaced with DB-backed values

**Process Manager:**
```
ProcessManager := Scribe::Settings::Manager
  INITIALIZE()

  PERFORM:
    load_all_settings_from_database
    apply_defaults_for_missing_keys
    cache_settings_in_memory
  END

  RESULTS:
    settings_loaded : Bool = false
    settings_count : Int32 = 0
  END
END
```

**Settings Manager (`src/config/settings_manager.cr`):**
```crystal
module Scribe::Settings
  module Manager
    DEFAULTS = {
      "output_dir"         => "~/Documents/Scribe",
      "shortcut_key"       => "option+shift+r",
      "whisper_model_path" => "auto",
      "auto_transcribe"    => "true",
    }

    @@cache = {} of String => String

    def self.load
      DEFAULTS.each do |key, default_value|
        existing = Scribe::Models::ApplicationSetting.where(key: key).first
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
    end

    def self.get(key : String) : String
      @@cache[key]? || DEFAULTS[key]? || ""
    end

    def self.set(key : String, value : String)
      existing = Scribe::Models::ApplicationSetting.where(key: key).first
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
      Scribe::Events::EventBus.emit(Scribe::Events::SETTINGS_CHANGED,
        Scribe::Events::EventData.new(key: key, value: value))
    end

    def self.output_dir : String
      path = get("output_dir").gsub("~", ENV["HOME"]? || "/tmp")
      path
    end

    def self.auto_transcribe? : Bool
      get("auto_transcribe") == "true"
    end

    def self.whisper_model_path : String
      get("whisper_model_path")
    end

    def self.shortcut_key : String
      get("shortcut_key")
    end
  end
end
```

**Acceptance Criteria:**
- Settings loaded from `application_settings` table on app startup
- Missing settings populated with defaults on first launch
- `Manager.get(key)` returns cached value; `Manager.set(key, value)` persists to DB and updates cache
- Convenience methods: `output_dir`, `auto_transcribe?`, `whisper_model_path`, `shortcut_key`
- `SETTINGS_CHANGED` event emitted when any setting changes
- `app.cr` reads `output_dir` from `Scribe::Settings::Manager.output_dir` instead of `ENV["SCRIBE_OUTPUT_DIR"]`
- `make macos` compiles successfully

---

## Story 8.4: Refactor app.cr Monolith

**As a Developer,** I want the 506-line app.cr monolith extracted into focused single-responsibility modules
→ **views:** no visible change; exact same runtime behavior; codebase is modular and maintainable

**Initiator:** Developer (refactoring)
**Action Verb:** perform
**Data Model / Process:** Architectural refactoring (no process manager — structural change only)
**View Outcome:** Same app behavior; app.cr reduced to ~100-150 line orchestrator

**Extraction Plan:**

| Current Location (app.cr) | New File | Content |
|---|---|---|
| Lines 145-182 (menu construction) | `src/platform/macos/menu_manager.cr` | NSStatusItem creation, menu building, callback wiring |
| Lines 184-186, 487-502 (recording indicator + status) | `src/platform/macos/indicator_manager.cr` | Floating indicator show/hide/update, status bar icon/title updates |
| Lines 200-229 (Carbon hotkey setup) | `src/platform/macos/hotkey_manager.cr` | Carbon hotkey handler installation, key registration |
| Lines 120-134, 267-305, 376-392 (whisper model + transcription) | `src/platform/macos/whisper_bridge.cr` | Model loading, `do_transcribe`, `find_whisper_model` |
| Lines 396-485 (WAV parsing + resampling) | `src/platform/macos/audio_processor.cr` | `read_wav_as_float32`, WAV header parsing, stereo downmix, resampling |

**Refactored app.cr (~100-150 lines):**
```crystal
# app.cr becomes a slim orchestrator:
# - LibScribePlatform FFI bindings (stay here — compile-time)
# - Constants (Carbon modifier flags, key codes, IDs)
# - Module App with:
#     @@class_vars for shared state
#     self.run — delegates to managers
#     self.toggle_recording — orchestrates capture/transcribe
#     self.on_transcription_done — orchestrates paste/save
#     self.on_paste_cycle_complete — finalizes
```

**Critical Constraints:**
- EXACT same runtime behavior — no functional changes
- LibScribePlatform FFI bindings stay in app.cr (compile-time)
- Constants stay in app.cr (used by multiple modules)
- Each extracted module lives under `Scribe::Platform::MacOS` namespace
- Extracted modules access shared state via method parameters, NOT class vars
- All extracted modules wrapped in `{% if flag?(:macos) %}`

**Acceptance Criteria:**
- `app.cr` reduced to ~100-150 lines (orchestrator only)
- `menu_manager.cr` handles NSStatusItem, menu construction, callback wiring
- `indicator_manager.cr` handles floating recording indicator and status bar updates
- `hotkey_manager.cr` handles Carbon hotkey handler installation and key registration
- `whisper_bridge.cr` handles whisper model loading, transcription, and model path search
- `audio_processor.cr` handles WAV file reading, format conversion, and resampling
- All extracted modules use `{% if flag?(:macos) %}` guards
- Process managers (`StartAudioCapture`, `TranscribeAndPaste`) remain unchanged
- `make macos` compiles successfully
- Running the app produces identical behavior to before refactoring

---

## Story 8.5: First-Launch Setup Flow

**As a System,** I want to automatically set up the application environment on first launch
→ **views:** no visible change on first launch; all directories created, database initialized, defaults written

**Initiator:** System (app startup, before main run loop)
**Action Verb:** perform
**Data Model / Process:** `Scribe::ProcessManagers::InitializeApplication`
**View Outcome:** App Support dirs exist, DB initialized with default settings, output dir created

**Process Manager:**
```
ProcessManager := Scribe::ProcessManagers::InitializeApplication
  INITIALIZE()

  PERFORM:
    create_app_support_directories
    initialize_database_connection
    run_model_migrations
    load_or_create_default_settings
    create_output_directory
    emit_app_initialized_event
  END

  RESULTS:
    first_launch : Bool = false
    directories_created : Array(String) = [] of String
    error_message : String? = nil
  END
END
```

**Implementation (`src/process_managers/initialize_application.cr`):**
```crystal
module Scribe::ProcessManagers
  class InitializeApplication
    getter? first_launch : Bool = false
    getter directories_created : Array(String) = [] of String
    getter error_message : String?

    def perform
      home = ENV["HOME"]? || "/tmp"

      # 1. Create App Support directories
      app_support = File.join(home, "Library/Application Support/Scribe")
      models_dir = File.join(app_support, "models")
      [app_support, models_dir].each do |dir|
        unless Dir.exists?(dir)
          Dir.mkdir_p(dir)
          @directories_created << dir
          @first_launch = true
        end
      end

      # 2. Initialize database
      Scribe::Database.setup

      # 3. Load or create default settings
      Scribe::Settings::Manager.load

      # 4. Create output directory
      output_dir = Scribe::Settings::Manager.output_dir
      unless Dir.exists?(output_dir)
        Dir.mkdir_p(output_dir)
        @directories_created << output_dir
      end

      # 5. Emit app initialized event
      Scribe::Events::EventBus.emit(Scribe::Events::APP_INITIALIZED,
        Scribe::Events::EventData.new(
          first_launch: @first_launch.to_s,
          output_dir: output_dir
        ))

      puts "[Scribe] Application initialized (first_launch=#{@first_launch})"
    rescue ex
      @error_message = ex.message
      STDERR.puts "[Scribe] Initialization error: #{ex.message}"
    end
  end
end
```

**Integration in app.cr:**
```crystal
def self.run
  # First: initialize application (DB, settings, dirs)
  init = Scribe::ProcessManagers::InitializeApplication.new
  init.perform

  # Now use settings instead of hardcoded/ENV values
  @@output_dir = Scribe::Settings::Manager.output_dir
  # ... rest of run method
end
```

**Acceptance Criteria:**
- `InitializeApplication` PM runs before any other app logic in `self.run`
- Creates `~/Library/Application Support/Scribe/` and `models/` subdirectory
- Calls `Scribe::Database.setup` to establish Grant connection and run migrations
- Calls `Scribe::Settings::Manager.load` to populate defaults
- Creates `~/Documents/Scribe/` output directory (from settings, not hardcoded)
- Emits `APP_INITIALIZED` event with `first_launch` flag
- Detects first launch vs. subsequent launch (directories already exist)
- All errors caught and logged; app still starts even if initialization partially fails
- `make macos` compiles successfully
