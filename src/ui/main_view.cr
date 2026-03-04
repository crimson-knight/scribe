module Scribe::UI::MainView
  @@capture : Scribe::ProcessManagers::StartAudioCapture? = nil

  def self.build : ::UI::VStack
    output_dir = ENV["SCRIBE_OUTPUT_DIR"]? || "/tmp"
    @@capture = Scribe::ProcessManagers::StartAudioCapture.new(output_directory: output_dir)

    root = ::UI::VStack.new(spacing: 16.0)

    # Title
    title = ::UI::Label.new("Scribe")
    title.font = ::UI::Font.new(size: 28.0, weight: :bold)
    title.text_color = ::UI::Color.new(0.1, 0.1, 0.1, 1.0)
    root << title

    # Status indicator
    status = ::UI::Label.new("Status: Idle")
    status.font = ::UI::Font.new(size: 14.0, weight: :regular)
    status.text_color = ::UI::Color.new(0.3, 0.7, 0.3, 1.0)
    root << status

    # Output directory
    dir_label = ::UI::Label.new("Output: #{output_dir}")
    dir_label.font = ::UI::Font.new(size: 11.0, weight: :regular)
    dir_label.text_color = ::UI::Color.new(0.4, 0.4, 0.4, 1.0)
    root << dir_label

    # Spacer
    root << ::UI::Spacer.new

    # Record button — toggles recording on/off
    record_btn = ::UI::Button.new("Record") do
      if cap = @@capture
        if cap.recording?
          cap.stop
          puts "[Scribe] Recording stopped"
        else
          cap.perform
          puts "[Scribe] Recording started"
        end
      end
    end
    record_btn.font = ::UI::Font.new(size: 18.0, weight: :semibold)
    root << record_btn

    # Shortcut hint
    hint = ::UI::Label.new("Press Option+Shift+R to record (coming soon)")
    hint.font = ::UI::Font.new(size: 12.0, weight: :light)
    hint.text_color = ::UI::Color.new(0.5, 0.5, 0.5, 1.0)
    root << hint

    root
  end
end
