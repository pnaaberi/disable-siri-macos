#!/bin/zsh
set -eu

root="${0:A:h:h}"

/bin/zsh -n "$root"/scripts/*.sh "$root"/scripts/lib/*.sh

"$root/scripts/disable-siri.sh" --help >/dev/null
"$root/scripts/remove-siri-touchbar-button.sh" --help >/dev/null
"$root/scripts/restore-siri.sh" --help >/dev/null

if "$root/scripts/disable-siri.sh" --not-a-real-option >/dev/null 2>&1; then
  print -u2 "disable-siri.sh accepted an unknown option"
  exit 1
fi

if "$root/scripts/remove-siri-touchbar-button.sh" --not-a-real-option >/dev/null 2>&1; then
  print -u2 "remove-siri-touchbar-button.sh accepted an unknown option"
  exit 1
fi

if "$root/scripts/restore-siri.sh" --not-a-real-option >/dev/null 2>&1; then
  print -u2 "restore-siri.sh accepted an unknown option"
  exit 1
fi

print "CLI checks passed."
