{% if flag?(:macos) %}

module Scribe::ProcessManagers
  # Process Manager: DownloadWhisperModel
  #
  # Downloads a whisper model from Hugging Face using NSURLSession via
  # the ObjC bridge. Reports progress via events and shows download
  # status in the recording indicator panel.
  #
  # This PM is standalone -- usable from model management, not just first-launch.
  # Download is async (uses ObjC NSURLSession delegate pattern with GCD callbacks
  # on the main thread).
  #
  # FSDD Pattern: PERFORM process manager (system-initiated on MODEL_MISSING)
  class DownloadWhisperModel
    BASE_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    getter downloaded_path : String?
    getter? success : Bool = false
    getter error_message : String?
    getter bytes_downloaded : Int64 = 0
    getter total_bytes : Int64 = 0

    def initialize(@model_name : String = "ggml-base.en.bin")
      home = ENV["HOME"]? || "/tmp"
      @destination_dir = File.join(home, "Library/Application Support/Scribe/models")
    end

    def perform
      url = "#{BASE_URL}/#{@model_name}"
      dest_path = File.join(@destination_dir, @model_name)

      # Ensure destination directory exists
      Dir.mkdir_p(@destination_dir) unless Dir.exists?(@destination_dir)

      # Capture instance vars as local vars to avoid closure over self
      model_name = @model_name
      dest = dest_path

      puts "[Scribe] Downloading model: #{model_name}"
      puts "[Scribe] URL: #{url}"
      puts "[Scribe] Destination: #{dest}"

      # Emit download started event
      Scribe::Events::EventBus.emit(
        Scribe::Events::MODEL_DOWNLOAD_STARTED,
        Scribe::Events::EventData.new(
          model_name: model_name,
          url: url
        )
      )

      # Start async download via ObjC bridge NSURLSession
      # NOTE: C callbacks cannot close over instance vars (GAP-17).
      # All referenced vars must be local (stack-captured) for C function pointers.
      Scribe::Platform::MacOS::LibScribePlatform.scribe_download_file(
        url.to_unsafe,
        dest.to_unsafe,
        ->(bytes_written : Int64, total : Int64) {
          # Progress callback -- fires on main thread
          pct = total > 0 ? (bytes_written * 100 / total) : 0
          mb_done = bytes_written / (1024 * 1024)
          mb_total = total > 0 ? total / (1024 * 1024) : 0

          puts "[Scribe] Download progress: #{pct}% (#{mb_done}/#{mb_total} MB)"

          Scribe::Events::EventBus.emit(
            Scribe::Events::MODEL_DOWNLOAD_PROGRESS,
            Scribe::Events::EventData.new(
              bytes_downloaded: bytes_written.to_s,
              total_bytes: total.to_s,
              percent: pct.to_s
            )
          )
        },
        ->(ok : Int32, err_msg : UInt8*) {
          # Completion callback -- fires on main thread
          if ok == 1
            puts "[Scribe] Download complete"
            Scribe::Events::EventBus.emit(
              Scribe::Events::MODEL_DOWNLOAD_COMPLETE,
              Scribe::Events::EventData.new
            )
          else
            error = err_msg.null? ? "Unknown download error" : String.new(err_msg)
            STDERR.puts "[Scribe] Download failed: #{error}"
            Scribe::Events::EventBus.emit(
              Scribe::Events::MODEL_DOWNLOAD_FAILED,
              Scribe::Events::EventData.new(
                error: error
              )
            )
          end
        }
      )
    end
  end
end

{% end %}
