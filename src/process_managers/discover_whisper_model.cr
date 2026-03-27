module Scribe::ProcessManagers
  # Process Manager: DiscoverWhisperModel
  #
  # Searches for a whisper model file across multiple locations in priority order:
  #   1. Explicit path from whisper_model_path setting (if not "auto")
  #   2. App bundle Resources directory
  #   3. App Support models directory
  #   4. Homebrew whisper-cpp models directory
  #
  # Emits MODEL_FOUND or MODEL_MISSING event via the event bus.
  #
  # FSDD Pattern: PERFORM process manager (system-initiated at startup)
  class DiscoverWhisperModel
    getter model_path : String?
    getter? model_found : Bool = false
    getter search_locations : Array(String) = [] of String

    def initialize(@model_name : String = "ggml-base.en.bin")
    end

    def perform
      home = ENV["HOME"]? || "/tmp"

      # 1. Check configured path from settings (if not "auto")
      configured = Scribe::Settings::Manager.whisper_model_path
      if configured != "auto" && !configured.empty?
        expanded = configured.gsub("~", home)
        @search_locations << expanded
        if File.exists?(expanded) && File.size(expanded) > 0
          @model_path = expanded
          @model_found = true
          emit_found
          return
        end
      end

      # 2. Check app bundle Resources
      exe_path = Process.executable_path || ""
      unless exe_path.empty?
        bundle_path = File.join(
          File.dirname(File.dirname(exe_path)),
          "Resources", @model_name
        )
        @search_locations << bundle_path
        if File.exists?(bundle_path) && File.size(bundle_path) > 0
          @model_path = bundle_path
          @model_found = true
          emit_found
          return
        end
      end

      # 3. Check App Support models directory
      app_support_path = File.join(home, "Library/Application Support/Scribe/models", @model_name)
      @search_locations << app_support_path
      if File.exists?(app_support_path) && File.size(app_support_path) > 0
        @model_path = app_support_path
        @model_found = true
        emit_found
        return
      end

      # 4. Check Homebrew whisper-cpp models directory
      homebrew_path = File.join("/opt/homebrew/share/whisper-cpp/models", @model_name)
      @search_locations << homebrew_path
      if File.exists?(homebrew_path) && File.size(homebrew_path) > 0
        @model_path = homebrew_path
        @model_found = true
        emit_found
        return
      end

      # Not found anywhere
      emit_missing
    end

    private def emit_found
      puts "[Scribe] Model discovered: #{@model_path}"
      Scribe::Events::EventBus.emit(
        Scribe::Events::MODEL_FOUND,
        Scribe::Events::EventData.new(
          path: @model_path.to_s,
          model_name: @model_name
        )
      )
    end

    private def emit_missing
      puts "[Scribe] Model not found: #{@model_name}"
      puts "[Scribe] Searched: #{@search_locations.join(", ")}"
      Scribe::Events::EventBus.emit(
        Scribe::Events::MODEL_MISSING,
        Scribe::Events::EventData.new(
          model_name: @model_name,
          searched_locations: @search_locations.join(";")
        )
      )
    end
  end
end
