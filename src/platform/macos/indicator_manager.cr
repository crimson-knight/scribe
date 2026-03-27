{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Manages the floating recording indicator and status bar icon/title updates.
  # Extracted from app.cr (Story 8.4).
  module IndicatorManager
    # Create the floating recording indicator panel (initially hidden).
    def self.create_indicator : Void*
      LibScribePlatform.scribe_create_recording_indicator
    end

    # Show the recording indicator with the given text.
    def self.show(indicator : Void*, text : String? = nil)
      if text
        LibScribePlatform.scribe_update_recording_indicator_text(indicator, text.to_unsafe)
      end
      LibScribePlatform.scribe_show_recording_indicator(indicator)
    end

    # Hide the recording indicator.
    def self.hide(indicator : Void*)
      LibScribePlatform.scribe_hide_recording_indicator(indicator)
    end

    # Update the text on the recording indicator without changing visibility.
    def self.update_text(indicator : Void*, text : String)
      LibScribePlatform.scribe_update_recording_indicator_text(indicator, text.to_unsafe)
    end

    # Update the status bar to reflect recording state.
    def self.update_status_recording(status_item : Void*, record_menu_item : Void*,
                                     recording_indicator : Void*, is_recording : Bool)
      if is_recording
        # Keep mic icon (recognizable) but use filled variant to indicate active state
        LibScribePlatform.scribe_set_status_item_image(status_item, "mic.fill".to_unsafe)
        LibScribePlatform.scribe_set_status_item_title(status_item, "REC".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_title(record_menu_item, "Stop Recording".to_unsafe)
        # Show the floating recording indicator with fresh text
        LibScribePlatform.scribe_update_recording_indicator_text(recording_indicator, "Recording — ⌥⇧R to stop".to_unsafe)
        LibScribePlatform.scribe_show_recording_indicator(recording_indicator)
      else
        LibScribePlatform.scribe_set_status_item_image(status_item, "mic".to_unsafe)
        LibScribePlatform.scribe_set_status_item_title(status_item, "Scribe".to_unsafe)
        LibScribePlatform.scribe_set_menu_item_title(record_menu_item, "Start Recording".to_unsafe)
        # Hide the floating recording indicator
        LibScribePlatform.scribe_hide_recording_indicator(recording_indicator)
      end
    end
  end
end

{% end %}
