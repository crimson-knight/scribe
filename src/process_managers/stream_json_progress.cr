require "../adapters/cli_adapter"

module Scribe::ProcessManagers
  # Process Manager: StreamJsonProgress
  #
  # Reads stdout from a spawned CLI process line-by-line, parses each line
  # as a JSON streaming event via the adapter, and emits typed EventBus events.
  # Accumulates all events for history and extracts the final result text.
  #
  # FSDD Pattern: PERFORM process manager (Epic 5.2 / Epic 10.3)
  class StreamJsonProgress
    getter streamed_events : Array(Scribe::Adapters::CliEvent)
    getter final_result_text : String?
    getter? was_completed : Bool = false
    getter exit_code : Int32?
    getter error_message : String?

    def initialize(
      @process : Process,
      @processing_job : Scribe::Models::ProcessingJob,
      @adapter : Scribe::Adapters::CliAdapter
    )
      @streamed_events = [] of Scribe::Adapters::CliEvent
    end

    def perform
      stdout = @process.output

      # Read stdout line-by-line until EOF
      while line = stdout.gets
        next if line.strip.empty?

        begin
          event = @adapter.parse_stream_line(line)
          @streamed_events << event

          dispatch_event(event)

          # Detect completion events
          case event.type
          when Scribe::Adapters::CliEventType::Result
            @final_result_text = event.text_content
            @was_completed = true
          when Scribe::Adapters::CliEventType::Error
            @error_message = event.text_content || "Unknown CLI error"
          end
        rescue ex
          STDERR.puts "[StreamJsonProgress] Error parsing line: #{ex.message}"
        end
      end

      # Process has finished writing stdout -- wait for exit
      status = @process.wait
      @exit_code = status.exit_code

      # If we didn't get a result event but process exited cleanly, still mark completed
      if !@was_completed && status.success?
        @was_completed = true
      end

      puts "[StreamJsonProgress] Stream ended (exit_code=#{@exit_code}, events=#{@streamed_events.size})"
    rescue ex
      @error_message = "Stream reading error: #{ex.message}"
      STDERR.puts "[StreamJsonProgress] #{@error_message}"
    end

    # Dispatch the appropriate EventBus event based on the parsed event type
    private def dispatch_event(event : Scribe::Adapters::CliEvent)
      job_id = (@processing_job.id || 0).to_s

      case event.type
      when Scribe::Adapters::CliEventType::Assistant
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_PROGRESS,
          Scribe::Events::EventData.new(
            job_id: job_id,
            text: event.text_content || ""
          )
        )
      when Scribe::Adapters::CliEventType::ToolUse
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_TOOL_USE,
          Scribe::Events::EventData.new(
            job_id: job_id,
            tool_name: event.tool_name || "unknown"
          )
        )
      when Scribe::Adapters::CliEventType::ToolResult
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_TOOL_RESULT,
          Scribe::Events::EventData.new(
            job_id: job_id,
            content: event.text_content || ""
          )
        )
      when Scribe::Adapters::CliEventType::Result
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_COMPLETED,
          Scribe::Events::EventData.new(
            job_id: job_id,
            result: event.text_content || "",
            duration_ms: (event.duration_ms || 0).to_s
          )
        )
      when Scribe::Adapters::CliEventType::Error
        Scribe::Events::EventBus.emit(
          Scribe::Events::CLI_FAILED,
          Scribe::Events::EventData.new(
            job_id: job_id,
            error: event.text_content || "Unknown error"
          )
        )
      else
        # Unknown event type -- logged but no EventBus emission
        STDERR.puts "[StreamJsonProgress] Unknown event type in line: #{event.raw_line[0, 80]}"
      end
    end
  end
end
