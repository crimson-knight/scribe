{% if flag?(:macos) %}

module Scribe::UI::AboutView
  VERSION = "1.0.0"

  def self.build : ::UI::VStack
    primary = Scribe::Platform::MacOS::SystemColors.label
    secondary = Scribe::Platform::MacOS::SystemColors.secondary_label
    accent = Scribe::Platform::MacOS::SystemColors.accent

    root = ::UI::VStack.new(spacing: 12.0)

    # App icon
    icon = ::UI::Label.new("🎙")
    icon.font = ::UI::Font.new(size: 64.0, weight: :regular)
    icon.accessibility_label = "Scribe application icon"
    root << icon

    # App name
    name_label = ::UI::Label.new("Scribe")
    name_label.font = ::UI::Font.new(size: 26.0, weight: :bold)
    name_label.text_color = primary
    name_label.accessibility_label = "Scribe"
    root << name_label

    # Version
    version_label = ::UI::Label.new("Version #{VERSION}")
    version_label.font = ::UI::Font.new(size: 13.0, weight: :regular)
    version_label.text_color = secondary
    root << version_label

    # Description
    desc = ::UI::Label.new(
      "Free, simple voice dictation and transcription. " \
      "Available to anyone."
    )
    desc.font = ::UI::Font.new(size: 13.0, weight: :regular)
    desc.text_color = secondary
    root << desc

    root << ::UI::Spacer.new
    root << ::UI::Divider.new

    # Built with
    built_with = ::UI::Label.new("Built with Crystal and Amber")
    built_with.font = ::UI::Font.new(size: 11.0, weight: :regular)
    built_with.text_color = secondary
    root << built_with

    crystal_link_btn = ::UI::Button.new("crystal-lang.org") {
      Scribe::Platform::MacOS::LibScribePlatform.scribe_open_url("https://crystal-lang.org".to_unsafe)
      nil
    }
    crystal_link_btn.accessibility_label = "Open crystal-lang.org in browser"
    root << crystal_link_btn

    amber_link_btn = ::UI::Button.new("amberframework.org") {
      Scribe::Platform::MacOS::LibScribePlatform.scribe_open_url("https://amberframework.org".to_unsafe)
      nil
    }
    amber_link_btn.accessibility_label = "Open amberframework.org in browser"
    root << amber_link_btn

    root << ::UI::Divider.new

    # Developer
    dev_label = ::UI::Label.new("AgentC Consulting LLC")
    dev_label.font = ::UI::Font.new(size: 11.0, weight: :semibold)
    dev_label.text_color = primary
    root << dev_label

    website_link_btn = ::UI::Button.new("agentc.consulting") {
      Scribe::Platform::MacOS::LibScribePlatform.scribe_open_url("https://agentc.consulting".to_unsafe)
      nil
    }
    website_link_btn.accessibility_label = "Open agentc.consulting in browser"
    root << website_link_btn

    support_label = ::UI::Label.new("Support: st@agentc.consulting")
    support_label.font = ::UI::Font.new(size: 11.0, weight: :regular)
    support_label.text_color = secondary
    support_label.accessibility_label = "Support email: st at agentc dot consulting"
    root << support_label

    # Copyright
    year = Time.local.year
    copyright = ::UI::Label.new("© #{year} AgentC Consulting LLC")
    copyright.font = ::UI::Font.new(size: 10.0, weight: :regular)
    copyright.text_color = secondary
    root << copyright

    root
  end
end

{% end %}
