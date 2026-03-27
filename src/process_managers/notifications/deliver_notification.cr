{% if flag?(:macos) %}

module Scribe::Notifications
  # Process Manager: DeliverNotification
  #
  # Sends a macOS system notification via UNUserNotificationCenter.
  # Permission is requested lazily on first use (handled in ObjC bridge).
  #
  # FSDD Pattern: PERFORM process manager (Epic 13.1)
  class DeliverNotification
    getter? was_successful : Bool = false

    def initialize(
      @title : String,
      @body : String,
      @identifier : String
    )
    end

    def perform
      # Truncate body to 200 chars for notification readability
      truncated_body = @body.size > 200 ? @body[0, 200] + "..." : @body

      Scribe::Platform::MacOS::LibScribePlatform.scribe_notification_send(
        @title.to_unsafe,
        truncated_body.to_unsafe,
        @identifier.to_unsafe
      )

      @was_successful = true
      puts "[DeliverNotification] Sent: #{@title}"
    rescue ex
      STDERR.puts "[DeliverNotification] Failed: #{ex.message}"
    end
  end
end

{% end %}
