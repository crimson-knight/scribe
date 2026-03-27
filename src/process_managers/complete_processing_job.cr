module Scribe::ProcessManagers
  # Process Manager: CompleteProcessingJob
  #
  # Finalizes a ProcessingJob after the CLI process exits.
  # Updates the job status to "completed" or "failed" based on exit code,
  # records the completion timestamp, and emits the appropriate event.
  #
  # FSDD Pattern: PERFORM process manager (Epic 5.3 / Epic 10.4)
  class CompleteProcessingJob
    getter final_status : String = "unknown"
    getter? was_successful : Bool = false
    getter duration_seconds : Float64?

    def initialize(
      @processing_job : Scribe::Models::ProcessingJob,
      @exit_code : Int32,
      @final_result_text : String? = nil,
      @error_message : String? = nil
    )
    end

    def perform
      now = Time.utc

      # 1. Determine outcome from exit code
      if @exit_code == 0 && @error_message.nil?
        @final_status = "completed"
        @was_successful = true
      else
        @final_status = "failed"
        @was_successful = false
      end

      # 2. Update ProcessingJob
      @processing_job.current_status = @final_status
      @processing_job.completed_at = now

      if msg = @error_message
        @processing_job.error_message = msg
      end

      if result_text = @final_result_text
        @processing_job.output_path = result_text[0, 255] if result_text.size > 0
      end

      begin
        @processing_job.save
      rescue ex
        STDERR.puts "[CompleteProcessingJob] Warning: Failed to save ProcessingJob: #{ex.message}"
      end

      # 3. Calculate duration
      if started = @processing_job.started_at
        @duration_seconds = (now - started).total_seconds
      end

      # 4. Emit completion or failure event
      job_id = (@processing_job.id || 0).to_s

      if @was_successful
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_COMPLETED,
          Scribe::Events::EventData.new(
            job_id: job_id,
            status: @final_status,
            duration_seconds: (@duration_seconds || 0.0).to_s,
            result: @final_result_text || ""
          )
        )
        puts "[CompleteProcessingJob] Job #{job_id} completed successfully (#{@duration_seconds.try(&.round(1))}s)"
      else
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_FAILED,
          Scribe::Events::EventData.new(
            job_id: job_id,
            status: @final_status,
            exit_code: @exit_code.to_s,
            error: @error_message || "Process exited with code #{@exit_code}"
          )
        )
        STDERR.puts "[CompleteProcessingJob] Job #{job_id} failed (exit_code=#{@exit_code}): #{@error_message}"
      end
    rescue ex
      STDERR.puts "[CompleteProcessingJob] Unexpected error: #{ex.message}"
    end
  end
end
