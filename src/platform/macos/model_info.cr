{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Model information for whisper model variants.
  # Used by the menu to display current model name and size.
  module ModelInfo
    record Info, display : String, size_mb : Int32

    MODEL_INFO = {
      "ggml-base.en.bin"   => Info.new(display: "base.en", size_mb: 142),
      "ggml-small.en.bin"  => Info.new(display: "small.en", size_mb: 466),
      "ggml-medium.en.bin" => Info.new(display: "medium.en", size_mb: 1500),
      "ggml-large.bin"     => Info.new(display: "large", size_mb: 2900),
    }

    # Get display string for the current model (e.g. "base.en (142 MB)")
    def self.display_string(model_name : String) : String
      if info = MODEL_INFO[model_name]?
        "#{info.display} (#{info.size_mb} MB)"
      else
        model_name
      end
    end

    # Get the menu item title for the current model
    def self.menu_title(model_name : String) : String
      "Whisper Model: #{display_string(model_name)}"
    end
  end
end

{% end %}
