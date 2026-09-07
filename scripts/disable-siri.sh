#!/bin/zsh
set -eu

source "${0:A:h}/lib/state.sh"
dsm_require_macos

touch_bar=false
force_touch_bar=false

for argument in "$@"; do
  case "$argument" in
    --touch-bar) touch_bar=true ;;
    --no-touch-bar) touch_bar=false ;;
    --force-touch-bar) touch_bar=true; force_touch_bar=true ;;
    -h|--help)
      print "Usage: ${0:t} [--touch-bar] [--force-touch-bar]"
      print "  Default: disable Siri without changing Touch Bar preferences."
      exit 0
      ;;
    *)
      print -u2 "Unknown argument: $argument"
      print -u2 "Run ${0:t} --help for usage."
      exit 2
      ;;
  esac
done

dsm_warn_untested_version

if $touch_bar && ! $force_touch_bar && ! dsm_touchbar_detected; then
  print -u2 "No active Touch Bar services were detected."
  print -u2 "No settings were changed. Use --force-touch-bar only after confirming the hardware."
  exit 1
fi

dsm_ensure_backup

dsm_write_bool com.apple.assistant.support "Assistant Enabled"
dsm_write_bool com.apple.Siri StatusMenuVisible
/usr/bin/defaults write com.apple.Siri UserHasDeclinedEnable -bool true
[[ "$(/usr/bin/defaults read com.apple.Siri UserHasDeclinedEnable)" == "1" ]]
dsm_write_bool com.apple.Siri VoiceTriggerUserEnabled
dsm_write_bool com.apple.Siri LockscreenEnabled
dsm_write_bool com.apple.Siri SiriPrefStashedStatusMenuVisible
dsm_write_bool com.apple.Siri SuggestionsEnabled

/bin/launchctl disable "gui/$(/usr/bin/id -u)/com.apple.Siri.agent"
if ! dsm_service_is_disabled; then
  print -u2 "Failed to verify that com.apple.Siri.agent is disabled."
  exit 1
fi
/usr/bin/killall Siri 2>/dev/null || true

if $touch_bar; then
  if $force_touch_bar; then
    "${0:A:h}/remove-siri-touchbar-button.sh" --force
  else
    "${0:A:h}/remove-siri-touchbar-button.sh"
  fi
fi

print "Siri disabled for user $(/usr/bin/id -un)."
