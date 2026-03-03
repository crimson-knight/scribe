require "./config/*"
require "./src/scribe/*"

Amber::Server.configure do |settings|
  settings.name = "scribe"
  settings.secret_key_base = ENV["SECRET_KEY_BASE"]? || "35ad7502d40bed624a7695c52b1d3b94bebfb3f4fedee0c3f77e0e43dd1b6793bafe51d95b97ccc43a8731814f7127adc61076284299d562866235661eec3d36"
end

Amber::Server.start