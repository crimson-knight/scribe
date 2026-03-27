module Scribe::ProcessManagers
  # Process Manager: InitializeApplication
  #
  # Runs on app startup before the main event loop.
  # Creates App Support directories, initializes the database,
  # runs migrations, loads or creates default settings, and
  # creates the output directory.
  #
  # FSDD Pattern: PERFORM process manager (system-initiated at launch)
  class InitializeApplication
    getter? first_launch : Bool = false
    getter directories_created : Array(String) = [] of String
    getter error_message : String?

    def perform
      home = ENV["HOME"]? || "/tmp"

      # 1. Create App Support directories
      app_support = File.join(home, "Library/Application Support/Scribe")
      models_dir = File.join(app_support, "models")
      [app_support, models_dir].each do |dir|
        unless Dir.exists?(dir)
          Dir.mkdir_p(dir)
          @directories_created << dir
          @first_launch = true
        end
      end

      # 2. Initialize database (connection + migrations)
      Scribe::Database.setup

      # 3. Load or create default settings
      Scribe::Settings::Manager.load

      # 4. Create output directory from settings
      output_dir = Scribe::Settings::Manager.output_dir
      unless Dir.exists?(output_dir)
        Dir.mkdir_p(output_dir)
        @directories_created << output_dir
      end

      # 5. Setup iCloud directories if enabled (Epic 12)
      # This may update inbox_storage_path to iCloud path
      icloud_setup = Scribe::ProcessManagers::SetupICloudDirectories.new
      icloud_setup.perform
      @directories_created.concat(icloud_setup.directories_created)

      # 6. Create inbox storage directory and archive subdirectory (Epic 11)
      # Uses the (possibly iCloud-updated) inbox_storage_path
      inbox_dir = Scribe::Settings::Manager.inbox_storage_path
      archive_dir = File.join(inbox_dir, "archive")
      [inbox_dir, archive_dir].each do |dir|
        unless Dir.exists?(dir)
          Dir.mkdir_p(dir)
          @directories_created << dir
        end
      end

      # 7. Emit app initialized event
      Scribe::Events::EventBus.emit(
        Scribe::Events::APP_INITIALIZED,
        Scribe::Events::EventData.new(
          first_launch: @first_launch.to_s,
          output_dir: output_dir
        )
      )

      puts "[Scribe] Application initialized (first_launch=#{@first_launch})"
    rescue ex
      @error_message = ex.message
      STDERR.puts "[Scribe] Initialization error: #{ex.message}"
    end
  end
end
