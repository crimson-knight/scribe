{% if flag?(:macos) %}

module Scribe::Platform::MacOS
  # Manages Carbon hotkey handler installation and key registration.
  # Supports dynamic registration from RecordingMode configs.
  module HotkeyManager
    # Carbon virtual key code map (US keyboard layout)
    KEY_CODE_MAP = {
      "a" => 0x00_u32, "s" => 0x01_u32, "d" => 0x02_u32, "f" => 0x03_u32,
      "h" => 0x04_u32, "g" => 0x05_u32, "z" => 0x06_u32, "x" => 0x07_u32,
      "c" => 0x08_u32, "v" => 0x09_u32, "b" => 0x0B_u32, "q" => 0x0C_u32,
      "w" => 0x0D_u32, "e" => 0x0E_u32, "r" => 0x0F_u32, "y" => 0x10_u32,
      "t" => 0x11_u32, "1" => 0x12_u32, "2" => 0x13_u32, "3" => 0x14_u32,
      "4" => 0x15_u32, "6" => 0x16_u32, "5" => 0x17_u32, "9" => 0x19_u32,
      "7" => 0x1A_u32, "8" => 0x1C_u32, "0" => 0x1D_u32, "o" => 0x1F_u32,
      "u" => 0x20_u32, "i" => 0x22_u32, "p" => 0x23_u32, "l" => 0x25_u32,
      "j" => 0x26_u32, "k" => 0x28_u32, "n" => 0x2D_u32, "m" => 0x2E_u32,
    }

    @@hotkey_refs = {} of UInt32 => Void*
    @@handler_installed = false

    # Install the Carbon event handler (once) and register default hotkeys.
    def self.register_hotkeys
      install_handler unless @@handler_installed

      # Default: Option+Shift+R for toggle recording
      register_hotkey(HOTKEY_TOGGLE_RECORDING, OPTION_KEY | SHIFT_KEY, VK_R)
      puts "[Scribe] Registered hotkey: Option+Shift+R (toggle recording)"
    end

    # Register hotkeys from an array of RecordingModes. Unregisters all existing first.
    def self.register_from_modes(modes : Array(Scribe::Models::RecordingMode))
      install_handler unless @@handler_installed
      unregister_all

      modes.each_with_index do |mode, idx|
        hotkey_id = (10 + idx).to_u32
        parsed = parse_shortcut(mode.shortcut)
        next unless parsed

        modifiers, key_code = parsed
        register_hotkey(hotkey_id, modifiers, key_code)
        puts "[Scribe] Registered hotkey: #{mode.shortcut} -> #{mode.name} (id: #{hotkey_id})"
      end
    end

    # Unregister all tracked hotkeys.
    def self.unregister_all
      @@hotkey_refs.each do |_id, ref|
        LibScribePlatform.scribe_hotkey_unregister(ref) unless ref.null?
      end
      @@hotkey_refs.clear
    end

    # Register a single hotkey by ID, modifiers, and key code.
    def self.register_hotkey(id : UInt32, modifiers : UInt32, key_code : UInt32)
      hotkey_ref = Pointer(Void).null
      status = LibScribePlatform.scribe_hotkey_register(id, modifiers, key_code, pointerof(hotkey_ref))
      if status == 0
        @@hotkey_refs[id] = hotkey_ref
      else
        STDERR.puts "[Scribe] Warning: Failed to register hotkey id=#{id} (status: #{status})"
      end
    end

    # Parse a shortcut string like "option+shift+r" into {modifier_flags, key_code}.
    # Returns nil if the shortcut string is invalid.
    def self.parse_shortcut(shortcut : String) : {UInt32, UInt32}?
      parts = shortcut.downcase.split("+").map(&.strip)
      key_char = parts.pop?
      return nil unless key_char

      modifiers = 0_u32
      parts.each do |mod|
        case mod
        when "option", "alt"    then modifiers |= OPTION_KEY
        when "shift"            then modifiers |= SHIFT_KEY
        when "cmd", "command"   then modifiers |= CMD_KEY
        when "ctrl", "control"  then modifiers |= CONTROL_KEY
        end
      end

      key_code = KEY_CODE_MAP[key_char]?
      return nil unless key_code

      {modifiers, key_code}
    end

    private def self.install_handler
      status = LibScribePlatform.scribe_hotkey_install_handler(->(hotkey_id : UInt32) {
        if hotkey_id >= 10
          # Mode-specific hotkey (IDs 10+)
          App.toggle_recording_for_mode(hotkey_id)
        else
          case hotkey_id
          when HOTKEY_TOGGLE_RECORDING
            App.toggle_recording
          end
        end
      })
      if status != 0
        STDERR.puts "[Scribe] Warning: Failed to install hotkey handler (status: #{status})"
      end
      @@handler_installed = true
    end
  end
end

{% end %}
