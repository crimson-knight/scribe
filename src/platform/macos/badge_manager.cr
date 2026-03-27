{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Manages the unread badge count displayed on the NSStatusItem title.
  # Shows "Scribe [N]" when N > 0 unread threads, or "Scribe" when all read.
  # Updated on THREAD_RESPONSE_READY and THREAD_READ events.
  #
  # Epic 13.2
  module BadgeManager
    # Update the status item title to reflect unread thread count.
    def self.update_badge(status_item : Void*)
      return if status_item.null?

      count = count_unread
      if count > 0
        LibScribePlatform.scribe_set_status_item_title(status_item, "Scribe [#{count}]".to_unsafe)
      else
        LibScribePlatform.scribe_set_status_item_title(status_item, "Scribe".to_unsafe)
      end
    end

    # Mark a thread as read by UUID: set unread = 0 and emit THREAD_READ.
    def self.mark_thread_read(thread_uuid : String)
      threads = Scribe::Models::InboxThread.all
      thread = threads.find { |t| t.thread_uuid == thread_uuid }
      return unless thread
      return if thread.unread == 0

      thread.unread = 0
      thread.updated_at = Time.utc
      thread.save rescue nil

      Scribe::Events::EventBus.emit(
        Scribe::Events::THREAD_READ,
        Scribe::Events::EventData.new(thread_uuid: thread_uuid)
      )

      puts "[BadgeManager] Thread #{thread_uuid} marked as read"
    end

    # Count unread threads via ORM.
    private def self.count_unread : Int32
      threads = Scribe::Models::InboxThread.all
      threads.count { |t| t.unread == 1 }.to_i32
    end
  end
end

{% end %}
