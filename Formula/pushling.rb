# Formula/pushling.rb — Homebrew cask formula for Pushling
# Install: brew install --cask pushling
#
# This installs:
#   - Pushling.app to /Applications
#   - LaunchAgent plist for auto-start
#   - pushling CLI to bin path
#   - MCP server to ~/.pushling/mcp
#
# Minimum macOS: 12.0 (Monterey)
# Touch Bar: 2016-2020 MacBook Pro

cask "pushling" do
  version "1.0.0"
  sha256 "TO_BE_COMPUTED"

  url "https://github.com/pushling/pushling/releases/download/v#{version}/Pushling-#{version}.dmg"
  name "Pushling"
  desc "Touch Bar virtual pet — a spirit creature born from your git history"
  homepage "https://github.com/pushling/pushling"

  depends_on macos: ">= :monterey"

  app "Pushling.app"

  # Install CLI tool
  binary "#{appdir}/Pushling.app/Contents/Resources/bin/pushling"

  # Install MCP server
  artifact "#{appdir}/Pushling.app/Contents/Resources/mcp",
           target: "#{Dir.home}/.pushling/mcp"

  preflight do
    # Stop existing daemon if running
    system_command "/bin/launchctl",
                   args: ["unload", "#{Dir.home}/Library/LaunchAgents/com.pushling.daemon.plist"],
                   sudo: false,
                   print_stderr: false
  end

  postflight do
    # Create data directories
    system_command "/bin/mkdir",
                   args: ["-p",
                          "#{Dir.home}/.local/share/pushling",
                          "#{Dir.home}/.local/share/pushling/feed",
                          "#{Dir.home}/.local/share/pushling/voice",
                          "#{Dir.home}/.local/share/pushling/backups",
                          "#{Dir.home}/.pushling/hooks"]

    # Install LaunchAgent plist
    plist_path = "#{Dir.home}/Library/LaunchAgents/com.pushling.daemon.plist"
    File.write(plist_path, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.pushling.daemon</string>
        <key>ProgramArguments</key>
        <array>
          <string>/Applications/Pushling.app/Contents/MacOS/Pushling</string>
        </array>
        <key>KeepAlive</key>
        <true/>
        <key>RunAtLoad</key>
        <true/>
        <key>ProcessType</key>
        <string>Background</string>
        <key>StandardOutPath</key>
        <string>#{Dir.home}/Library/Logs/Pushling/pushling.log</string>
        <key>StandardErrorPath</key>
        <string>#{Dir.home}/Library/Logs/Pushling/pushling.error.log</string>
      </dict>
      </plist>
    PLIST

    # Ensure log directory exists
    system_command "/bin/mkdir",
                   args: ["-p", "#{Dir.home}/Library/Logs/Pushling"]

    # Load LaunchAgent
    system_command "/bin/launchctl",
                   args: ["load", plist_path],
                   sudo: false
  end

  uninstall launchctl: "com.pushling.daemon",
            delete:    "#{Dir.home}/Library/LaunchAgents/com.pushling.daemon.plist"

  zap trash: [
    "#{Dir.home}/.pushling",
    "#{Dir.home}/Library/Logs/Pushling"
  ]

  # Note: ~/.local/share/pushling is NOT removed on uninstall
  # (creature state preserved). Use `pushling uninstall --purge` to remove.

  caveats <<~EOS
    Pushling has been installed and is running!

    To track a git repository:
      pushling track /path/to/repo

    To install Claude Code hooks:
      pushling hooks install

    To check status:
      pushling status

    Your creature's state is stored at:
      ~/.local/share/pushling/state.db

    This data is preserved on uninstall. To remove it:
      rm -rf ~/.local/share/pushling
  EOS
end
