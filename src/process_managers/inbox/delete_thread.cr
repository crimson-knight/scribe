module Scribe::Inbox
  # Process Manager: DeleteThread
  #
  # Permanently deletes a thread: removes the .md file from disk,
  # deletes all InboxMessage records for the thread, and deletes
  # the InboxThread record from the database.
  #
  # FSDD Pattern: PERFORM process manager (Epic 11.8)
  class DeleteThread
    getter? was_successful : Bool = false
    getter error_message : String?

    def initialize(@thread : Scribe::Models::InboxThread)
    end

    def perform
      thread_uuid = @thread.thread_uuid
      thread_id = @thread.id || 0_i64

      # 1. Delete thread file from disk
      file_path = @thread.file_path
      if File.exists?(file_path)
        File.delete(file_path)
        puts "[DeleteThread] Deleted file: #{file_path}"
      else
        puts "[DeleteThread] File not found (already deleted): #{file_path}"
      end

      # 2. Delete all InboxMessage records for this thread
      begin
        all_messages = Scribe::Models::InboxMessage.all
        thread_messages = all_messages.select { |m| m.thread_id == thread_id }
        thread_messages.each do |msg|
          msg.destroy rescue nil
        end
        puts "[DeleteThread] Deleted #{thread_messages.size} messages for thread #{thread_uuid}"
      rescue ex
        STDERR.puts "[DeleteThread] Warning: Failed to delete messages: #{ex.message}"
      end

      # 3. Delete the InboxThread record
      begin
        @thread.destroy
      rescue ex
        @error_message = "Failed to delete InboxThread: #{ex.message}"
        STDERR.puts "[DeleteThread] #{@error_message}"
        return
      end

      # 4. Emit THREAD_UPDATED event
      Scribe::Events::EventBus.emit(
        Scribe::Events::THREAD_UPDATED,
        Scribe::Events::EventData.new(
          thread_uuid: thread_uuid,
          status: "deleted"
        )
      )

      @was_successful = true
      puts "[DeleteThread] Thread #{thread_uuid} deleted"
    rescue ex
      @error_message = "Unexpected error: #{ex.message}"
      STDERR.puts "[DeleteThread] #{@error_message}"
    end
  end
end
