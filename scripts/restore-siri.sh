#!/bin/zsh
set -eu

source "${0:A:h}/lib/state.sh"
dsm_require_macos

if (( $# > 0 )); then
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    print "Usage: ${0:t}"
    print "Restores the exact state captured by the first disable operation."
    exit 0
  fi
  print -u2 "Unknown argument: $1"
  exit 2
fi

if [[ ! -f "${DSM_STATE_META}.plist" ]]; then
  print -u2 "No saved state was found at: $DSM_STATE_DIR"
  print -u2 "Nothing was changed."
  exit 1
fi

if [[ "$(/usr/bin/defaults read "$DSM_STATE_META" userID)" != "$(/usr/bin/id -u)" ]]; then
  print -u2 "Saved state belongs to a different user ID; nothing was changed."
  exit 1
fi

dsm_restore_bool com.apple.assistant.support "Assistant Enabled" assistant_enabled
dsm_restore_bool com.apple.Siri StatusMenuVisible status_menu_visible
dsm_restore_bool com.apple.Siri UserHasDeclinedEnable user_declined
dsm_restore_bool com.apple.Siri VoiceTriggerUserEnabled voice_trigger
dsm_restore_bool com.apple.Siri LockscreenEnabled lockscreen
dsm_restore_bool com.apple.Siri SiriPrefStashedStatusMenuVisible stashed_menu_visible
dsm_restore_bool com.apple.Siri SuggestionsEnabled suggestions

if [[ "$(/usr/bin/defaults read "$DSM_STATE_META" controlstripSnapshotPresent)" == "1" ]]; then
  dsm_restore_touchbar_array MiniCustomized miniCustomizedPresent
  dsm_restore_touchbar_array FullCustomized fullCustomizedPresent
fi

if [[ "$(/usr/bin/defaults read "$DSM_STATE_META" siriAgentWasDisabled)" == "1" ]]; then
  /bin/launchctl disable "gui/$(/usr/bin/id -u)/com.apple.Siri.agent"
  if ! dsm_service_is_disabled; then
    print -u2 "Failed to restore the disabled Siri agent state."
    exit 1
  fi
else
  /bin/launchctl enable "gui/$(/usr/bin/id -u)/com.apple.Siri.agent"
  if dsm_service_is_disabled; then
    print -u2 "Failed to restore the enabled/default Siri agent state."
    exit 1
  fi
fi

/usr/bin/killall Siri 2>/dev/null || true
/usr/bin/killall ControlStrip 2>/dev/null || true

archive="${DSM_STATE_ROOT}/restored-$(/bin/date +%Y%m%d-%H%M%S)-$$"
/bin/mv "$DSM_STATE_DIR" "$archive"
print "Restored the captured user state. Backup archived at: $archive"
