require "json"

module Scribe::Adapters
  # Event types from CLI streaming output
  enum CliEventType
    Assistant   # Claude's text response
    ToolUse     # Tool invocation (Write, Read, etc.)
    ToolResult  # Result from tool execution
    Result      # Final result -- processing complete
    Error       # Error event
    Unknown     # Unparseable line
  end

  # Parsed event from a single line of CLI streaming output
  class CliEvent
    getter type : CliEventType
    getter data : JSON::Any?
    getter raw_line : String
    getter tool_name : String?
    getter text_content : String?
    getter duration_ms : Int64?

    def initialize(
      @type : CliEventType,
      @raw_line : String,
      @data : JSON::Any? = nil,
      @tool_name : String? = nil,
      @text_content : String? = nil,
      @duration_ms : Int64? = nil
    )
    end
  end

  # Configuration options for CLI adapter
  class AdapterOptions
    getter allowed_tools : Array(String)
    getter output_format : String
    getter working_directory : String?
    getter max_turns : Int32?

    def initialize(
      @allowed_tools : Array(String) = ["Write", "Edit", "Read", "Glob", "Grep"],
      @output_format : String = "stream-json",
      @working_directory : String? = nil,
      @max_turns : Int32? = nil
    )
    end
  end

  # Abstract base class for CLI adapters.
  # Subclasses implement command construction and stream line parsing
  # for a specific CLI tool (e.g., Claude Code, future alternatives).
  abstract class CliAdapter
    # Build the command array to spawn the CLI process.
    # Returns an array where element 0 is the binary and the rest are arguments.
    abstract def build_command(prompt : String, options : AdapterOptions) : Array(String)

    # Parse a single line of streaming output into a typed CliEvent.
    abstract def parse_stream_line(line : String) : CliEvent

    # Human-readable name of this adapter (e.g., "claude-code").
    abstract def adapter_name : String

    # Check if the CLI binary is available on the system.
    def cli_available? : Bool
      cmd = build_command("test", AdapterOptions.new)
      binary = cmd.first
      # Check if binary is in PATH
      result = Process.run("which", [binary], output: IO::Memory.new, error: IO::Memory.new)
      result.success?
    rescue
      false
    end
  end
end
