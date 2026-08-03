#!/bin/zsh
set -eu

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script supports macOS only."
  exit 1
fi

defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true
defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
defaults write com.apple.Siri LockscreenEnabled -bool false
defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false
defaults write com.apple.Siri SuggestionsEnabled -bool false

launchctl disable "gui/$(id -u)/com.apple.Siri.agent" 2>/dev/null || true
killall Siri 2>/dev/null || true

if [[ "${1:-}" != "--no-touch-bar" ]]; then
  "${0:A:h}/remove-siri-touchbar-button.sh"
fi

print "Siri disabled for user $(id -un)."
