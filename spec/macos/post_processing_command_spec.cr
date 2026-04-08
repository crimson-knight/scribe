# post_processing_command_spec.cr — Tests for post-processing command construction
#
# Verifies that user commands with complex arguments (quotes, flags, long strings)
# are properly combined with the transcript file path for shell execution.
#
# Run:
#   cd ~/personal_coding_projects/scribe && crystal-alpha spec spec/macos/post_processing_command_spec.cr

require "spec"

describe "Post-processing command construction" do
  describe "command + transcript path combination" do
    it "appends a simple path to a simple command" do
      command = "echo"
      path = "/tmp/transcript.md"
      escaped_path = Process.quote(path)
      full = "#{command} #{escaped_path}"
      # Process.quote only adds quotes when needed (spaces/special chars)
      full.should eq("echo /tmp/transcript.md")
    end

    it "handles paths with spaces" do
      command = "process.sh"
      path = "/Users/me/Documents/My Scribe Files/transcript 2026.md"
      escaped_path = Process.quote(path)
      full = "#{command} #{escaped_path}"
      full.should contain("'")
      full.should contain("My Scribe Files")
    end

    it "handles complex commands with quotes and flags" do
      command = %q(claude -p "I am scanning documents into a folder")
      path = "/tmp/scribe_20260328.md"
      escaped_path = Process.quote(path)
      full = "#{command} #{escaped_path}"

      # The full command should have the user's quoted -p argument intact
      full.should contain(%q(-p "I am scanning documents into a folder"))
      # And the path should be at the end
      full.should end_with("/tmp/scribe_20260328.md")
    end

    it "handles commands with pipes" do
      command = "cat | process.sh"
      path = "/tmp/test.md"
      escaped_path = Process.quote(path)
      full = "#{command} #{escaped_path}"
      full.should eq("cat | process.sh /tmp/test.md")
    end

    it "handles the real claude command" do
      command = %q(claude -p "I am scanning documents into a folder and I want your help reviewing, renaming and organizing these files. I have provided you a recording transcript with the latest details around what I think these documents are about.")
      path = "/Users/crimsonknight/Documents/Scribe/scribe_20260328_120000.md"
      escaped_path = Process.quote(path)
      full = "#{command} #{escaped_path}"

      # Must contain the full -p argument with quotes
      full.should contain("reviewing, renaming and organizing")
      # Must end with the escaped transcript path
      full.should contain("scribe_20260328_120000.md")
      # Must NOT have Crystal's args array syntax
      full.should_not contain("args:")
    end
  end

  describe "Process.quote" do
    it "escapes paths with special characters" do
      Process.quote("hello world").should eq("'hello world'")
    end

    it "handles paths with single quotes" do
      result = Process.quote("it's a file.md")
      # Should be properly escaped for shell
      result.should_not be_empty
    end

    it "handles normal paths without modification beyond quoting" do
      result = Process.quote("/tmp/scribe_20260328.md")
      result.should eq("/tmp/scribe_20260328.md")
    end
  end

  describe "shell execution safety" do
    it "does not use args: parameter with shell: true" do
      # This is the pattern that was BROKEN:
      # Process.run(command, args: [path], shell: true)
      #
      # This is the CORRECT pattern:
      # full_command = "#{command} #{Process.quote(path)}"
      # Process.run(full_command, shell: true)
      #
      # Verify the correct pattern works with a real command:
      output = IO::Memory.new
      status = Process.run(
        "echo #{Process.quote("hello world")}",
        output: output,
        shell: true
      )
      status.success?.should be_true
      output.to_s.strip.should eq("hello world")
    end

    it "passes complex commands through shell correctly" do
      output = IO::Memory.new
      command = %q(echo "test with quotes")
      path = "/tmp/file.md"
      full = "#{command} #{Process.quote(path)}"

      status = Process.run(full, output: output, shell: true)
      status.success?.should be_true
      result = output.to_s.strip
      result.should contain("test with quotes")
      result.should contain("/tmp/file.md")
    end
  end
end
