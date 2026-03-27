module Scribe::Events
  # Event name constants
  RECORDING_STARTED      = "recording.started"
  RECORDING_STOPPED      = "recording.stopped"
  TRANSCRIPTION_STARTED  = "transcription.started"
  TRANSCRIPTION_COMPLETE = "transcription.complete"
  TRANSCRIPTION_FAILED   = "transcription.failed"
  PASTE_COMPLETE         = "paste.complete"
  PASTE_FAILED           = "paste.failed"
  SETTINGS_CHANGED       = "settings.changed"
  APP_INITIALIZED        = "app.initialized"
  DB_READY               = "db.ready"

  # Model management events (Epic 9)
  MODEL_FOUND             = "model.found"
  MODEL_MISSING           = "model.missing"
  MODEL_DOWNLOAD_STARTED  = "model.download.started"
  MODEL_DOWNLOAD_PROGRESS = "model.download.progress"
  MODEL_DOWNLOAD_COMPLETE = "model.download.complete"
  MODEL_DOWNLOAD_FAILED   = "model.download.failed"
  MODEL_VERIFIED          = "model.verified"
  MODEL_CORRUPTED         = "model.corrupted"

  # CLI processing events (Epic 10)
  CLI_SPAWNED             = "cli.spawned"
  CLI_PROGRESS            = "cli.progress"
  CLI_TOOL_USE            = "cli.tool_use"
  CLI_TOOL_RESULT         = "cli.tool_result"
  CLI_COMPLETED           = "cli.completed"
  CLI_FAILED              = "cli.failed"
  CLI_CANCELLED           = "cli.cancelled"

  # Inbox events (Epic 11)
  THREAD_CREATED        = "inbox.thread.created"
  THREAD_UPDATED        = "inbox.thread.updated"
  THREAD_RESPONSE_READY = "inbox.thread.response_ready"
  THREAD_READ           = "inbox.thread.read"

  # iCloud sync events (Epic 12)
  ICLOUD_FILE_CHANGED = "icloud.file.changed"
  SYNC_COMPLETE       = "sync.complete"
  SYNC_CONFLICT       = "sync.conflict"

  # Queue events (Epic 13)
  QUEUE_ITEM_ADDED = "queue.item.added"
  QUEUE_PROCESSING = "queue.processing"
  QUEUE_IDLE       = "queue.idle"

  # Generic event payload -- carries typed data via a string-keyed hash
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
