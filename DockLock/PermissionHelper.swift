import ApplicationServices
import AppKit

enum PermissionHelper {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the system authorization dialog (if Accessibility is not yet enabled).
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
