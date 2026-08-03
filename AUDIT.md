# Audit notes

## Threat and safety model

This project changes preferences for the current user. It does not attempt to remove Siri binaries: macOS system files are protected, deletion would be brittle, and Siri frameworks can be shared by features such as dictation and system intelligence.

The scripts intentionally avoid:

- `sudo` and root writes
- disabling System Integrity Protection
- deleting files or unloading unrelated Apple services
- network access, downloads, telemetry, and persistence mechanisms

Before changing anything, the scripts capture the targeted Boolean preferences, the presence and contents of both Touch Bar customization arrays, and the existing `launchctl` disabled state. Repeated runs do not replace that baseline. They filter the current Touch Bar arrays, however, so later user customizations are not discarded merely by running the disabling command again. Rollback restores only the originally targeted values rather than importing entire preference domains.

## Changes made

The Siri preference changes target macOS generally. The two `com.apple.controlstrip` changes apply only to MacBook Pro computers equipped with a physical Touch Bar. They have no useful effect on computers without that hardware and should be skipped there with `--no-touch-bar`.

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

When customized arrays already exist, the script retains their order and entries and filters only `com.apple.system.siri`. When an array is absent, the compact fallback is brightness, volume, and mute; the expanded fallback retains brightness, keyboard brightness, Mission Control, Launchpad, media, and volume groups. Rollback restores the original arrays or deletes the overrides if they were originally absent.

## Process handling

The script asks currently running Siri and Control Strip UI processes to exit. macOS relaunches Control Strip automatically. Failures are ignored because a process may not exist or may be protected.

A root-owned process named `siriinferenced` can remain active. It is a protected shared framework helper and is not proof that the user-facing Siri assistant is enabled. This project does not interfere with it.

## Persistence and limitations

Preference and launch-service settings normally survive logout and restart. Writes and launch-agent disablement are verified before success is reported. No project can honestly promise that unsupported preference keys will survive every macOS upgrade. Apple may migrate or reset them, and managed-device policy may override user settings.

This project was manually verified on a 15-inch 2017 MacBook Pro (`MacBookPro14,3`) with a quad-core Intel Core i7 and Touch Bar, running macOS 13.7.8. The model identifier is a product-family identifier, not a unique device identifier. The scripts record that non-unique model identifier in the private rollback metadata and warn when the current macOS version differs from the tested version. This tested configuration must not be generalized to every macOS release without verification. Touch Bar changes are relevant only to MacBook Pro computers that physically have a Touch Bar; some MacBook Pro models use physical function keys and are out of scope for that part.

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

`restore-siri.sh` restores the exact targeted values captured by the first operation, including whether each key existed and whether the launch agent was already disabled. It restores only the two Touch Bar array keys rather than replacing the entire `com.apple.controlstrip` domain. The consumed snapshot is archived with user-only permissions.

## Remaining limitations

- The preference keys are private Apple implementation details, not a supported public API.
- Behavior is manually verified only on the tested model and macOS version above.
- Touch Bar detection relies on the presence of an active `TouchBarServer` or `ControlStrip` process. An explicit force option exists for confirmed hardware when those processes are unavailable.
- A user can still re-enable Siri or customize the Touch Bar later; “forever” is not a technically enforceable promise.
