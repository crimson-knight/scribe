require "grant"
require "grant/src/adapter/sqlite"
require "grant/src/adapter/pg"
require "grant/src/adapter/mysql"

module Scribe::Database
  @@initialized = false

  def self.setup
    return if @@initialized

    home = ENV["HOME"]? || "/tmp"
    app_support = File.join(home, "Library/Application Support/Scribe")
    Dir.mkdir_p(app_support) unless Dir.exists?(app_support)
    db_path = File.join(app_support, "scribe.db")

    Grant::ConnectionRegistry.establish_connection(
      database: "primary",
      adapter: Grant::Adapter::Sqlite,
      url: "sqlite3://#{db_path}",
      pool_size: 1,
      initial_pool_size: 1
    )

    # Create tables if they don't exist (idempotent — rescue if already exists)
    Scribe::Models::ApplicationSetting.migrator.create rescue nil
    Scribe::Models::ProcessingJob.migrator.create rescue nil
    Scribe::Models::InboxThread.migrator.create rescue nil
    Scribe::Models::InboxMessage.migrator.create rescue nil

    @@initialized = true
    puts "[Scribe::Database] SQLite initialized at #{db_path}"
  end

  def self.initialized? : Bool
    @@initialized
  end
end
