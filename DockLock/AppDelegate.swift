import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = DockLockManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.start()

        // Recalculate when monitors are plugged/unplugged or resolution changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Lightweight polling for permission status; refresh menu bar UI automatically after authorization
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.manager.refreshPermission()
        }
    }

    @objc private func screenParametersChanged() {
        manager.refreshAnchors()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stop()
    }
}
