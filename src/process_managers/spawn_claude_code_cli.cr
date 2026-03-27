require "../adapters/cli_adapter"
require "../adapters/claude_code_adapter"

module Scribe::ProcessManagers
  # Process Manager: SpawnClaudeCodeCli
  #
  # Spawns the Claude Code CLI as a child process with JSON streaming output.
  # Builds a prompt from an instruction template and transcription text,
  # creates a ProcessingJob record, and returns the spawned process for
  # streaming by StreamJsonProgress.
  #
  # FSDD Pattern: PERFORM process manager (Epic 5.1 / Epic 10.2)
  class SpawnClaudeCodeCli
    TRANSCRIPTION_PLACEHOLDER = "{{transcription}}"

    getter process : Process?
    getter processing_job : Scribe::Models::ProcessingJob?
    getter? was_spawn_successful : Bool = false
    getter error_message : String?

    def initialize(
      @transcription_text : String,
      @instruction_template : String,
      @output_directory : String,
      @adapter : Scribe::Adapters::CliAdapter = Scribe::Adapters::ClaudeCodeAdapter.new
    )
    end

    def perform
      # 1. Validate CLI binary exists
      unless @adapter.cli_available?
        @error_message = "CLI binary not found: #{@adapter.adapter_name}. Ensure '#{@adapter.adapter_name}' is installed and in PATH."
        STDERR.puts "[SpawnClaudeCodeCli] #{@error_message}"
        return
      end

      # 2. Build prompt from template and transcription
      prompt = build_prompt

      # 3. Construct CLI command via adapter
      options = Scribe::Adapters::AdapterOptions.new(
        working_directory: @output_directory
      )
      command_args = @adapter.build_command(prompt, options)

      # 4. Spawn CLI process with stdout pipe for streaming
      binary = command_args.first
      args = command_args[1..]

      begin
        stderr_pipe = IO::Memory.new
        @process = Process.new(
          command: binary,
          args: args,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe,
          chdir: @output_directory
        )
      rescue ex
        @error_message = "Failed to spawn CLI process: #{ex.message}"
        STDERR.puts "[SpawnClaudeCodeCli] #{@error_message}"
        return
      end

      # 5. Create ProcessingJob record
      job = Scribe::Models::ProcessingJob.new
      job.job_type = "ai_processing"
      job.input_path = @output_directory
      job.current_status = "running"
      job.started_at = Time.utc
      begin
        job.save
      rescue ex
        STDERR.puts "[SpawnClaudeCodeCli] Warning: Failed to save ProcessingJob: #{ex.message}"
      end
      @processing_job = job

      @was_spawn_successful = true

      # 6. Emit CLI_SPAWNED event
      Scribe::Events::EventBus.emit(
        Scribe::Events::CLI_SPAWNED,
        Scribe::Events::EventData.new(
          job_id: (job.id || 0).to_s,
          adapter: @adapter.adapter_name
        )
      )

      puts "[SpawnClaudeCodeCli] Process spawned (adapter=#{@adapter.adapter_name})"
    rescue ex
      @error_message = "Unexpected error: #{ex.message}"
      STDERR.puts "[SpawnClaudeCodeCli] #{@error_message}"
    end

    # Build the prompt by substituting {{transcription}} in the template
    # and appending working directory context.
    private def build_prompt : String
      # Replace placeholder with transcription text
      prompt = @instruction_template.gsub(TRANSCRIPTION_PLACEHOLDER, @transcription_text)

      # If the template didn't contain the placeholder, append the transcription
      unless @instruction_template.includes?(TRANSCRIPTION_PLACEHOLDER)
        prompt += "\n\nWorking directory: #{@output_directory}\nTranscription content:\n---\n#{@transcription_text}\n---"
      end

      prompt
    end
  end
end
