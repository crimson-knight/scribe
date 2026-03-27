require "digest/sha256"

module Scribe::ProcessManagers
  # Process Manager: VerifyModelIntegrity
  #
  # Computes SHA256 hash of a whisper model file and verifies against
  # a stored known-good hash. On first verification, stores the computed
  # hash in the application_settings table. On subsequent verifications,
  # compares against the stored hash.
  #
  # Emits MODEL_VERIFIED on success, MODEL_CORRUPTED on mismatch or missing file.
  # Reads file in 8KB chunks to handle large models (up to 2.9 GB).
  #
  # FSDD Pattern: PERFORM process manager (system-initiated after discovery/download)
  class VerifyModelIntegrity
    CHUNK_SIZE = 8192 # 8KB read chunks

    getter? verified : Bool = false
    getter computed_hash : String = ""
    getter expected_hash : String = ""
    getter error_message : String?

    def initialize(@model_path : String, @model_name : String = "ggml-base.en.bin")
    end

    def perform
      # Check file exists
      unless File.exists?(@model_path)
        @error_message = "Model file not found: #{@model_path}"
        emit_corrupted
        return
      end

      # Check file is not empty
      if File.size(@model_path) == 0
        @error_message = "Model file is empty: #{@model_path}"
        emit_corrupted
        return
      end

      # Compute SHA256 in chunks (handles large files)
      @computed_hash = compute_sha256(@model_path)

      # Look up stored hash from settings
      settings_key = "model_hash_#{@model_name}"
      @expected_hash = Scribe::Settings::Manager.get(settings_key)

      if @expected_hash.empty?
        # First verification -- store the computed hash as known-good
        Scribe::Settings::Manager.set(settings_key, @computed_hash)
        @expected_hash = @computed_hash
        @verified = true
        puts "[Scribe] Model integrity: first verification, hash stored for #{@model_name}"
        emit_verified
      elsif @computed_hash == @expected_hash
        # Hash matches stored value
        @verified = true
        puts "[Scribe] Model integrity: verified #{@model_name}"
        emit_verified
      else
        # Hash mismatch -- file may be corrupted
        @error_message = "Hash mismatch for #{@model_name}: expected #{@expected_hash[0..7]}..., got #{@computed_hash[0..7]}..."
        puts "[Scribe] Model integrity: CORRUPTED #{@model_name}"
        emit_corrupted
      end
    rescue ex
      @error_message = "Integrity check error: #{ex.message}"
      STDERR.puts "[Scribe] #{@error_message}"
      emit_corrupted
    end

    private def compute_sha256(path : String) : String
      digest = Digest::SHA256.new
      File.open(path, "rb") do |file|
        buffer = Bytes.new(CHUNK_SIZE)
        while (bytes_read = file.read(buffer)) > 0
          digest.update(buffer[0, bytes_read])
        end
      end
      digest.hexfinal
    end

    private def emit_verified
      Scribe::Events::EventBus.emit(
        Scribe::Events::MODEL_VERIFIED,
        Scribe::Events::EventData.new(
          path: @model_path,
          hash: @computed_hash,
          model_name: @model_name
        )
      )
    end

    private def emit_corrupted
      Scribe::Events::EventBus.emit(
        Scribe::Events::MODEL_CORRUPTED,
        Scribe::Events::EventData.new(
          path: @model_path,
          expected_hash: @expected_hash,
          computed_hash: @computed_hash,
          model_name: @model_name
        )
      )
    end
  end
end
