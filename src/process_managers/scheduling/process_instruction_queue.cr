module Scribe::Scheduling
  # Process Manager: ProcessInstructionQueue
  #
  # Manages a FIFO queue of inbox threads to be processed by the CLI adapter.
  # Ensures only one CLI process runs at a time. When processing completes
  # (success or failure), automatically dequeues and processes the next item.
  #
  # Integrates with ScheduleService to respect work hours when enabled.
  #
  # FSDD Pattern: PERFORM process manager (Epic 13.4)
  module ProcessInstructionQueue
    @@queue = [] of Int64          # thread IDs in FIFO order
    @@processing = false
    @@current_thread_id : Int64? = nil

    # Add a thread to the processing queue and trigger processing if idle.
    def self.enqueue(thread_id : Int64)
      @@queue << thread_id

      Scribe::Events::EventBus.emit(
        Scribe::Events::QUEUE_ITEM_ADDED,
        Scribe::Events::EventData.new(
          thread_id: thread_id.to_s,
          queue_size: @@queue.size.to_s
        )
      )

      puts "[ProcessInstructionQueue] Enqueued thread #{thread_id} (queue size: #{@@queue.size})"
      process_next unless @@processing
    end

    # Attempt to process the next item in the queue.
    def self.process_next
      return if @@processing
      return if @@queue.empty?

      # Check work hours (Epic 13.3)
      unless Scribe::Services::ScheduleService.within_work_hours?
        next_start = Scribe::Services::ScheduleService.next_work_window_start
        puts "[ProcessInstructionQueue] Outside work hours -- queue paused until #{next_start}"
        Scribe::Events::EventBus.emit(
          Scribe::Events::QUEUE_IDLE,
          Scribe::Events::EventData.new(
            reason: "outside_work_hours",
            next_start: next_start.to_s
          )
        )
        return
      end

      @@processing = true
      thread_id = @@queue.shift
      @@current_thread_id = thread_id

      # Look up thread from DB
      threads = Scribe::Models::InboxThread.all
      thread = threads.find { |t| (t.id || 0_i64) == thread_id }

      unless thread
        STDERR.puts "[ProcessInstructionQueue] Thread #{thread_id} not found -- skipping"
        @@processing = false
        @@current_thread_id = nil
        process_next
        return
      end

      # Look up user message for this thread
      messages = Scribe::Models::InboxMessage.all
      user_message = messages.find { |m| m.thread_id == thread_id && m.role == "user" }

      unless user_message
        STDERR.puts "[ProcessInstructionQueue] No user message for thread #{thread_id} -- skipping"
        @@processing = false
        @@current_thread_id = nil
        process_next
        return
      end

      # Update thread status to processing
      thread.current_status = "processing"
      thread.updated_at = Time.utc
      thread.save rescue nil

      Scribe::Events::EventBus.emit(
        Scribe::Events::QUEUE_PROCESSING,
        Scribe::Events::EventData.new(
          thread_id: thread_id.to_s,
          thread_uuid: thread.thread_uuid,
          queue_remaining: @@queue.size.to_s
        )
      )

      # Spawn CLI process
      output_dir = Scribe::Settings::Manager.output_dir
      spawn_pm = Scribe::ProcessManagers::SpawnClaudeCodeCli.new(
        transcription_text: user_message.content,
        instruction_template: user_message.content,
        output_directory: output_dir
      )
      spawn_pm.perform

      if spawn_pm.was_spawn_successful?
        # Link processing job to the message
        if job = spawn_pm.processing_job
          user_message.processing_job_id = job.id
          user_message.save rescue nil
        end
        puts "[ProcessInstructionQueue] Processing thread #{thread.thread_uuid}"
      else
        # Spawn failed -- mark thread as failed and move on
        thread.current_status = "failed"
        thread.updated_at = Time.utc
        thread.save rescue nil

        STDERR.puts "[ProcessInstructionQueue] CLI spawn failed for thread #{thread.thread_uuid}: #{spawn_pm.error_message}"
        @@processing = false
        @@current_thread_id = nil
        process_next
      end
    end

    # Called when CLI processing completes successfully for a thread.
    def self.on_completed(thread_id : Int64)
      if @@current_thread_id == thread_id || @@current_thread_id.nil?
        @@processing = false
        @@current_thread_id = nil
        puts "[ProcessInstructionQueue] Completed thread #{thread_id} -- dequeuing next"
        process_next
      end
    end

    # Called when CLI processing fails for a thread.
    def self.on_failed(thread_id : Int64)
      if @@current_thread_id == thread_id || @@current_thread_id.nil?
        @@processing = false
        @@current_thread_id = nil
        puts "[ProcessInstructionQueue] Failed thread #{thread_id} -- dequeuing next"
        process_next
      end
    end

    # Number of items waiting in the queue (not including currently processing).
    def self.queue_size : Int32
      @@queue.size.to_i32
    end

    # Whether a CLI process is currently running.
    def self.processing? : Bool
      @@processing
    end

    # The thread ID currently being processed, if any.
    def self.current_thread_id : Int64?
      @@current_thread_id
    end
  end
end
