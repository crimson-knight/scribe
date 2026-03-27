require "uuid"

module Scribe::Inbox
  # Process Manager: SendFollowUpMessage
  #
  # Appends a follow-up message to an existing inbox thread, rebuilds
  # the full conversation context, and dispatches to the CLI adapter
  # for processing.
  #
  # FSDD Pattern: PERFORM process manager (Epic 11.5)
  class SendFollowUpMessage
    getter message : Scribe::Models::InboxMessage?
    getter processing_job : Scribe::Models::ProcessingJob?
    getter? was_successful : Bool = false
    getter error_message : String?

    def initialize(
      @thread : Scribe::Models::InboxThread,
      @message_text : String,
      @output_directory : String = ""
    )
    end

    def perform
      thread_id = @thread.id || 0_i64

      # 1. Create user InboxMessage record
      now = Time.utc
      message = Scribe::Models::InboxMessage.new
      message.thread_id = thread_id
      message.message_uuid = UUID.random.to_s
      message.role = "user"
      message.content = @message_text
      message.created_at = now

      begin
        message.save
      rescue ex
        @error_message = "Failed to save InboxMessage: #{ex.message}"
        STDERR.puts "[SendFollowUpMessage] #{@error_message}"
        return
      end
      @message = message

      # 2. Append message to thread file
      Scribe::Services::ThreadFileService.append_message(@thread.file_path, message)

      # 3. Build full context prompt from all messages in the thread
      prompt = build_full_context_prompt(thread_id, @message_text)

      # 4. Update thread status to processing
      @thread.current_status = "processing"
      @thread.updated_at = now
      @thread.save rescue nil

      # 5. Spawn CLI adapter with full context
      output_dir = @output_directory.empty? ? Scribe::Settings::Manager.output_dir : @output_directory
      spawn_pm = Scribe::ProcessManagers::SpawnClaudeCodeCli.new(
        transcription_text: prompt,
        instruction_template: prompt,
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
        @thread.current_status = "failed"
        @thread.updated_at = Time.utc
        @thread.save rescue nil
        @error_message = spawn_pm.error_message
        STDERR.puts "[SendFollowUpMessage] CLI spawn failed: #{@error_message}"
      end

      # 6. Emit THREAD_UPDATED event
      Scribe::Events::EventBus.emit(
        Scribe::Events::THREAD_UPDATED,
        Scribe::Events::EventData.new(
          thread_uuid: @thread.thread_uuid,
          status: "processing"
        )
      )

      @was_successful = true
      puts "[SendFollowUpMessage] Follow-up sent in thread #{@thread.thread_uuid}"
    rescue ex
      @error_message = "Unexpected error: #{ex.message}"
      STDERR.puts "[SendFollowUpMessage] #{@error_message}"
    end

    # Build a full conversation context prompt from all prior messages.
    # Includes all messages so the CLI has complete context.
    private def build_full_context_prompt(thread_id : Int64, new_message : String) : String
      begin
        all_messages = Scribe::Models::InboxMessage.all
        thread_messages = all_messages.select { |m| m.thread_id == thread_id }
        thread_messages = thread_messages.sort_by { |m| m.created_at || Time.utc }
      rescue
        thread_messages = [] of Scribe::Models::InboxMessage
      end

      String.build do |io|
        io << "This is a continued conversation. Here is the full context:\n\n"
        thread_messages.each do |msg|
          role = msg.role == "user" ? "User" : "Assistant"
          io << "#{role}: #{msg.content}\n\n"
        end
      end
    end
  end
end
