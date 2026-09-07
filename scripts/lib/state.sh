#!/bin/zsh

# Shared state and verification helpers. This file is sourced by the commands.

typeset -gr DSM_STATE_ROOT="${DISABLE_SIRI_STATE_ROOT:-${HOME}/Library/Application Support/disable-siri-macos}"
typeset -gr DSM_STATE_DIR="${DSM_STATE_ROOT}/state-v1"
typeset -gr DSM_STATE_META="${DSM_STATE_DIR}/metadata"
typeset -gr DSM_CONTROLSTRIP_SNAPSHOT="${DSM_STATE_DIR}/controlstrip.plist"
typeset -gr DSM_TESTED_MACOS_VERSION="13.7.8"
typeset -g DSM_PARTIAL_BACKUP=""

dsm_bool_word() {
  [[ "$1" == "1" ]] && print true || print false
}

dsm_cleanup_partial_backup() {
  if [[ -n "$DSM_PARTIAL_BACKUP" && -d "$DSM_PARTIAL_BACKUP" ]]; then
    /bin/rm -R -- "$DSM_PARTIAL_BACKUP"
  fi
}

dsm_require_macos() {
  if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
    print -u2 "This project supports macOS only."
    return 1
  fi
}

dsm_warn_untested_version() {
  local current
  current=$(/usr/bin/sw_vers -productVersion)
  if [[ "$current" != "$DSM_TESTED_MACOS_VERSION" && "${DSM_VERSION_WARNING_SHOWN:-0}" != "1" ]]; then
    print -u2 "Warning: tested on macOS $DSM_TESTED_MACOS_VERSION; this Mac runs $current."
    print -u2 "Apple's private preference keys may behave differently."
  fi
  export DSM_VERSION_WARNING_SHOWN=1
}

dsm_touchbar_detected() {
  /usr/bin/pgrep -qx TouchBarServer || /usr/bin/pgrep -qx ControlStrip
}

dsm_service_is_disabled() {
  /bin/launchctl print-disabled "gui/$(/usr/bin/id -u)" 2>/dev/null |
    /usr/bin/grep -Fq '"com.apple.Siri.agent" => disabled'
}

dsm_capture_bool() {
  local metadata="$1" domain="$2" key="$3" slot="$4" value

  if value=$(/usr/bin/defaults read "$domain" "$key" 2>/dev/null); then
    if [[ "$value" != "0" && "$value" != "1" ]]; then
      print -u2 "Cannot safely preserve $domain/$key: expected a Boolean, found '$value'."
      return 1
    fi
    /usr/bin/defaults write "$metadata" "${slot}_present" -bool true
    /usr/bin/defaults write "$metadata" "${slot}_value" -bool "$(dsm_bool_word "$value")"
  else
    /usr/bin/defaults write "$metadata" "${slot}_present" -bool false
  fi
}

dsm_ensure_backup() {
  if [[ -f "${DSM_STATE_META}.plist" ]]; then
    return 0
  fi

  if [[ -e "$DSM_STATE_DIR" ]]; then
    print -u2 "State path exists but is incomplete: $DSM_STATE_DIR"
    print -u2 "Move it aside manually after inspecting it; it will not be overwritten."
    return 1
  fi

  /bin/mkdir -p -m 700 "$DSM_STATE_ROOT"

  local temporary metadata
  temporary=$(/usr/bin/mktemp -d "${DSM_STATE_ROOT}/.state-v1.XXXXXX")
  DSM_PARTIAL_BACKUP="$temporary"
  trap dsm_cleanup_partial_backup EXIT HUP INT TERM
  metadata="${temporary}/metadata"

  /usr/bin/defaults write "$metadata" formatVersion -int 1
  /usr/bin/defaults write "$metadata" userID -int "$(/usr/bin/id -u)"
  /usr/bin/defaults write "$metadata" macOSVersion -string "$(/usr/bin/sw_vers -productVersion)"
  /usr/bin/defaults write "$metadata" hardwareModel -string "$(/usr/sbin/sysctl -n hw.model)"
  /usr/bin/defaults write "$metadata" siriAgentWasDisabled -bool \
    "$(dsm_service_is_disabled && print true || print false)"

  dsm_capture_bool "$metadata" com.apple.assistant.support "Assistant Enabled" assistant_enabled
  dsm_capture_bool "$metadata" com.apple.Siri StatusMenuVisible status_menu_visible
  dsm_capture_bool "$metadata" com.apple.Siri UserHasDeclinedEnable user_declined
  dsm_capture_bool "$metadata" com.apple.Siri VoiceTriggerUserEnabled voice_trigger
  dsm_capture_bool "$metadata" com.apple.Siri LockscreenEnabled lockscreen
  dsm_capture_bool "$metadata" com.apple.Siri SiriPrefStashedStatusMenuVisible stashed_menu_visible
  dsm_capture_bool "$metadata" com.apple.Siri SuggestionsEnabled suggestions

  if /usr/bin/defaults export com.apple.controlstrip "${temporary}/controlstrip.plist" >/dev/null 2>&1; then
    /usr/bin/defaults write "$metadata" controlstripSnapshotPresent -bool true
    /usr/bin/defaults write "$metadata" miniCustomizedPresent -bool \
      "$(/usr/bin/defaults read com.apple.controlstrip MiniCustomized >/dev/null 2>&1 && print true || print false)"
    /usr/bin/defaults write "$metadata" fullCustomizedPresent -bool \
      "$(/usr/bin/defaults read com.apple.controlstrip FullCustomized >/dev/null 2>&1 && print true || print false)"
  else
    /usr/bin/defaults write "$metadata" controlstripSnapshotPresent -bool false
    /usr/bin/defaults write "$metadata" miniCustomizedPresent -bool false
    /usr/bin/defaults write "$metadata" fullCustomizedPresent -bool false
  fi

  /bin/chmod -R go-rwx "$temporary"
  /bin/mv "$temporary" "$DSM_STATE_DIR"
  DSM_PARTIAL_BACKUP=""
  print "Saved original state to: $DSM_STATE_DIR"
}

