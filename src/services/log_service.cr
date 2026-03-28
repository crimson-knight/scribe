module Scribe::Services
  # Persistent file-based logging with rotation and cleanup.
  #
  # Writes to ~/Library/Application Support/Scribe/logs/scribe.log
  # On startup, rotates the previous session's log to scribe-YYYY-MM-DD.log
  # Cleans up logs older than the configured retention period (default 30 days).
  #
  # Usage:
  #   LogService.setup
  #   LogService.info("Recording started")
  #   LogService.warn("Model not found")
  #   LogService.error("Transcription failed: #{ex.message}")
  #   LogService.close
  module LogService
    @@log_file : File? = nil
    @@log_dir : String = ""

    LOG_DIR_NAME = "logs"
    LOG_FILE_NAME = "scribe.log"

    # Initialize logging: create directory, rotate old log, open new file, cleanup old logs.
    def self.setup
      @@log_dir = File.join(Scribe::Settings::Manager.app_support_dir, LOG_DIR_NAME)
      Dir.mkdir_p(@@log_dir) unless Dir.exists?(@@log_dir)

      log_path = File.join(@@log_dir, LOG_FILE_NAME)

      # Rotate previous session's log if it exists
      if File.exists?(log_path)
        begin
          mod_time = File.info(log_path).modification_time
          dated_name = "scribe-#{mod_time.to_local.to_s("%Y-%m-%d_%H%M%S")}.log"
          dated_path = File.join(@@log_dir, dated_name)
          File.rename(log_path, dated_path) unless File.exists?(dated_path)
        rescue ex
          STDERR.puts "[LogService] Failed to rotate log: #{ex.message}"
        end
      end

      # Open new log file
      begin
        @@log_file = File.open(log_path, "a")
        info("=== Scribe session started ===")
        info("Version: 1.0.0")
        info("Log directory: #{@@log_dir}")
      rescue ex
        STDERR.puts "[LogService] Failed to open log file: #{ex.message}"
      end

      # Cleanup old logs
      cleanup_old
    end

    # Write an INFO-level log entry.
    def self.info(message : String)
      write("INFO", message)
    end

    # Write a WARN-level log entry.
    def self.warn(message : String)
      write("WARN", message)
    end

    # Write an ERROR-level log entry.
    def self.error(message : String)
      write("ERROR", message)
    end

    # Flush the log file to disk.
    def self.flush
      @@log_file.try(&.flush)
    end

    # Close the log file handle.
    def self.close
      info("=== Scribe session ended ===")
      @@log_file.try(&.close)
      @@log_file = nil
    end

    # The log directory path (for display in About/Settings).
    def self.log_dir : String
      @@log_dir
    end

    # Delete log files older than the retention period.
    def self.cleanup_old
      retention_days = Scribe::Settings::Manager.get("log_retention_days").to_i32 rescue 30
      cutoff = Time.utc - retention_days.days

      Dir.glob(File.join(@@log_dir, "scribe-*.log")).each do |path|
        begin
          if File.info(path).modification_time < cutoff
            File.delete(path)
            puts "[LogService] Deleted old log: #{File.basename(path)}"
          end
        rescue
        end
      end
    end

    private def self.write(level : String, message : String)
      timestamp = Time.local.to_s("%Y-%m-%d %H:%M:%S")
      line = "[#{timestamp}] [#{level}] #{message}"

      # Write to file
      if file = @@log_file
        begin
          file.puts(line)
          file.flush
        rescue
        end
      end

      # Also write to stdout/stderr for terminal debugging
      case level
      when "ERROR"
        STDERR.puts line
      else
        puts line
      end
    end
  end
end
