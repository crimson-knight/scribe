module Scribe::UI::InboxListView
  # Build the inbox list view using Asset Pipeline components.
  # Shows a scrollable list of inbox threads sorted by updated_at desc.
  def self.build : ::UI::VStack
    root = ::UI::VStack.new(spacing: 12.0)

    # Header
    header = ::UI::Label.new("Inbox")
    header.font = ::UI::Font.new(size: 24.0, weight: :bold)
    header.text_color = ::UI::Color.new(0.1, 0.1, 0.1, 1.0)
    root << header

    # Query threads from database
    begin
      threads = Scribe::Models::InboxThread.all
      # Sort by updated_at desc (newest first)
      sorted_threads = threads.sort_by { |t| t.updated_at || Time.utc }.reverse
    rescue
      sorted_threads = [] of Scribe::Models::InboxThread
    end

    if sorted_threads.empty?
      # Empty state
      empty_label = ::UI::Label.new("No threads yet")
      empty_label.font = ::UI::Font.new(size: 16.0, weight: :regular)
      empty_label.text_color = ::UI::Color.new(0.5, 0.5, 0.5, 1.0)
      root << empty_label

      hint_label = ::UI::Label.new("Record a dictation and click \"Send to Agent\" to get started.")
      hint_label.font = ::UI::Font.new(size: 12.0, weight: :light)
      hint_label.text_color = ::UI::Color.new(0.6, 0.6, 0.6, 1.0)
      root << hint_label
    else
      sorted_threads.each do |thread|
        row = build_thread_row(thread)
        root << row
      end
    end

    root << ::UI::Spacer.new

    root
  end

  # Build a single thread row with title, status, and timestamp.
  private def self.build_thread_row(thread : Scribe::Models::InboxThread) : ::UI::VStack
    row = ::UI::VStack.new(spacing: 4.0)

    # Title with unread indicator
    title_text = thread.unread == 1 ? "* #{thread.title}" : thread.title
    title_weight = thread.unread == 1 ? :bold : :semibold
    title = ::UI::Label.new(title_text)
    title.font = ::UI::Font.new(size: 14.0, weight: title_weight)
    title.text_color = ::UI::Color.new(0.1, 0.1, 0.1, 1.0)
    row << title

    # Status and timestamp
    status_color = case thread.current_status
                   when "completed" then ::UI::Color.new(0.2, 0.7, 0.2, 1.0)
                   when "processing" then ::UI::Color.new(0.9, 0.6, 0.1, 1.0)
                   when "failed" then ::UI::Color.new(0.8, 0.2, 0.2, 1.0)
                   when "archived" then ::UI::Color.new(0.5, 0.5, 0.5, 1.0)
                   else ::UI::Color.new(0.3, 0.3, 0.3, 1.0)
                   end

    status_text = thread.current_status.capitalize
    if thread.current_status == "processing"
      status_text = "Processing..."
    end

    updated_str = thread.updated_at.try(&.to_s("%b %d, %I:%M %p")) || ""
    info_text = "#{status_text}  |  #{updated_str}"

    info = ::UI::Label.new(info_text)
    info.font = ::UI::Font.new(size: 11.0, weight: :regular)
    info.text_color = status_color
    row << info

    row
  end
end
