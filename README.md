# DockLock

macOS menu bar utility: locks the Dock to its current position, preventing it from jumping between screens in multi-monitor setups.

## How It Works

The Dock only switches screens when one condition is met: **the cursor enters the Dock trigger zone (the edge strip on the side where the Dock is located)**. DockLock uses a system-level `CGEventTap` (at the HID layer, the earliest point in the event chain) to monitor mouse movement/drag events. When the cursor is about to enter the trigger zone of a **non-Dock screen**, the event position is clamped just outside the boundary (~1px away). Since the cursor can't physically reach the trigger zone, the Dock will never switch screens. Normal operation is unaffected, and there's no cursor jitter.

- **Auto-detection**: On launch, locates the current Dock screen via window list (`CGWindowListCopyWindowInfo`) and reads `com.apple.dock`'s `orientation` to determine Dock position (bottom/left/right).
- **Coordinate conversion**: Based on `CGDisplayBounds` (global Quartz pixel coordinates), works correctly across different resolutions.
- **Display changes**: Automatically recalculates when monitors are connected/disconnected.

## System Requirements

- macOS 13.0+
- **Accessibility** permission required (to monitor/intercept mouse events)

## Build & Run

```bash
# Build from command line (Debug)
xcodebuild -project DockLock.xcodeproj -target DockLock -configuration Debug SYMROOT=build build

# Launch
open build/Debug/DockLock.app
```

Or open `DockLock.xcodeproj` in Xcode and hit Run directly (no code signing needed, use "Sign to Run Locally").

After first launch:

1. Click the lock icon in the menu bar → "Accessibility permission required, click to open settings"
2. In **System Settings → Privacy & Security → Accessibility**, check DockLock (or the terminal/Xcode running it)
3. Back in the menu bar, click "Re-enable Interception"

## Usage

| Menu Item                            | Description                                                      |
| ------------------------------------ | ---------------------------------------------------------------- |
| Lock Dock (prevent screen switching) | Toggle interception; when off, restores system default behavior  |
| Pin to Current Screen                | Set the Dock anchor to the screen currently containing the mouse |
| Launch at Login                      | Register LaunchAgent for auto-start on login                     |
| Re-enable Interception               | Recreate event tap after granting permission                     |

Menu bar icon: 🔒 Locked / 🔓 Unlocked.

## Project Structure

```
DockLock/
├── DockLockApp.swift      # SwiftUI entry point, MenuBarExtra (menu bar only, no Dock icon)
├── AppDelegate.swift      # Start interception, monitor display changes, poll permission
├── DockLockManager.swift  # Core: CGEventTap lifecycle + event clamping callback
├── ScreenGate.swift       # Display geometry, trigger zone calculation (pure logic, testable)
├── DockDetector.swift     # Locate Dock screen and orientation
├── PermissionHelper.swift # Accessibility permission check/guidance
├── MenuBarView.swift      # Menu bar UI
└── Settings.swift         # UserDefaults settings + auto-launch (SMAppService)
```

## Known Limitations / Future Plans

- The edge strip (default 8pt) on non-Dock screens in the Dock's direction will be clamped, making content within that strip unclickable; strip height can be adjusted in `Settings.swift`.
- Currently the anchor (Dock's screen) is auto-detected on each launch and valid for the session; future versions may add manual pinning with persistence.
- Distribution requires Developer ID + notarization (no sandbox, as system-level event interception is needed; not distributed via App Store).

## License

Copyright (C) 2026 Garrett HE <garrett.he@outlook.com>

MIT License, see [LICENSE](./LICENSE).
