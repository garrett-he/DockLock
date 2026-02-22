import Foundation
import ServiceManagement

/// Simple UserDefaults wrapper for persisting a small number of user settings.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let lockEnabled = "lockEnabled"
        static let hotZonePoints = "hotZonePoints"
    }

    var lockEnabled: Bool {
        get { defaults.object(forKey: Key.lockEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.lockEnabled) }
    }

    /// Dock trigger zone height (points). Default 8pt; smaller values interfere less with normal use,
    /// larger values are more reliable.
    var hotZonePoints: Double {
        get {
            let v = defaults.double(forKey: Key.hotZonePoints)
            return v > 0 ? v : 8
        }
        set { defaults.set(newValue, forKey: Key.hotZonePoints) }
    }
}

/// Auto-launch at login (macOS 13+, registers a LaunchAgent).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to set auto-launch: \(error)")
        }
    }
}
