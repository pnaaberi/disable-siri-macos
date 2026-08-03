# Disable Siri on macOS

A small, auditable set of shell scripts that disables Siri for the current macOS user and, when explicitly requested, removes the Siri button from a MacBook Pro Touch Bar.

The scripts do not use `sudo`, delete Apple files, disable System Integrity Protection, or modify the sealed system volume. Before the first change, they save the affected preferences and Siri launch-agent state in a private per-user backup.

## Compatibility

### Who this is for

- **Siri disabling:** Macs running macOS. The preference keys are version-dependent, so check the tested version below.
- **Touch Bar button removal:** **MacBook Pro computers with a physical Touch Bar only.** It does not apply to MacBook Air, iMac, Mac mini, Mac Studio, Mac Pro, or MacBook Pro models with physical function keys instead of a Touch Bar.
- Having a MacBook Pro is not enough by itself: Apple sold models both with and without Touch Bar. Check for the narrow touch-sensitive display above the number keys.

The Touch Bar portion was verified on a **15-inch 2017 MacBook Pro** (`MacBookPro14,3`) with a quad-core Intel Core i7 and Touch Bar, running macOS Ventura 13.7.8. This is the tested configuration, not a claim that every Touch Bar model or macOS release behaves identically. No serial number or other unique machine identifier is published.

Apple may rename preferences or change their behavior in later macOS releases. Review [AUDIT.md](AUDIT.md) before using this on another version. The commands print a warning when the macOS version differs from the tested version. The script makes no Touch Bar changes unless `--touch-bar` is passed.

## Quick start

Open Terminal and run:

```sh
git clone https://github.com/pnaaberi/disable-siri-macos.git
cd disable-siri-macos
./scripts/disable-siri.sh --touch-bar
```

The script disables Siri, voice activation, lock-screen Siri, Siri suggestions, and the menu-bar item. With `--touch-bar`, it first verifies that Touch Bar services are active, then removes only the Siri item from existing compact and expanded Control Strip customizations. If no custom layout exists, it installs a conservative Siri-free layout. The original state is retained for rollback.

Log out and back in if a System Settings screen does not immediately reflect the change.

## Undo

```sh
./scripts/restore-siri.sh
```

This restores each affected preference, both Touch Bar arrays, and the Siri launch-agent override to the values captured before the first change. If a preference did not previously exist, it is deleted. The used snapshot is then archived rather than deleted.

## Run only one part

Disable Siri without changing Touch Bar settings—the safe default:

```sh
./scripts/disable-siri.sh
```

Remove only the Siri Touch Bar button:

```sh
./scripts/remove-siri-touchbar-button.sh
```

If the Mac physically has a Touch Bar but its services are not currently detectable, inspect the machine first and then use `--force-touch-bar` with the main script, or `--force` with the Touch Bar-only script. These flags bypass detection; they do not bypass backups or verification.

## Saved state

The first operation saves state under:

```text
~/Library/Application Support/disable-siri-macos/state-v1
```

Repeated disable operations reuse this snapshot and never overwrite it. Touch Bar filtering operates on the current layout each time, so buttons added after the first run are preserved while Siri is removed. After restoration the original snapshot is renamed with a `restored-YYYYMMDD-HHMMSS-PID` prefix, allowing a future operation to capture a fresh baseline. The directory is accessible only to the current user.

## Notes for automation agents

Treat this as an explicit user-setting change:

1. Confirm the host is macOS and identify its version with `sw_vers`.
2. Do not pass `--touch-bar` unless the user asked to modify Touch Bar settings.
3. Before applying Touch Bar settings, confirm the computer has a physical Touch Bar; do not infer this merely from “MacBook Pro.”
4. Explain that “permanent” cannot be guaranteed across major macOS updates.
5. Run as the signed-in desktop user, without `sudo`.
6. Do not kill or delete protected system components. A root-owned `siriinferenced` process may remain; its presence does not mean the Siri assistant is enabled.
7. Preserve the state directory: it is required for exact rollback. Never overwrite or delete it automatically.
8. Verify preference values and `launchctl print-disabled gui/$(id -u)` after execution.
9. Offer `restore-siri.sh` as the rollback path.

## Security

Read the scripts before running them. External commands use explicit system paths to reduce dependence on the caller's `PATH`. State files are created with user-only permissions. See [AUDIT.md](AUDIT.md) for each change and its impact.

## License

MIT
