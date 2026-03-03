# POC 2: macOS Global Keyboard Shortcuts
#
# Validates:
# 1. Carbon RegisterEventHotKey works from Crystal FFI
# 2. Global shortcuts trigger callbacks regardless of focused app
# 3. Modifier + key combinations can be registered/unregistered
#
# Build:
#   clang -c poc/keyboard-shortcuts/ext/hotkey_bridge.c -o poc/keyboard-shortcuts/ext/hotkey_bridge.o -framework Carbon
#   crystal-alpha build poc/keyboard-shortcuts/hotkey_poc.cr -o bin/poc_hotkey \
#     --link-flags="poc/keyboard-shortcuts/ext/hotkey_bridge.o -framework Carbon -framework AppKit"

{% if flag?(:darwin) %}

@[Link(framework: "Carbon")]
@[Link(framework: "AppKit")]
lib LibHotkeyBridge
  # Callback type: receives the hotkey ID when triggered
  alias HotkeyCallbackFn = (UInt32) -> Void

  # Install the Carbon event handler (call once)
  fun hotkey_install_handler(callback : HotkeyCallbackFn) : Int32

  # Register a global hotkey
  # modifier_flags: cmdKey=0x100, shiftKey=0x200, optionKey=0x800, controlKey=0x1000
  # key_code: Carbon virtual key code
  fun hotkey_register(hotkey_id : UInt32, modifier_flags : UInt32, key_code : UInt32, out_ref : Void**) : Int32

  # Unregister a hotkey
  fun hotkey_unregister(ref : Void*) : Int32

  # Run Carbon event loop (blocking)
  fun hotkey_run_loop(seconds : Float64) : Void

  # Pump events (non-blocking, for integration)
  fun hotkey_pump_events : Void
end

# Carbon modifier flags
MODIFIER_CMD     = 0x0100_u32
MODIFIER_SHIFT   = 0x0200_u32
MODIFIER_OPTION  = 0x0800_u32
MODIFIER_CONTROL = 0x1000_u32

# Common Carbon virtual key codes
VK_ANSI_R = 0x0F_u32  # R key
VK_ANSI_S = 0x01_u32  # S key
VK_ANSI_D = 0x02_u32  # D key
VK_SPACE  = 0x31_u32  # Space bar

# --- Hotkey callback ---
# This gets called from the C event handler when a registered hotkey is pressed
hotkey_triggered = ->(hotkey_id : UInt32) {
  case hotkey_id
  when 1_u32
    puts "[#{Time.local}] HOTKEY 1 triggered: Option+Shift+R (Record toggle)"
  when 2_u32
    puts "[#{Time.local}] HOTKEY 2 triggered: Option+Shift+S (Stop/Save)"
  else
    puts "[#{Time.local}] HOTKEY #{hotkey_id} triggered (unknown)"
  end
}

puts "=== Scribe POC: Global Keyboard Shortcuts ==="
puts ""

# Install the event handler
result = LibHotkeyBridge.hotkey_install_handler(hotkey_triggered)
if result == 0
  puts "Event handler installed: PASS"
else
  puts "Event handler install failed with error: #{result}"
  exit 1
end

# Register hotkeys
hotkey1_ref = Pointer(Void).null
hotkey2_ref = Pointer(Void).null

# Hotkey 1: Option + Shift + R (Record toggle)
result = LibHotkeyBridge.hotkey_register(
  1_u32,
  MODIFIER_OPTION | MODIFIER_SHIFT,
  VK_ANSI_R,
  pointerof(hotkey1_ref)
)
if result == 0
  puts "Hotkey 1 registered (Option+Shift+R): PASS"
else
  puts "Hotkey 1 registration failed: #{result}"
  exit 1
end

# Hotkey 2: Option + Shift + S (Stop/Save)
result = LibHotkeyBridge.hotkey_register(
  2_u32,
  MODIFIER_OPTION | MODIFIER_SHIFT,
  VK_ANSI_S,
  pointerof(hotkey2_ref)
)
if result == 0
  puts "Hotkey 2 registered (Option+Shift+S): PASS"
else
  puts "Hotkey 2 registration failed: #{result}"
  exit 1
end

puts ""
puts "=== Validation Complete ==="
puts "1. Carbon event handler installed: PASS"
puts "2. Global hotkey Option+Shift+R registered: PASS"
puts "3. Global hotkey Option+Shift+S registered: PASS"
puts ""
puts "Listening for hotkeys... Press Option+Shift+R or Option+Shift+S"
puts "(Press Ctrl+C to quit)"
puts ""

# Handle Ctrl+C gracefully
Signal::INT.trap do
  puts "\nUnregistering hotkeys..."
  LibHotkeyBridge.hotkey_unregister(hotkey1_ref) unless hotkey1_ref.null?
  LibHotkeyBridge.hotkey_unregister(hotkey2_ref) unless hotkey2_ref.null?
  puts "Cleanup complete. Exiting."
  exit 0
end

# Run the event loop — this is what makes the hotkeys actually fire
LibHotkeyBridge.hotkey_run_loop(0.0)

{% else %}
puts "This POC requires macOS (Darwin). Current platform not supported."
exit 1
{% end %}
