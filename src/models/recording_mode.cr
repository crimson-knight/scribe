require "json"

module Scribe::Models
  struct RecordingMode
    include JSON::Serializable

    property name : String
    property shortcut : String
    property output_dir : String
    property system_audio : Bool
    property post_process : String
    property auto_paste : Bool

    def initialize(
      @name : String,
      @shortcut : String = "",
      @output_dir : String = "",
      @system_audio : Bool = false,
      @post_process : String = "",
      @auto_paste : Bool = true
    )
    end

    # Resolve output directory: use mode's dir if set, else fallback.
    def resolved_output_dir(fallback : String) : String
      if output_dir.empty?
        fallback
      else
        output_dir.gsub("~", ENV["HOME"]? || "/tmp")
      end
    end

    # Human-readable summary for settings UI.
    def summary : String
      parts = [] of String
      parts << (system_audio ? "Mic + System Audio" : "Mic Only")
      parts << (auto_paste ? "Auto-paste" : "Save only")
      parts << "→ #{Scribe::Settings::Manager.display_path(output_dir)}" unless output_dir.empty?
      parts << "Post: #{post_process.split(" ").first}" unless post_process.empty?
      parts.join(" | ")
    end
  end
end
