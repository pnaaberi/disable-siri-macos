#!/bin/zsh
set -eu

source "${0:A:h}/lib/state.sh"
dsm_require_macos

force=false
for argument in "$@"; do
  case "$argument" in
    --force) force=true ;;
    -h|--help)
      print "Usage: ${0:t} [--force]"
      exit 0
      ;;
    *)
      print -u2 "Unknown argument: $argument"
      exit 2
      ;;
  esac
done

dsm_warn_untested_version

if ! $force && ! dsm_touchbar_detected; then
  print -u2 "No active Touch Bar services were detected; no settings were changed."
  print -u2 "Use --force only after confirming this Mac physically has a Touch Bar."
  exit 1
fi

dsm_ensure_backup

typeset -a compact expanded
typeset current_snapshot=""
cleanup_current_snapshot() {
  if [[ -n "$current_snapshot" && -f "$current_snapshot" ]]; then
    /bin/rm -f -- "$current_snapshot"
  fi
}
trap cleanup_current_snapshot EXIT HUP INT TERM

current_snapshot=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/disable-siri-controlstrip.XXXXXX")
if ! /usr/bin/defaults export com.apple.controlstrip "$current_snapshot" >/dev/null 2>&1; then
  /bin/rm -f -- "$current_snapshot"
  current_snapshot=""
fi

if [[ -n "$current_snapshot" ]] &&
   /usr/bin/defaults read com.apple.controlstrip MiniCustomized >/dev/null 2>&1; then
  compact=(${(f)"$(dsm_plist_array "$current_snapshot" MiniCustomized)"})
  compact=("${(@)compact:#com.apple.system.siri}")
else
  compact=(
    "com.apple.system.brightness"
    "com.apple.system.volume"
    "com.apple.system.mute"
  )
fi

if [[ -n "$current_snapshot" ]] &&
   /usr/bin/defaults read com.apple.controlstrip FullCustomized >/dev/null 2>&1; then
  expanded=(${(f)"$(dsm_plist_array "$current_snapshot" FullCustomized)"})
  expanded=("${(@)expanded:#com.apple.system.siri}")
else
  expanded=(
    "com.apple.system.group.brightness"
    "com.apple.system.group.keyboard-brightness"
    "com.apple.system.mission-control"
    "com.apple.system.launchpad"
    "com.apple.system.group.media"
    "com.apple.system.group.volume"
  )
fi

[[ -z "$current_snapshot" ]] || /bin/rm -f -- "$current_snapshot"
current_snapshot=""

dsm_write_array_from_lines MiniCustomized "${compact[@]}"
dsm_write_array_from_lines FullCustomized "${expanded[@]}"

if /usr/bin/defaults read com.apple.controlstrip MiniCustomized | /usr/bin/grep -Fq com.apple.system.siri ||
   /usr/bin/defaults read com.apple.controlstrip FullCustomized | /usr/bin/grep -Fq com.apple.system.siri; then
  print -u2 "Failed to verify Siri removal from the Touch Bar."
  exit 1
fi

/usr/bin/killall ControlStrip 2>/dev/null || true
print "Siri removed from the compact and expanded Touch Bar Control Strip."
