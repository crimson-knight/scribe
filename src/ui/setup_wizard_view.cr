{% if flag?(:macos) %}

module Scribe::UI::SetupWizardView
  def self.build(step : Int32) : ::UI::VStack
    primary = Scribe::Platform::MacOS::SystemColors.label
    secondary = Scribe::Platform::MacOS::SystemColors.secondary_label
    accent = Scribe::Platform::MacOS::SystemColors.accent

    root = ::UI::VStack.new(spacing: 20.0)

    case step
    when 0 then build_accessibility_step(root, primary, secondary, accent)
    when 1 then build_login_step(root, primary, secondary, accent)
    when 2 then build_ready_step(root, primary, secondary, accent)
    end

    # Progress dots (centered)
    root << ::UI::Spacer.new
    dots_row = ::UI::HStack.new(spacing: 10.0)
    dots_row << ::UI::Spacer.new
    3.times do |i|
      dot = ::UI::Label.new(i == step ? "●" : "○")
      dot.font = ::UI::Font.new(size: 8.0, weight: :regular)
      dot.text_color = i == step ? accent : secondary
      dot.accessibility_label = i == step ? "Step #{i + 1} of 3, current" : "Step #{i + 1} of 3"
      dots_row << dot
    end
    dots_row << ::UI::Spacer.new
    root << dots_row

    root
  end

  private def self.build_accessibility_step(root, primary, secondary, accent)
    icon = ::UI::Label.new("🔒")
    icon.font = ::UI::Font.new(size: 48.0, weight: :regular)
    icon.accessibility_label = "Security icon"
    root << icon

    title = ::UI::Label.new("Accessibility Access")
    title.font = ::UI::Font.new(size: 22.0, weight: :regular)
    title.text_color = primary
    root << title

    desc = ::UI::Label.new(
      "Scribe needs Accessibility access to paste transcriptions " \
      "into your active application. This allows Scribe to simulate " \
      "keyboard shortcuts after transcribing your voice."
    )
    desc.font = ::UI::Font.new(size: 13.0, weight: :regular)
    desc.text_color = secondary
    root << desc

    ax_granted = Scribe::Platform::MacOS::LibScribePlatform.scribe_accessibility_check(0) == 1

    if ax_granted
      # Permission already granted — show checkmark
      check = ::UI::Label.new("✓ Accessibility access is granted")
      check.font = ::UI::Font.new(size: 13.0, weight: :medium)
      check.text_color = Scribe::Platform::MacOS::SystemColors.system_green
      check.accessibility_label = "Accessibility access is granted"
      root << check
    else
      # Not yet granted — show action buttons
      grant_btn = ::UI::Button.new("Grant Access") {
        puts "[Wizard] Grant Access clicked"
        Scribe::Platform::MacOS::LibScribePlatform.scribe_accessibility_check(1)
        nil
      }
      grant_btn.font = ::UI::Font.new(size: 15.0, weight: :regular)
      grant_btn.key_equivalent = "\r"
      grant_btn.accessibility_label = "Grant Accessibility permission to Scribe"

      settings_btn = ::UI::Button.new("Open System Settings") {
        puts "[Wizard] Open System Settings clicked"
        Scribe::Platform::MacOS::LibScribePlatform.scribe_open_system_settings(
          "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility".to_unsafe
        )
        nil
      }
      settings_btn.font = ::UI::Font.new(size: 13.0, weight: :regular)
      settings_btn.accessibility_label = "Open System Settings to Accessibility preferences"

      grant_row = ::UI::HStack.new(spacing: 12.0)
      grant_row << settings_btn
      grant_row << ::UI::Spacer.new
      grant_row << grant_btn
      root << grant_row

      hint = ::UI::Label.new("After granting access, click Restart to apply.")
      hint.font = ::UI::Font.new(size: 11.0, weight: :regular)
      hint.text_color = secondary
      root << hint

      restart_btn = ::UI::Button.new("Restart Scribe") {
        puts "[Wizard] Restart clicked"
        Scribe::Platform::MacOS::LibScribePlatform.scribe_restart_app
        nil
      }
      restart_btn.font = ::UI::Font.new(size: 13.0, weight: :regular)
      restart_btn.accessibility_label = "Restart Scribe to apply Accessibility permission"
      root << restart_btn
    end

    next_btn = ::UI::Button.new(ax_granted ? "Next →" : "Next (skip for now) →") {
      puts "[Wizard] Next clicked (step 0 → 1)"
      Scribe::Platform::MacOS::App.wizard_update_step(1)
      nil
    }
    next_btn.accessibility_label = ax_granted ? "Next step" : "Skip Accessibility and go to next step"
    if ax_granted
      next_btn.font = ::UI::Font.new(size: 15.0, weight: :regular)
      next_btn.key_equivalent = "\r"
    else
      next_btn.font = ::UI::Font.new(size: 13.0, weight: :regular)
    end

    nav_row = ::UI::HStack.new(spacing: 12.0)
    unless ax_granted
      skip_spacer = ::UI::Spacer.new
      nav_row << skip_spacer
    end
    nav_row << ::UI::Spacer.new
    nav_row << next_btn
    root << nav_row
  end

  private def self.build_login_step(root, primary, secondary, accent)
    icon = ::UI::Label.new("🚀")
    icon.font = ::UI::Font.new(size: 48.0, weight: :regular)
    icon.accessibility_label = "Rocket icon"
    root << icon

    title = ::UI::Label.new("Launch at Login")
    title.font = ::UI::Font.new(size: 22.0, weight: :regular)
    title.text_color = primary
    root << title

    desc = ::UI::Label.new(
      "Scribe works best when it starts automatically with your Mac. " \
      "Enable Launch at Login so Scribe is always ready in your menu bar."
    )
    desc.font = ::UI::Font.new(size: 13.0, weight: :regular)
    desc.text_color = secondary
    root << desc

    login_enabled = Scribe::Platform::MacOS::LibScribePlatform.scribe_launch_at_login_status == 1

    if login_enabled
      # Already enabled — show success
      check = ::UI::Label.new("✓ Launch at Login is enabled")
      check.font = ::UI::Font.new(size: 13.0, weight: :medium)
      check.text_color = Scribe::Platform::MacOS::SystemColors.system_green
      check.accessibility_label = "Launch at Login is enabled"
      root << check
    else
      enable_btn = ::UI::Button.new("Enable Launch at Login") {
        puts "[Wizard] Enable Launch at Login clicked"
        Scribe::Platform::MacOS::LibScribePlatform.scribe_launch_at_login_enable
        Scribe::Settings::Manager.set("launch_at_login", "true")
        # Refresh to show success state
        Scribe::Platform::MacOS::App.wizard_update_step(1)
        nil
      }
      enable_btn.font = ::UI::Font.new(size: 15.0, weight: :regular)
      enable_btn.key_equivalent = "\r"
      enable_btn.accessibility_label = "Enable Scribe to launch automatically at login"
      root << enable_btn
    end

    next_btn = ::UI::Button.new("Next →") {
      puts "[Wizard] Next clicked (step 1 → 2)"
      Scribe::Platform::MacOS::App.wizard_update_step(2)
      nil
    }
    next_btn.font = ::UI::Font.new(size: 15.0, weight: :regular)
    next_btn.key_equivalent = "\r"
    next_btn.accessibility_label = "Next step"

    nav_row = ::UI::HStack.new(spacing: 12.0)
    nav_row << ::UI::Spacer.new
    nav_row << next_btn
    root << nav_row
  end

  private def self.build_ready_step(root, primary, secondary, accent)
    icon = ::UI::Label.new("🎉")
    icon.font = ::UI::Font.new(size: 48.0, weight: :regular)
    icon.accessibility_label = "Celebration icon"
    root << icon

    title = ::UI::Label.new("You're All Set!")
    title.font = ::UI::Font.new(size: 22.0, weight: :regular)
    title.text_color = primary
    root << title

    shortcut = Scribe::Settings::Manager.shortcut_key.upcase.gsub("+", " + ")

    desc = ::UI::Label.new(
      "Scribe is running in your menu bar. Use the " \
      "keyboard shortcut below to start and stop " \
      "recording."
    )
    desc.font = ::UI::Font.new(size: 13.0, weight: :regular)
    desc.text_color = secondary
    root << desc

    shortcut_display = ::UI::Label.new(shortcut)
    shortcut_display.font = ::UI::Font.new(size: 22.0, weight: :semibold, family: "monospace")
    shortcut_display.text_color = accent
    shortcut_display.accessibility_label = "Keyboard shortcut: #{shortcut}"
    root << shortcut_display

    desc2 = ::UI::Label.new(
      "Your voice will be transcribed and pasted into " \
      "whatever app you're using. Change settings " \
      "anytime from the menu bar."
    )
    desc2.font = ::UI::Font.new(size: 13.0, weight: :regular)
    desc2.text_color = secondary
    root << desc2

    finish_btn = ::UI::Button.new("Start Using Scribe") {
      puts "[Wizard] Finish clicked"
      Scribe::Settings::Manager.set("wizard_completed", "true")
      Scribe::Platform::MacOS::App.wizard_finish
      nil
    }
    finish_btn.font = ::UI::Font.new(size: 15.0, weight: :regular)
    finish_btn.key_equivalent = "\r"
    finish_btn.accessibility_label = "Finish setup and start using Scribe"

    nav_row = ::UI::HStack.new(spacing: 12.0)
    nav_row << ::UI::Spacer.new
    nav_row << finish_btn
    root << nav_row
  end
end

{% end %}
