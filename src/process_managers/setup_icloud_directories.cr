module Scribe::ProcessManagers
  # Process Manager: SetupICloudDirectories
  #
  # Creates iCloud Drive directory structure for Scribe if iCloud sync
  # is enabled and the iCloud Drive container exists. Updates the
  # inbox_storage_path setting to point to iCloud when active.
  #
  # iCloud structure:
  #   ~/Library/Mobile Documents/com~apple~CloudDocs/Scribe/
  #     inbox/          -- thread .md files
  #     transcriptions/ -- saved transcription .md files
  #     templates/      -- instruction template .md files
  #
  # FSDD Pattern: PERFORM process manager (Epic 12.1)
  class SetupICloudDirectories
    getter? icloud_available : Bool = false
    getter directories_created : Array(String) = [] of String
    getter error_message : String?

    def perform
      # Check if iCloud sync is enabled (auto-detects if set to "auto")
      unless Scribe::Settings::Manager.icloud_sync_enabled?
        puts "[SetupICloudDirectories] iCloud sync disabled or iCloud Drive not available"
        return
      end

      icloud_base = Scribe::Settings::Manager.icloud_base_path
      inbox_dir = File.join(icloud_base, "inbox")
      transcriptions_dir = File.join(icloud_base, "transcriptions")
      templates_dir = File.join(icloud_base, "templates")

      # Create iCloud directories
      [icloud_base, inbox_dir, transcriptions_dir, templates_dir].each do |dir|
        unless Dir.exists?(dir)
          Dir.mkdir_p(dir)
          @directories_created << dir
        end
      end

      @icloud_available = true

      # Update inbox_storage_path to point to iCloud inbox
      Scribe::Settings::Manager.set("inbox_storage_path", inbox_dir)

      puts "[SetupICloudDirectories] iCloud directories ready at #{icloud_base}"
      puts "[SetupICloudDirectories] Inbox storage path updated to: #{inbox_dir}"
    rescue ex
      @error_message = ex.message
      STDERR.puts "[SetupICloudDirectories] Error: #{ex.message}"
    end
  end
end