dsm_write_bool() {
  local domain="$1" key="$2"
  /usr/bin/defaults write "$domain" "$key" -bool false
  [[ "$(/usr/bin/defaults read "$domain" "$key" 2>/dev/null)" == "0" ]] || {
    print -u2 "Failed to verify $domain/$key."
    return 1
  }
}

dsm_restore_bool() {
  local domain="$1" key="$2" slot="$3" present value actual
  present=$(/usr/bin/defaults read "$DSM_STATE_META" "${slot}_present")

  if [[ "$present" == "1" ]]; then
    value=$(/usr/bin/defaults read "$DSM_STATE_META" "${slot}_value")
    /usr/bin/defaults write "$domain" "$key" -bool "$(dsm_bool_word "$value")"
    actual=$(/usr/bin/defaults read "$domain" "$key" 2>/dev/null)
    [[ "$actual" == "$value" ]] || {
      print -u2 "Failed to verify restoration of $domain/$key."
      return 1
    }
  else
    /usr/bin/defaults delete "$domain" "$key" 2>/dev/null || true
    if /usr/bin/defaults read "$domain" "$key" >/dev/null 2>&1; then
      print -u2 "Failed to verify removal of previously absent $domain/$key."
      return 1
    fi
  fi
}

dsm_plist_array() {
  local plist="$1" key="$2" line
  typeset -a output
  output=(${(f)"$(/usr/libexec/PlistBuddy -c "Print :${key}" "$plist")"})

  for line in "${output[@]}"; do
    [[ "$line" == "Array {" || "$line" == "}" || "$line" == "Array {}" ]] && continue
    line="${line#    }"
    if [[ -z "$line" || "$line" == *$'\n'* ]]; then
      print -u2 "Cannot safely parse saved Touch Bar item."
      return 1
    fi
    print -r -- "$line"
  done
}

dsm_write_array_from_lines() {
  local key="$1"; shift
  typeset -a values
  values=("$@")
  /usr/bin/defaults write com.apple.controlstrip "$key" -array "${values[@]}"
  dsm_array_matches "$key" "${values[@]}" || {
    print -u2 "Failed to verify com.apple.controlstrip/$key."
    return 1
  }
}

dsm_array_matches() {
  local key="$1" temporary index; shift
  typeset -a expected actual
  expected=("$@")
  temporary=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/disable-siri-array.XXXXXX")

  if ! /usr/bin/defaults export com.apple.controlstrip "$temporary" >/dev/null 2>&1; then
    /bin/rm -f -- "$temporary"
    return 1
  fi
  actual=(${(f)"$(dsm_plist_array "$temporary" "$key")"})
  /bin/rm -f -- "$temporary"

  (( ${#actual[@]} == ${#expected[@]} )) || return 1
  for (( index = 1; index <= ${#expected[@]}; index++ )); do
    [[ "${actual[$index]}" == "${expected[$index]}" ]] || return 1
  done
}

dsm_restore_touchbar_array() {
  local key="$1" presence_key="$2" present
  typeset -a items
  present=$(/usr/bin/defaults read "$DSM_STATE_META" "$presence_key")

  if [[ "$present" == "1" ]]; then
    items=(${(f)"$(dsm_plist_array "$DSM_CONTROLSTRIP_SNAPSHOT" "$key")"})
    dsm_write_array_from_lines "$key" "${items[@]}"
  else
    /usr/bin/defaults delete com.apple.controlstrip "$key" 2>/dev/null || true
  fi
}
