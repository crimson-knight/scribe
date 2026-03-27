require "amber"
require "asset_pipeline/ui"
require "crystal_audio"
require "../config/*"

# Compiler compatibility patches
require "./patches/**"

# Application source
require "./models/**"
require "./events/**"
require "./adapters/**"
require "./services/**"
require "./process_managers/**"
require "./ui/**"
require "./controllers/**"

# Platform-specific entry point
{% if flag?(:macos) %}
  require "./platform/macos/**"
{% end %}

# Launch the native app
{% if flag?(:macos) %}
  Scribe::Platform::MacOS::App.run
{% elsif flag?(:ios) %}
  # iOS: crystal_init() called from Swift host — no Crystal-side main loop
{% elsif flag?(:android) %}
  # Android: JNI entry point — no Crystal-side main loop
{% else %}
  puts "Scribe requires a platform flag: -Dmacos, -Dios, or -Dandroid"
  exit 1
{% end %}
