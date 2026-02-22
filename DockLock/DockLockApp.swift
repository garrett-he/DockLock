import SwiftUI

@main
struct DockLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = DockLockManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            Image(systemName: manager.isLocked ? "lock.fill" : "lock.open.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
