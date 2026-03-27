require "yaml"

module Scribe::Services::ThreadFileService
  # Parsed thread data returned from read_thread
  record ThreadData,
    id : String,
    title : String,
    agent : String,
    status : String,
    created : String,
    updated : String

  record MessageData,
    role : String,
    timestamp : String,
    content : String

  # Write a complete thread file (creates or overwrites the .md file).
  # Builds YAML frontmatter from thread metadata and message sections from messages.
  def self.write_thread(thread : Scribe::Models::InboxThread, messages : Array(Scribe::Models::InboxMessage))
    content = String.build do |io|
      # YAML frontmatter
      io << "---\n"
      io << "id: #{thread.thread_uuid}\n"
      io << "title: \"#{escape_yaml_string(thread.title)}\"\n"
      io << "agent: #{thread.agent_id}\n"
      io << "status: #{thread.current_status}\n"
      io << "created: #{thread.created_at.try(&.to_utc.to_s("%Y-%m-%dT%H:%M:%SZ")) || Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")}\n"
      io << "updated: #{thread.updated_at.try(&.to_utc.to_s("%Y-%m-%dT%H:%M:%SZ")) || Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")}\n"
      io << "---\n"

      # Message sections
      messages.each do |msg|
        io << "\n"
        role_label = msg.role == "user" ? "User" : "Assistant"
        timestamp = msg.created_at.try(&.to_s("%I:%M %p")) || Time.utc.to_s("%I:%M %p")
        io << "## #{role_label} -- #{timestamp}\n"
        io << msg.content
        io << "\n"
      end
    end

    File.write(thread.file_path, content)
    puts "[ThreadFileService] Wrote thread file: #{thread.file_path}"
  rescue ex
    STDERR.puts "[ThreadFileService] Failed to write thread file: #{ex.message}"
  end

  # Read and parse a thread .md file. Returns thread metadata and messages.
  def self.read_thread(file_path : String) : {ThreadData, Array(MessageData)}?
    return nil unless File.exists?(file_path)

    raw = File.read(file_path)

    # Split frontmatter from body
    parts = raw.split("---", limit: 3)
    return nil if parts.size < 3

    frontmatter_str = parts[1].strip
    body = parts[2]

    # Parse YAML frontmatter
    thread_data = parse_frontmatter(frontmatter_str)
    return nil unless thread_data

    # Parse message sections from body
    messages = parse_messages(body)

    {thread_data, messages}
  rescue ex
    STDERR.puts "[ThreadFileService] Failed to read thread file #{file_path}: #{ex.message}"
    nil
  end

  # Append a single message to an existing thread file.
  # Updates the frontmatter `updated` timestamp.
  def self.append_message(file_path : String, message : Scribe::Models::InboxMessage)
    return unless File.exists?(file_path)

    raw = File.read(file_path)

    # Update the `updated:` line in frontmatter
    now = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
    raw = raw.gsub(/^updated: .+$/m, "updated: #{now}")

    # Append message section
    role_label = message.role == "user" ? "User" : "Assistant"
    timestamp = message.created_at.try(&.to_s("%I:%M %p")) || Time.utc.to_s("%I:%M %p")

    content = String.build do |io|
      io << raw.chomp
      io << "\n\n## #{role_label} -- #{timestamp}\n"
      io << message.content
      io << "\n"
    end

    File.write(file_path, content)
    puts "[ThreadFileService] Appended message to: #{file_path}"
  rescue ex
    STDERR.puts "[ThreadFileService] Failed to append message: #{ex.message}"
  end

  # Write a completion marker timestamp into the thread file frontmatter.
  # Used by iOS companion app to detect completed threads via iCloud sync.
  # If the frontmatter already has a completion_marker line, it is updated.
  # Otherwise, a new line is inserted before the closing "---".
  #
  # Epic 13.5 -- Mobile Push Notification Readiness
  def self.write_completion_marker(file_path : String, timestamp : Time)
    return unless File.exists?(file_path)

    raw = File.read(file_path)
    marker_value = timestamp.to_utc.to_s("%Y-%m-%dT%H:%M:%SZ")

    if raw.includes?("completion_marker:")
      # Update existing marker
      raw = raw.gsub(/^completion_marker: .+$/m, "completion_marker: #{marker_value}")
    else
      # Insert before closing "---" of frontmatter
      # The frontmatter is delimited by "---\n...\n---\n"
      # We want to insert before the second "---"
      parts = raw.split("---", limit: 3)
      if parts.size >= 3
        raw = String.build do |io|
          io << "---"
          io << parts[1].chomp
          io << "\ncompletion_marker: #{marker_value}\n"
          io << "---"
          io << parts[2]
        end
      end
    end

    File.write(file_path, raw)
    puts "[ThreadFileService] Wrote completion marker to: #{file_path}"
  rescue ex
    STDERR.puts "[ThreadFileService] Failed to write completion marker: #{ex.message}"
  end

  # Parse YAML frontmatter string into ThreadData
  private def self.parse_frontmatter(yaml_str : String) : ThreadData?
    # Simple key: value parsing (avoids full YAML parser complexity)
    data = {} of String => String
    yaml_str.each_line do |line|
      if match = line.match(/^(\w+):\s*(.+)$/)
        key = match[1]
        value = match[2].strip
        # Strip quotes from values
        value = value[1..-2] if value.starts_with?('"') && value.ends_with?('"')
        data[key] = value
      end
    end

    ThreadData.new(
      id: data["id"]? || "",
      title: data["title"]? || "",
      agent: data["agent"]? || "default",
      status: data["status"]? || "active",
      created: data["created"]? || "",
      updated: data["updated"]? || ""
    )
  end

  # Parse message sections from the body text.
  # Messages are delimited by `## Role -- Timestamp` headers.
  private def self.parse_messages(body : String) : Array(MessageData)
    messages = [] of MessageData
    current_role : String? = nil
    current_timestamp : String? = nil
    current_content = String::Builder.new

    body.each_line do |line|
      if match = line.match(/^## (User|Assistant) -- (.+)$/)
        # Save previous message if any
        if role = current_role
          messages << MessageData.new(
            role: role.downcase,
            timestamp: current_timestamp || "",
            content: current_content.to_s.strip
          )
        end
        # Start new message
        current_role = match[1]
        current_timestamp = match[2].strip
        current_content = String::Builder.new
      elsif current_role
        current_content << line
        current_content << "\n"
      end
    end

    # Save last message
    if role = current_role
      messages << MessageData.new(
        role: role.downcase,
        timestamp: current_timestamp || "",
        content: current_content.to_s.strip
      )
    end

    messages
  end

  # Escape special characters in YAML string values
  private def self.escape_yaml_string(str : String) : String
    str.gsub("\"", "\\\"")
  end
end
