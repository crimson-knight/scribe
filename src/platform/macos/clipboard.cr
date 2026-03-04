{% if flag?(:macos) %}

module Scribe::Platform::MacOS::Clipboard
  # Read current clipboard text. Returns nil if clipboard is empty or non-text.
  def self.read : String?
    ptr = LibScribePlatform.scribe_clipboard_read
    return nil if ptr.null?

    text = String.new(ptr)
    LibScribePlatform.scribe_clipboard_free(ptr)
    text
  end

  # Write text to clipboard. Returns true on success.
  def self.write(text : String) : Bool
    LibScribePlatform.scribe_clipboard_write(text.to_unsafe) == 0
  end

  # Simulate Cmd+V paste keystroke via CGEvent injection.
  # Requires Accessibility permission.
  def self.simulate_paste : Bool
    LibScribePlatform.scribe_clipboard_simulate_paste == 0
  end
end

{% end %}
