require "uuid"

module Scribe::Inbox
  # Process Manager: CreateThreadFromTranscription
  #
  # Creates a new inbox thread from a transcription result. Generates a UUID,
  # creates InboxThread + InboxMessage records, writes the thread .md file,
  # and spawns the CLI adapter for AI processing.
  #
  # FSDD Pattern: PERFORM process manager (Epic 11.2)
  class CreateThreadFromTranscription
    getter thread : Scribe::Models::InboxThread?
    getter message : Scribe::Models::InboxMessage?
    getter processing_job : Scribe::Models::ProcessingJob?
    getter? was_successful : Bool = false
    getter error_message : String?

    def initialize(
      @transcription_text : String,
      @agent_id : String = "default",
      @output_directory : String = ""
    )
    end

    def perform
      # 1. Generate thread UUID
      thread_uuid = UUID.random.to_s

      # 2. Derive title from first line of transcription (truncated to 80 chars)
      title = derive_title(@transcription_text)

      # 3. Resolve inbox storage path
      inbox_path = Scribe::Settings::Manager.inbox_storage_path
      Dir.mkdir_p(inbox_path) unless Dir.exists?(inbox_path)
      file_path = File.join(inbox_path, "#{thread_uuid}.md")

      # 4. Create InboxThread record
      now = Time.utc
      thread = Scribe::Models::InboxThread.new
      thread.thread_uuid = thread_uuid
      thread.title = title
      thread.agent_id = @agent_id
      thread.current_status = "processing"
      thread.unread = 0
      thread.file_path = file_path
      thread.created_at = now
      thread.updated_at = now

      begin
        thread.save
      rescue ex
        @error_message = "Failed to save InboxThread: #{ex.message}"
        STDERR.puts "[CreateThreadFromTranscription] #{@error_message}"
        return
      end
      @thread = thread

      # 5. Create user InboxMessage record
      message_uuid = UUID.random.to_s
      message = Scribe::Models::InboxMessage.new
      message.thread_id = thread.id || 0_i64
      message.message_uuid = message_uuid
      message.role = "user"
      message.content = @transcription_text
      message.created_at = now

      begin
        message.save
      rescue ex
        @error_message = "Failed to save InboxMessage: #{ex.message}"
        STDERR.puts "[CreateThreadFromTranscription] #{@error_message}"
        return
      end
      @message = message

      # 6. Write thread file via ThreadFileService
      Scribe::Services::ThreadFileService.write_thread(thread, [message])

      # 7. Spawn CLI adapter for processing
      output_dir = @output_directory.empty? ? Scribe::Settings::Manager.output_dir : @output_directory
      spawn_pm = Scribe::ProcessManagers::SpawnClaudeCodeCli.new(
        transcription_text: @transcription_text,
        instruction_template: @transcription_text,
        output_directory: output_dir
      )
      spawn_pm.perform

      if spawn_pm.was_spawn_successful?
        @processing_job = spawn_pm.processing_job

        # Link processing job to the message
        if job = spawn_pm.processing_job
          message.processing_job_id = job.id
          message.save rescue nil
        end
      else
        thread.current_status = "failed"
        thread.updated_at = Time.utc
        thread.save rescue nil
        @error_message = spawn_pm.error_message
        STDERR.puts "[CreateThreadFromTranscription] CLI spawn failed: #{@error_message}"
      end

      # 8. Emit THREAD_CREATED event
      Scribe::Events::EventBus.emit(
        Scribe::Events::THREAD_CREATED,
        Scribe::Events::EventData.new(
          thread_uuid: thread_uuid,
          title: title,
          agent_id: @agent_id
        )
      )

      @was_successful = true
      puts "[CreateThreadFromTranscription] Thread created: #{thread_uuid} -- #{title}"
    rescue ex
      @error_message = "Unexpected error: #{ex.message}"
      STDERR.puts "[CreateThreadFromTranscription] #{@error_message}"
    end

    # Derive a title from the first line of text, truncated to 80 characters.
    private def derive_title(text : String) : String
      first_line = text.lines.first?.try(&.strip) || "Untitled"
      first_line = first_line[0, 80] if first_line.size > 80
      first_line.empty? ? "Untitled" : first_line
    end
  end
end
