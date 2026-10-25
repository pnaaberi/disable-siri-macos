#!/bin/zsh
set -eu

# Runs backup -> Touch Bar removal -> restore against stubbed macOS commands.
# Real preferences, launch agents and processes are never touched, so this
# runs on macOS and, with zsh and python3 installed, on Linux.

root="${0:A:h:h}"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/disable-siri-touchbar.XXXXXX")
trap 'rm -R -- "$test_root"' EXIT HUP INT TERM

stub="$test_root/stub-tools"
mkdir -p "$stub"
cp "$root"/tests/stubs/* "$stub/"
for tool in chmod date grep id mkdir mktemp mv rm; do
  ln -s "$(command -v "$tool")" "$stub/$tool"
done

# Point every absolute command path in a copy of the scripts at the stubs.
mkdir -p "$test_root/scripts/lib"
for file in scripts/*.sh scripts/lib/*.sh; do
  sed -e "s#/usr/libexec/#$stub/#g" -e "s#/usr/sbin/#$stub/#g" \
      -e "s#/usr/bin/#$stub/#g" -e "s#/bin/#$stub/#g" \
      "$root/$file" > "$test_root/$file"
done

fail() {
  print -u2 "FAIL: $1"
  exit 1
}

reset_state() {
  rm -Rf -- "$test_root/home" "$test_root/store"
  mkdir -p "$test_root/home" "$test_root/store"
  export HOME="$test_root/home"
  export DSM_STUB_STORE="$test_root/store"
  export DISABLE_SIRI_STATE_ROOT="$test_root/home/state"
  unset DSM_STUB_EXPORT_FAIL
  "$stub/defaults" write com.example.unrelated Keep -string untouched
}

run() {
  zsh "$test_root/scripts/$1" "${@:2}" >/dev/null
}

defaults_has() {
  "$stub/defaults" read "$@" >/dev/null 2>&1
}

assert_unrelated_untouched() {
  [[ "$("$stub/defaults" read com.example.unrelated Keep)" == untouched ]] || fail "unrelated preference changed"
}

# 1. Originally absent com.apple.controlstrip domain.
reset_state
run remove-siri-touchbar-button.sh
defaults_has com.apple.controlstrip MiniCustomized || fail "removal did not create MiniCustomized"
defaults_has com.apple.controlstrip FullCustomized || fail "removal did not create FullCustomized"
run restore-siri.sh
defaults_has com.apple.controlstrip MiniCustomized && fail "restore kept created MiniCustomized"
defaults_has com.apple.controlstrip FullCustomized && fail "restore kept created FullCustomized"
defaults_has com.apple.controlstrip && fail "restore left the originally absent domain behind"
assert_unrelated_untouched
[[ -n "$(print -l "$DISABLE_SIRI_STATE_ROOT"/restored-*(N))" ]] || fail "backup was not archived"

# 2. Existing domain: compact array restored exactly, absent expanded array removed,
#    other keys in the domain kept.
reset_state
"$stub/defaults" write com.apple.controlstrip MiniCustomized -array \
  com.apple.system.volume com.apple.system.siri com.example.third-party
"$stub/defaults" write com.apple.controlstrip OtherKey -string kept
run remove-siri-touchbar-button.sh
"$stub/defaults" read com.apple.controlstrip MiniCustomized | grep -Fq com.apple.system.siri && fail "Siri not removed"
run restore-siri.sh
[[ "$("$stub/defaults" read com.apple.controlstrip MiniCustomized)" == \
   "$(print -l '(' '    com.apple.system.volume,' '    com.apple.system.siri,' '    com.example.third-party' ')')" ]] ||
  fail "MiniCustomized not restored exactly"
defaults_has com.apple.controlstrip FullCustomized && fail "restore kept created FullCustomized"
[[ "$("$stub/defaults" read com.apple.controlstrip OtherKey)" == kept ]] || fail "other controlstrip key changed"
assert_unrelated_untouched

# 3. A domain that exists but cannot be exported is an error, not "absent":
#    nothing may change and no backup may be recorded.
reset_state
"$stub/defaults" write com.apple.controlstrip MiniCustomized -array com.apple.system.siri
export DSM_STUB_EXPORT_FAIL=com.apple.controlstrip
if run remove-siri-touchbar-button.sh 2>/dev/null; then
  fail "removal continued after an unexpected export failure"
fi
[[ ! -e "$DISABLE_SIRI_STATE_ROOT/state-v1" ]] || fail "backup recorded after export failure"
"$stub/defaults" read com.apple.controlstrip MiniCustomized | grep -Fq com.apple.system.siri || fail "settings changed after export failure"

print "Touch Bar backup/remove/restore checks passed."
