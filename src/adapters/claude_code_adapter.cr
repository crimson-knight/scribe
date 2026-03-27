require "./cli_adapter"

module Scribe::Adapters
  # Concrete CLI adapter for the Claude Code CLI (`claude`).
  #
  # Builds commands using Claude Code's flags:
  #   claude -p "prompt" --output-format stream-json --allowedTools "Write,Edit,..."
  #
  # Parses the stream-json output format where each line is a JSON object
  # with a `type` field: assistant, tool_use, tool_result, result, error.
  class ClaudeCodeAdapter < CliAdapter
    getter cli_path : String

    def initialize(@cli_path : String = "claude")
    end

    def adapter_name : String
      "claude-code"
    end

    # Build the claude CLI command array.
    #
    # Example output:
    #   ["claude", "-p", "prompt text", "--output-format", "stream-json",
    #    "--allowedTools", "Write,Edit,Read,Glob,Grep"]
    def build_command(prompt : String, options : AdapterOptions) : Array(String)
      cmd = [@cli_path, "-p", prompt, "--output-format", options.output_format]

      unless options.allowed_tools.empty?
        cmd << "--allowedTools"
        cmd << options.allowed_tools.join(",")
      end

      if max = options.max_turns
        cmd << "--max-turns"
        cmd << max.to_s
      end

      cmd
    end

    # Parse a single line of Claude Code stream-json output.
    #
    # Expected JSON formats:
    #   {"type":"assistant","message":{"content":[{"type":"text","text":"..."}]}}
    #   {"type":"tool_use","tool":{"name":"Write","input":{...}}}
    #   {"type":"tool_result","content":"..."}
    #   {"type":"result","result":"...","duration_ms":1234}
    #   {"type":"error","error":{"message":"..."}}
    def parse_stream_line(line : String) : CliEvent
      stripped = line.strip
      return CliEvent.new(type: CliEventType::Unknown, raw_line: line) if stripped.empty?

      json = JSON.parse(stripped)
      type_str = json["type"]?.try(&.as_s?) || ""

      case type_str
      when "assistant"
        text = extract_assistant_text(json)
        CliEvent.new(
          type: CliEventType::Assistant,
          raw_line: line,
          data: json,
          text_content: text
        )
      when "tool_use"
        tool_name = json["tool"]?.try(&.["name"]?.try(&.as_s?))
        CliEvent.new(
          type: CliEventType::ToolUse,
          raw_line: line,
          data: json,
          tool_name: tool_name
        )
      when "tool_result"
        content = json["content"]?.try(&.as_s?)
        CliEvent.new(
          type: CliEventType::ToolResult,
          raw_line: line,
          data: json,
          text_content: content
        )
      when "result"
        result_text = json["result"]?.try(&.as_s?)
        duration = json["duration_ms"]?.try(&.as_i64?)
        CliEvent.new(
          type: CliEventType::Result,
          raw_line: line,
          data: json,
          text_content: result_text,
          duration_ms: duration
        )
      when "error"
        error_msg = json["error"]?.try(&.["message"]?.try(&.as_s?))
        CliEvent.new(
          type: CliEventType::Error,
          raw_line: line,
          data: json,
          text_content: error_msg
        )
      else
        CliEvent.new(type: CliEventType::Unknown, raw_line: line, data: json)
      end
    rescue ex : JSON::ParseException
      CliEvent.new(type: CliEventType::Unknown, raw_line: line)
    end

    # Extract text content from an assistant message.
    # The assistant message format has nested content array:
    #   {"message":{"content":[{"type":"text","text":"actual text"}]}}
    private def extract_assistant_text(json : JSON::Any) : String?
      content_array = json["message"]?.try(&.["content"]?)
      return nil unless content_array

      # Collect all text blocks from the content array
      texts = [] of String
      if arr = content_array.as_a?
        arr.each do |item|
          if item["type"]?.try(&.as_s?) == "text"
            if text = item["text"]?.try(&.as_s?)
              texts << text
            end
          end
        end
      end

      texts.empty? ? nil : texts.join("\n")
    end
  end
end
