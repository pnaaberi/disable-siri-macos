# Disable Siri on macOS

A small, auditable set of shell scripts that disables Siri for the current macOS user and removes the Siri button from the Touch Bar Control Strip.

The scripts do not use `sudo`, delete Apple files, disable System Integrity Protection, or modify the sealed system volume. Every change is reversible.

## Compatibility

### Who this is for

- **Siri disabling:** Macs running macOS. The preference keys are version-dependent, so check the tested version below.
- **Touch Bar button removal:** **MacBook Pro computers with a physical Touch Bar only.** It does not apply to MacBook Air, iMac, Mac mini, Mac Studio, Mac Pro, or MacBook Pro models with physical function keys instead of a Touch Bar.
- Having a MacBook Pro is not enough by itself: Apple sold models both with and without Touch Bar. Check for the narrow touch-sensitive display above the number keys.

The Touch Bar portion was verified on a **15-inch 2017 MacBook Pro** (`MacBookPro14,3`) with a quad-core Intel Core i7 and Touch Bar, running macOS Ventura 13.7.8. This is the tested configuration, not a claim that every Touch Bar model or macOS release behaves identically. No serial number or other unique machine identifier is published.

Apple may rename preferences or change their behavior in later macOS releases. Review [AUDIT.md](AUDIT.md) before using this on another version. On a Mac without Touch Bar, use `./scripts/disable-siri.sh --no-touch-bar`.

## Quick start

Open Terminal and run:

```sh
git clone https://github.com/pnaaberi/disable-siri-macos.git
cd disable-siri-macos
./scripts/disable-siri.sh
```

The script disables Siri, voice activation, lock-screen Siri, Siri suggestions, and the menu-bar item. On Touch Bar Macs it also replaces both the compact and expanded Control Strip layouts with useful controls that omit Siri.

Log out and back in if a System Settings screen does not immediately reflect the change.

## Undo

```sh
./scripts/restore-siri.sh
```

This removes the preferences written by the disabling script and re-enables the Siri launch agent. macOS then returns to its defaults; you can choose your preferred Siri and Touch Bar settings in System Settings.

## Run only one part

Disable Siri without changing the Touch Bar:

```sh
./scripts/disable-siri.sh --no-touch-bar
```

Remove only the Siri Touch Bar button:

```sh
./scripts/remove-siri-touchbar-button.sh
```

## Notes for automation agents

Treat this as an explicit user-setting change:

1. Confirm the host is macOS and identify its version with `sw_vers`.
2. Before applying Touch Bar settings, confirm the computer has a physical Touch Bar; do not infer this merely from “MacBook Pro.”
3. On a Mac without Touch Bar, pass `--no-touch-bar`.
4. Explain that “permanent” cannot be guaranteed across major macOS updates.
5. Run as the signed-in desktop user, without `sudo`.
6. Do not kill or delete protected system components. A root-owned `siriinferenced` process may remain; its presence does not mean the Siri assistant is enabled.
7. Verify preference values and `launchctl print-disabled gui/$(id -u)` after execution.
8. Offer `restore-siri.sh` as the rollback path.

## Security

Read the scripts before running them. They use only `/usr/bin/defaults`, `/bin/launchctl`, `/usr/bin/killall`, and standard shell built-ins. See [AUDIT.md](AUDIT.md) for each change and its impact.

## License

MIT
