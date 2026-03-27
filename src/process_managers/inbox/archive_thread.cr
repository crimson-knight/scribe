module Scribe::Inbox
  # Process Manager: ArchiveThread
  #
  # Moves a thread's .md file to the archive subdirectory and updates
  # the thread status to "archived" in the database.
  #
  # FSDD Pattern: PERFORM process manager (Epic 11.8)
  class ArchiveThread
    getter? was_successful : Bool = false
    getter archive_path : String?
    getter error_message : String?

    def initialize(@thread : Scribe::Models::InboxThread)
    end

    def perform
      # 1. Resolve archive directory path
      inbox_path = Scribe::Settings::Manager.inbox_storage_path
      archive_dir = File.join(inbox_path, "archive")
      Dir.mkdir_p(archive_dir) unless Dir.exists?(archive_dir)

      # 2. Move thread file to archive directory
      source_path = @thread.file_path
      filename = File.basename(source_path)
      dest_path = File.join(archive_dir, filename)

      if File.exists?(source_path)
        File.rename(source_path, dest_path)
        @archive_path = dest_path
        puts "[ArchiveThread] Moved #{filename} to archive"
      else
        puts "[ArchiveThread] Source file not found: #{source_path} (may already be archived)"
        @archive_path = dest_path
      end

      # 3. Update thread status and file_path in database
      @thread.current_status = "archived"
      @thread.file_path = dest_path
      @thread.updated_at = Time.utc

      begin
        @thread.save
      rescue ex
        @error_message = "Failed to update InboxThread: #{ex.message}"
        STDERR.puts "[ArchiveThread] #{@error_message}"
        return
      end

      # 4. Emit THREAD_UPDATED event
      Scribe::Events::EventBus.emit(
        Scribe::Events::THREAD_UPDATED,
        Scribe::Events::EventData.new(
          thread_uuid: @thread.thread_uuid,
          status: "archived"
        )
      )

      @was_successful = true
      puts "[ArchiveThread] Thread #{@thread.thread_uuid} archived"
    rescue ex
      @error_message = "Unexpected error: #{ex.message}"
      STDERR.puts "[ArchiveThread] #{@error_message}"
    end
  end
end
