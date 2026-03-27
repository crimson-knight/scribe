module Scribe::UI::InboxThreadView
  # Build the thread detail view showing full conversation history.
  # Displays all messages in chronological order with role labels,
  # timestamps, and a status indicator.
  def self.build(thread : Scribe::Models::InboxThread) : ::UI::VStack
    root = ::UI::VStack.new(spacing: 12.0)

    # Header with thread title
    title = ::UI::Label.new(thread.title)
    title.font = ::UI::Font.new(size: 20.0, weight: :bold)
    title.text_color = ::UI::Color.new(0.1, 0.1, 0.1, 1.0)
    root << title

    # Status indicator
    status_label = build_status_label(thread.current_status)
    root << status_label

    # Query messages for this thread
    begin
      all_messages = Scribe::Models::InboxMessage.all
      thread_id = thread.id || 0_i64
      messages = all_messages.select { |m| m.thread_id == thread_id }
      # Sort by created_at ascending (chronological)
      messages = messages.sort_by { |m| m.created_at || Time.utc }
    rescue
      messages = [] of Scribe::Models::InboxMessage
    end

    if messages.empty?
      empty_label = ::UI::Label.new("No messages in this thread.")
      empty_label.font = ::UI::Font.new(size: 14.0, weight: :regular)
      empty_label.text_color = ::UI::Color.new(0.5, 0.5, 0.5, 1.0)
      root << empty_label
    else
      messages.each do |message|
        msg_view = build_message_view(message)
        root << msg_view
      end
    end

    root << ::UI::Spacer.new

    root
  end

  # Build a status label with appropriate color for the thread status.
  private def self.build_status_label(status : String) : ::UI::Label
    display_text = case status
                   when "active"     then "Active"
                   when "processing" then "Processing..."
                   when "completed"  then "Completed"
                   when "failed"     then "Failed"
                   when "archived"   then "Archived"
                   else status.capitalize
                   end

    color = case status
            when "completed"  then ::UI::Color.new(0.2, 0.7, 0.2, 1.0)
            when "processing" then ::UI::Color.new(0.9, 0.6, 0.1, 1.0)
            when "failed"     then ::UI::Color.new(0.8, 0.2, 0.2, 1.0)
            when "archived"   then ::UI::Color.new(0.5, 0.5, 0.5, 1.0)
            else ::UI::Color.new(0.3, 0.3, 0.3, 1.0)
            end

    label = ::UI::Label.new(display_text)
    label.font = ::UI::Font.new(size: 12.0, weight: :semibold)
    label.text_color = color
    label
  end

  # Build a single message view with role label, content, and timestamp.
  private def self.build_message_view(message : Scribe::Models::InboxMessage) : ::UI::VStack
    msg_stack = ::UI::VStack.new(spacing: 4.0)

    # Role and timestamp header
    role_label = message.role == "user" ? "User" : "Assistant"
    timestamp = message.created_at.try(&.to_s("%I:%M %p")) || ""
    header_text = "#{role_label} -- #{timestamp}"

    role_color = message.role == "user" ? ::UI::Color.new(0.1, 0.3, 0.7, 1.0) : ::UI::Color.new(0.2, 0.6, 0.3, 1.0)

    header = ::UI::Label.new(header_text)
    header.font = ::UI::Font.new(size: 12.0, weight: :bold)
    header.text_color = role_color
    msg_stack << header

    # Message content
    content = ::UI::Label.new(message.content)
    content.font = ::UI::Font.new(size: 13.0, weight: :regular)
    content.text_color = ::UI::Color.new(0.15, 0.15, 0.15, 1.0)
    msg_stack << content

    msg_stack
  end
end
