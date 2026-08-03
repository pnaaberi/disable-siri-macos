#!/bin/zsh
set -eu

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script supports macOS only."
  exit 1
fi

# Replace the compact Control Strip with a useful set that omits com.apple.Siri.
defaults write com.apple.controlstrip MiniCustomized -array \
  "com.apple.system.brightness" \
  "com.apple.system.volume" \
  "com.apple.system.mute"

# Define the expanded Control Strip too; otherwise macOS can retain its default
# expanded layout, which includes Siri on some Touch Bar models/macOS versions.
defaults write com.apple.controlstrip FullCustomized -array \
  "com.apple.system.group.brightness" \
  "com.apple.system.group.keyboard-brightness" \
  "com.apple.system.mission-control" \
  "com.apple.system.launchpad" \
  "com.apple.system.group.media" \
  "com.apple.system.group.volume"

killall ControlStrip 2>/dev/null || true
print "Siri removed from the compact and expanded Touch Bar Control Strip."
