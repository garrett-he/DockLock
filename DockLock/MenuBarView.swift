import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: DockLockManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DockLock")
                    .font(.headline)
                Text("Dock pinned to: \(manager.dockDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Toggle(isOn: lockBinding) {
                Text("Lock Dock (prevent screen switching)")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Button {
                manager.pinToCurrentScreen()
            } label: {
                Label("Pin to Current Screen", systemImage: "display.2")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Divider()

            Toggle(isOn: launchAtLoginBinding) {
                Text("Launch at Login")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Divider()

            permissionRow
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            if !manager.isTapRunning && manager.isPermissionGranted {
                Button {
                    manager.start()
                } label: {
                    Label("Re-enable Interception", systemImage: "arrow.clockwise")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 260)
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { manager.isLocked },
            set: { value in
                manager.isLocked = value
                if value {
                    // When re-locking, the Dock may have switched screens during the unlocked period; re-anchor
                    manager.refreshAnchors()
                }
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.setEnabled($0) }
        )
    }

    @ViewBuilder
    private var permissionRow: some View {
        if manager.isPermissionGranted {
            Label("Accessibility: Authorized", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button {
                PermissionHelper.requestAccess()
                PermissionHelper.openSystemSettings()
            } label: {
                Label("Accessibility permission required, click to open settings", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}
