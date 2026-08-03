#!/bin/zsh
set -eu

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script supports macOS only."
  exit 1
fi

delete_default() {
  defaults delete "$1" "$2" 2>/dev/null || true
}

delete_default com.apple.assistant.support "Assistant Enabled"
delete_default com.apple.Siri StatusMenuVisible
delete_default com.apple.Siri UserHasDeclinedEnable
delete_default com.apple.Siri VoiceTriggerUserEnabled
delete_default com.apple.Siri LockscreenEnabled
delete_default com.apple.Siri SiriPrefStashedStatusMenuVisible
delete_default com.apple.Siri SuggestionsEnabled
delete_default com.apple.controlstrip MiniCustomized
delete_default com.apple.controlstrip FullCustomized

launchctl enable "gui/$(id -u)/com.apple.Siri.agent" 2>/dev/null || true
killall ControlStrip 2>/dev/null || true

print "Project overrides removed. Configure Siri in System Settings if desired."
