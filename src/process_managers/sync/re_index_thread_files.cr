require "uuid"

module Scribe::Sync
  # Process Manager: ReIndexThreadFiles
  #
  # Scans the inbox directory for .md thread files and rebuilds the SQLite
  # index (InboxThread + InboxMessage records) to match the file system.
  #
  # Called:
  #   1. On app startup (to pick up iCloud-synced changes from other devices)
  #   2. When FSEvents detects file changes in the iCloud directory
  #
  # The .md files are the source of truth. SQLite is a local cache/index.
  #
  # Handles:
  #   - New files (not in DB) => create DB records
  #   - Modified files (newer than DB) => update DB records
  #   - Deleted files (in DB but not on disk) => remove DB records
  #   - Conflicts (file and DB diverge) => append-only merge (Story 12.5)
  #
  # FSDD Pattern: PERFORM process manager (Epic 12.4)
  class ReIndexThreadFiles
    getter files_scanned : Int32 = 0
    getter threads_created : Int32 = 0
    getter threads_updated : Int32 = 0
    getter threads_removed : Int32 = 0
    getter conflicts_resolved : Int32 = 0
    getter error_message : String?

    def initialize(@inbox_path : String = Scribe::Settings::Manager.inbox_storage_path)
    end

    def perform
      unless Dir.exists?(@inbox_path)
        puts "[ReIndexThreadFiles] Inbox directory does not exist: #{@inbox_path}"
        return
      end

      # 1. Scan inbox directory for .md files
      file_uuids = scan_md_files

      # 2. Get all existing threads from DB
      db_threads = Scribe::Models::InboxThread.all

      # 3. Build lookup of DB threads by UUID for fast matching
      db_by_uuid = {} of String => Scribe::Models::InboxThread
      db_threads.each { |t| db_by_uuid[t.thread_uuid] = t }

      # 4. Process each file
      file_uuids.each do |uuid, file_path|
        @files_scanned += 1

        if existing = db_by_uuid.delete(uuid)
          # File exists in DB -- check if modified
          process_existing_file(file_path, existing)
        else
          # New file (not in DB) -- create records
          process_new_file(file_path)
        end
      end

      # 5. Handle orphaned DB records (files deleted from disk)
      db_by_uuid.each do |uuid, thread|
        remove_orphaned_thread(thread)
      end

      # 6. Emit sync complete event
      Scribe::Events::EventBus.emit(
        Scribe::Events::SYNC_COMPLETE,
        Scribe::Events::EventData.new(
          files_scanned: @files_scanned.to_s,
          threads_created: @threads_created.to_s,
          threads_updated: @threads_updated.to_s,
          threads_removed: @threads_removed.to_s,
          conflicts_resolved: @conflicts_resolved.to_s
        )
      )

      puts "[ReIndexThreadFiles] Scan complete: #{@files_scanned} files, #{@threads_created} new, #{@threads_updated} updated, #{@threads_removed} removed"
    rescue ex
      @error_message = ex.message
      STDERR.puts "[ReIndexThreadFiles] Error: #{ex.message}"
    end

    # Scan the inbox directory for .md files.
    # Returns a hash of UUID => file_path.
    private def scan_md_files : Hash(String, String)
      result = {} of String => String

      Dir.each_child(@inbox_path) do |entry|
        next unless entry.ends_with?(".md")
        next if entry.starts_with?(".")

        file_path = File.join(@inbox_path, entry)
        next unless File.file?(file_path)

        # UUID is the filename without .md extension
        uuid = entry.chomp(".md")
        result[uuid] = file_path
      end

      result
    end

    # Process a file that already has a matching DB record.
    # Checks modification time and updates if the file is newer.
    private def process_existing_file(file_path : String, thread : Scribe::Models::InboxThread)
      # Compare file modification time with DB updated_at
      file_mtime = File.info(file_path).modification_time
      db_updated = thread.updated_at

      # If file is newer than DB record, re-parse and update
      if db_updated.nil? || file_mtime > db_updated
        parsed = Scribe::Services::ThreadFileService.read_thread(file_path)
        return unless parsed

        thread_data, file_messages = parsed

        # Check for conflicts (Story 12.5)
        db_messages = Scribe::Models::InboxMessage.all.select { |m| m.thread_id == (thread.id || 0_i64) }

        if file_messages.size != db_messages.size
          # Conflict: message counts differ
          resolve_conflict(file_path, thread, thread_data, file_messages, db_messages)
        else
          # No conflict: update thread metadata from file
          update_thread_from_file(thread, thread_data)
        end

        @threads_updated += 1
      end
    end

    # Process a new .md file that has no matching DB record.
    # Creates InboxThread and InboxMessage records.
    private def process_new_file(file_path : String)
      parsed = Scribe::Services::ThreadFileService.read_thread(file_path)
      unless parsed
        STDERR.puts "[ReIndexThreadFiles] Failed to parse: #{file_path}"
        return
      end

      thread_data, messages = parsed

      # Create InboxThread record
      now = Time.utc
      thread = Scribe::Models::InboxThread.new
      thread.thread_uuid = thread_data.id.empty? ? UUID.random.to_s : thread_data.id
      thread.title = thread_data.title.empty? ? "Untitled" : thread_data.title
      thread.agent_id = thread_data.agent.empty? ? "default" : thread_data.agent
      thread.current_status = thread_data.status.empty? ? "active" : thread_data.status
      thread.unread = 0
      thread.file_path = file_path
      thread.created_at = parse_timestamp(thread_data.created) || now
      thread.updated_at = parse_timestamp(thread_data.updated) || now

      begin
        thread.save
      rescue ex
        STDERR.puts "[ReIndexThreadFiles] Failed to save thread: #{ex.message}"
        return
      end

      thread_id = thread.id || 0_i64

      # Create InboxMessage records
      messages.each do |msg_data|
        message = Scribe::Models::InboxMessage.new
        message.thread_id = thread_id
        message.message_uuid = UUID.random.to_s
        message.role = msg_data.role
        message.content = msg_data.content
        message.created_at = parse_timestamp(msg_data.timestamp) || now

        begin
          message.save
        rescue ex
          STDERR.puts "[ReIndexThreadFiles] Failed to save message: #{ex.message}"
        end
      end

      @threads_created += 1
      puts "[ReIndexThreadFiles] Created thread from file: #{thread.thread_uuid}"
    end

    # Remove a DB thread whose .md file no longer exists on disk.
    private def remove_orphaned_thread(thread : Scribe::Models::InboxThread)
      thread_id = thread.id || 0_i64

      # Delete associated messages
      messages = Scribe::Models::InboxMessage.all.select { |m| m.thread_id == thread_id }
      messages.each do |msg|
        msg.destroy rescue nil
      end

      # Delete the thread record
      thread.destroy rescue nil

      @threads_removed += 1
      puts "[ReIndexThreadFiles] Removed orphaned thread: #{thread.thread_uuid}"
    end

    # Update thread metadata from file data (file is source of truth).
    private def update_thread_from_file(thread : Scribe::Models::InboxThread, data : Scribe::Services::ThreadFileService::ThreadData)
      thread.title = data.title unless data.title.empty?
      thread.current_status = data.status unless data.status.empty?
      thread.agent_id = data.agent unless data.agent.empty?
      thread.updated_at = parse_timestamp(data.updated) || Time.utc
      thread.save rescue nil
    end

    # Conflict resolution (Story 12.5):
    # When file and DB have different message counts, merge using append-only strategy.
    # File is truth for thread metadata. Messages are merged: any message in file not
    # in DB is added to DB; any message in DB not in file is appended to file.
    private def resolve_conflict(
      file_path : String,
      thread : Scribe::Models::InboxThread,
      thread_data : Scribe::Services::ThreadFileService::ThreadData,
      file_messages : Array(Scribe::Services::ThreadFileService::MessageData),
      db_messages : Array(Scribe::Models::InboxMessage)
    )
      thread_id = thread.id || 0_i64

      # Build sets of message content for comparison
      db_contents = db_messages.map { |m| {m.role, m.content.strip} }.to_set
      file_contents = file_messages.map { |m| {m.role, m.content.strip} }.to_set

      # Messages in file but not in DB => add to DB
      file_messages.each do |msg_data|
        key = {msg_data.role, msg_data.content.strip}
        unless db_contents.includes?(key)
          message = Scribe::Models::InboxMessage.new
          message.thread_id = thread_id
          message.message_uuid = UUID.random.to_s
          message.role = msg_data.role
          message.content = msg_data.content
          message.created_at = parse_timestamp(msg_data.timestamp) || Time.utc
          message.save rescue nil
          puts "[ReIndexThreadFiles] Conflict: added file message to DB for thread #{thread.thread_uuid}"
        end
      end

      # Messages in DB but not in file => append to file
      db_only_messages = db_messages.select do |m|
        key = {m.role, m.content.strip}
        !file_contents.includes?(key)
      end

      db_only_messages.each do |msg|
        Scribe::Services::ThreadFileService.append_message(file_path, msg)
        puts "[ReIndexThreadFiles] Conflict: appended DB message to file for thread #{thread.thread_uuid}"
      end

      # Update thread metadata from file (file is truth)
      update_thread_from_file(thread, thread_data)

      @conflicts_resolved += 1

      # Emit conflict event
      Scribe::Events::EventBus.emit(
        Scribe::Events::SYNC_CONFLICT,
        Scribe::Events::EventData.new(
          thread_uuid: thread.thread_uuid,
          file_path: file_path,
          file_messages: file_messages.size.to_s,
          db_messages: db_messages.size.to_s
        )
      )
    end

    # Parse a timestamp string into a Time object.
    # Handles ISO 8601 format and HH:MM AM/PM format.
    private def parse_timestamp(str : String) : Time?
      return nil if str.empty?

      # Try ISO 8601 format first (from YAML frontmatter)
      Time.parse_utc(str, "%Y-%m-%dT%H:%M:%SZ")
    rescue
      # Try HH:MM AM/PM format (from message timestamps)
      begin
        Time.parse(str, "%I:%M %p", Time::Location::UTC)
      rescue
        nil
      end
    end
  end
end
