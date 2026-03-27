module Scribe::ProcessManagers
  # Process Manager: CancelProcessingJob
  #
  # Cancels an active CLI processing job by sending SIGTERM, waiting up to
  # 5 seconds, then SIGKILL if the process is still running. Updates the
  # ProcessingJob status to "cancelled" and preserves any partial output.
  #
  # FSDD Pattern: PERFORM process manager (Epic 5.6 / Epic 10.5)
  class CancelProcessingJob
    SIGTERM_WAIT_SECONDS = 5

    getter? was_cancelled : Bool = false
    getter? required_sigkill : Bool = false
    getter error_message : String?

    def initialize(
      @process : Process,
      @processing_job : Scribe::Models::ProcessingJob
    )
    end

    def perform
      pid = @process.pid

      # 1. Check if process is already terminated
      unless process_running?(pid)
        @was_cancelled = true
        update_job_status
        puts "[CancelProcessingJob] Process #{pid} already exited"
        return
      end

      # 2. Send SIGTERM (graceful shutdown)
      begin
        Process.signal(Signal::TERM, pid)
        puts "[CancelProcessingJob] Sent SIGTERM to process #{pid}"
      rescue ex
        # Process may have already exited between our check and signal
        @was_cancelled = true
        update_job_status
        puts "[CancelProcessingJob] Process #{pid} exited before SIGTERM could be sent"
        return
      end

      # 3. Wait up to 5 seconds for graceful exit
      exited = wait_for_exit(pid, SIGTERM_WAIT_SECONDS)

      # 4. Send SIGKILL if still running
      if !exited && process_running?(pid)
        begin
          Process.signal(Signal::KILL, pid)
          @required_sigkill = true
          puts "[CancelProcessingJob] Sent SIGKILL to process #{pid}"
        rescue ex
          # Process exited between check and kill -- that's fine
          puts "[CancelProcessingJob] Process #{pid} exited before SIGKILL"
        end
      end

      @was_cancelled = true

      # 5. Update ProcessingJob
      update_job_status

      # 6. Emit cancellation event
      job_id = (@processing_job.id || 0).to_s
      Scribe::Events::EventBus.emit(
        Scribe::Events::CLI_CANCELLED,
        Scribe::Events::EventData.new(
          job_id: job_id,
          required_sigkill: @required_sigkill.to_s
        )
      )

      puts "[CancelProcessingJob] Job #{job_id} cancelled (sigkill=#{@required_sigkill})"
    rescue ex
      @error_message = "Cancel error: #{ex.message}"
      STDERR.puts "[CancelProcessingJob] #{@error_message}"
    end

    # Update the ProcessingJob record to cancelled status
    private def update_job_status
      @processing_job.current_status = "cancelled"
      @processing_job.completed_at = Time.utc
      begin
        @processing_job.save
      rescue ex
        STDERR.puts "[CancelProcessingJob] Warning: Failed to save ProcessingJob: #{ex.message}"
      end
    end

    # Check if a process is still running by sending signal 0
    private def process_running?(pid : Int64) : Bool
      Process.signal(Signal::NONE, pid)
      true
    rescue
      false
    end

    # Poll for process exit over the given number of seconds.
    # Returns true if the process exited within the timeout.
    private def wait_for_exit(pid : Int64, seconds : Int32) : Bool
      # Poll every 250ms
      checks = seconds * 4
      checks.times do
        return true unless process_running?(pid)
        sleep 0.25
      end
      !process_running?(pid)
    end
  end
end
