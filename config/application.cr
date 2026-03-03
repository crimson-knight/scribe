require "amber"
require "../src/controllers/application_controller"

Amber::Server.configure do |settings|
  settings.name = "scribe"
  settings.port = ENV["PORT"]?.try(&.to_i) || 3000
  settings.env = ENV["AMBER_ENV"]? || "development"
  settings.secret_key_base = ENV["SECRET_KEY_BASE"]? || "change_me"
end