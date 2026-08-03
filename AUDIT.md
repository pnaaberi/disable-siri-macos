# Audit notes

## Threat and safety model

This project changes preferences for the current user. It does not attempt to remove Siri binaries: macOS system files are protected, deletion would be brittle, and Siri frameworks can be shared by features such as dictation and system intelligence.

The scripts intentionally avoid:

- `sudo` and root writes
- disabling System Integrity Protection
- deleting files or unloading unrelated Apple services
- network access, downloads, telemetry, and persistence mechanisms

## Changes made

| Domain or service | Key/action | Intended effect |
| --- | --- | --- |
| `com.apple.assistant.support` | `Assistant Enabled = false` | Turns off the Siri assistant for the user |
| `com.apple.Siri` | `StatusMenuVisible = false` | Hides the menu-bar item |
| `com.apple.Siri` | `UserHasDeclinedEnable = true` | Records that Siri was declined |
| `com.apple.Siri` | `VoiceTriggerUserEnabled = false` | Disables “Hey Siri” |
| `com.apple.Siri` | `LockscreenEnabled = false` | Disables lock-screen access |
| `com.apple.Siri` | `SiriPrefStashedStatusMenuVisible = false` | Prevents restoration of the stashed menu-bar choice |
| `com.apple.Siri` | `SuggestionsEnabled = false` | Disables Siri suggestions in this preference domain |
| `gui/<uid>/com.apple.Siri.agent` | `launchctl disable` | Prevents the per-user Siri agent from launching |
| `com.apple.controlstrip` | `MiniCustomized` array | Defines compact Touch Bar controls without Siri |
| `com.apple.controlstrip` | `FullCustomized` array | Defines expanded Touch Bar controls without Siri |

The compact Touch Bar list is deliberately conservative: brightness, volume, and mute. The expanded list retains brightness, keyboard brightness, Mission Control, Launchpad, media, and volume groups. These replace the user's existing Control Strip customizations. The restore script deletes both overrides so macOS can return to its default or System Settings-managed arrangement.

## Process handling

The script asks currently running Siri and Control Strip UI processes to exit. macOS relaunches Control Strip automatically. Failures are ignored because a process may not exist or may be protected.

A root-owned process named `siriinferenced` can remain active. It is a protected shared framework helper and is not proof that the user-facing Siri assistant is enabled. This project does not interfere with it.

## Persistence and limitations

Preference and launch-service settings normally survive logout and restart. No project can honestly promise that unsupported preference keys will survive every macOS upgrade. Apple may migrate or reset them, and managed-device policy may override user settings.

This project was manually verified on a 15-inch 2017 MacBook Pro (`MacBookPro14,3`) with a quad-core Intel Core i7 and Touch Bar, running macOS 13.7.8. The model identifier is a product-family identifier, not a unique device identifier. Touch Bar changes are relevant only to Macs that have a Touch Bar.

## Verification

After disabling, these commands should return `0`:

```sh
defaults read com.apple.assistant.support "Assistant Enabled"
defaults read com.apple.Siri VoiceTriggerUserEnabled
defaults read com.apple.Siri LockscreenEnabled
defaults read com.apple.Siri StatusMenuVisible
```

The launch service should be shown as disabled:

```sh
launchctl print-disabled "gui/$(id -u)" | grep com.apple.Siri.agent
```

Neither Touch Bar list should contain a `com.apple.system.siri` item:

```sh
defaults read com.apple.controlstrip MiniCustomized
defaults read com.apple.controlstrip FullCustomized
```

## Rollback

`restore-siri.sh` deletes only the keys written by this project, removes the Touch Bar override, and re-enables the launch agent. Deleting a key restores macOS-managed default behavior rather than guessing the user's former value.
