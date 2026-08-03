#!/bin/zsh
set -eu

test_root=$(/usr/bin/mktemp -d /tmp/disable-siri-tests.XXXXXX)
trap '/bin/rm -R -- "$test_root"' EXIT HUP INT TERM
export DISABLE_SIRI_STATE_ROOT="$test_root/state"

root="${0:A:h:h}"
source "$root/scripts/lib/state.sh"
/bin/mkdir -p "$DSM_STATE_DIR"

source_domain="$test_root/source"
/usr/bin/defaults write "$source_domain" Existing -bool true
dsm_capture_bool "$DSM_STATE_META" "$source_domain" Existing existing
dsm_capture_bool "$DSM_STATE_META" "$source_domain" Missing missing

/usr/bin/defaults write "$source_domain" Existing -bool false
/usr/bin/defaults write "$source_domain" Missing -bool true
dsm_restore_bool "$source_domain" Existing existing
dsm_restore_bool "$source_domain" Missing missing

[[ "$(/usr/bin/defaults read "$source_domain" Existing)" == "1" ]]
if /usr/bin/defaults read "$source_domain" Missing >/dev/null 2>&1; then
  print -u2 "Previously absent Boolean was not removed"
  exit 1
fi

array_plist="$test_root/arrays"
/usr/bin/defaults write "$array_plist" Example -array \
  com.apple.system.volume \
  com.apple.system.siri \
  com.example.third-party

typeset -a items
items=(${(f)"$(dsm_plist_array "${array_plist}.plist" Example)"})
items=("${(@)items:#com.apple.system.siri}")

[[ ${#items[@]} == 2 ]]
[[ "${items[1]}" == com.apple.system.volume ]]
[[ "${items[2]}" == com.example.third-party ]]

/usr/bin/defaults write "$array_plist" Empty -array
items=(${(f)"$(dsm_plist_array "${array_plist}.plist" Empty)"})
[[ ${#items[@]} == 0 ]]

print "State-helper checks passed."
