import CoreGraphics
import AppKit

/// Core engine: manages system-level CGEventTap. When the cursor approaches the trigger zone of a
/// non-Dock monitor, clamp the event position just outside the boundary, ensuring the Dock never receives
/// the cursor position needed to trigger screen switching.
final class DockLockManager: ObservableObject {
    static let shared = DockLockManager()

    @Published var isLocked: Bool = true
    @Published var isPermissionGranted: Bool = false
    @Published var isTapRunning: Bool = false
    @Published var dockDisplayName: String = "Detecting…"

    let gate = ScreenGate()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {
        refreshPermission()
    }

    // MARK: - Lifecycle

    func start() {
        refreshAnchors()
        installTap()
        // Dock process may still be starting up; re-check once more after a short delay for reliability
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshAnchors()
        }
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isTapRunning = false
    }

    // MARK: - Event Interception

    private func installTap() {
        guard tap == nil else { return }

        let mask: CGEventMask = eventMask(.mouseMoved)
            | eventMask(.leftMouseDragged)
            | eventMask(.rightMouseDragged)
            | eventMask(.otherMouseDragged)

        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isTapRunning = false
            refreshPermission()
            return
        }

        tap = newTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: newTap, enable: true)
        isTapRunning = true
    }

    private func eventMask(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << CGEventMask(type.rawValue)
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passRetained(event)
        }
        let manager = Unmanaged<DockLockManager>.fromOpaque(refcon).takeUnretainedValue()

        // Auto-recover tap if system disabled it due to timeout or user input
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        return manager.process(event: event)
    }

    private func process(event: CGEvent) -> Unmanaged<CGEvent> {
        guard isLocked else {
            return Unmanaged.passRetained(event)
        }
        let location = event.location
        if let clamped = gate.clampedPosition(for: location) {
            event.location = clamped
        }
        return Unmanaged.passRetained(event)
    }

    // MARK: - Anchor (Dock monitor and orientation)

    /// Re-detect which monitor and orientation the Dock is on, and refresh display geometry info.
    func refreshAnchors() {
        gate.hotZonePoints = Settings.shared.hotZonePoints
        gate.refreshDisplays()

        if let info = DockDetector.detect() {
            gate.dockDisplayID = info.displayID
            gate.orientation = info.orientation
        } else if gate.dockDisplayID == nil {
            // Fallback on detection failure: use main display + bottom Dock
            gate.dockDisplayID = CGMainDisplayID()
            gate.orientation = .bottom
        }
        updateDockDisplayName()
    }

    /// Pin the Dock to the screen currently containing the mouse cursor.
    func pinToCurrentScreen() {
        gate.refreshDisplays()
        if let id = gate.display(containing: currentMouseLocation()) {
            gate.dockDisplayID = id
            updateDockDisplayName()
        }
    }

    private func currentMouseLocation() -> CGPoint {
        let p = NSEvent.mouseLocation // Cocoa coordinates (origin at bottom-left, in points)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return .zero }

        let id = CGDirectDisplayID(number.uint32Value)
        let bounds = CGDisplayBounds(id) // Global Quartz pixel coordinates
        let scaleX = bounds.width / screen.frame.width
        let scaleY = bounds.height / screen.frame.height
        let x = bounds.minX + (p.x - screen.frame.minX) * scaleX
        let y = bounds.maxY - (p.y - screen.frame.minY) * scaleY
        return CGPoint(x: x, y: y)
    }

    private func updateDockDisplayName() {
        guard let id = gate.dockDisplayID else {
            dockDisplayName = "Unknown"
            return
        }
        let name = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }?.localizedName ?? "Display #\(id)"
        dockDisplayName = name
    }

    func refreshPermission() {
        isPermissionGranted = PermissionHelper.isTrusted
    }
}
