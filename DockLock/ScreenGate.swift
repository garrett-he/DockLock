import CoreGraphics
import AppKit

enum DockOrientation: String {
    case bottom
    case left
    case right
}

struct DisplayInfo: Equatable {
    let displayID: CGDirectDisplayID
    let bounds: CGRect // Global Quartz pixel coordinates (origin at top-left)
    let scale: CGFloat // pixels per point
}

/// Geometric computation unit: handles display info, Dock trigger zone calculation, and cursor clamping.
/// Pure logic, no side effects, easy to test.
final class ScreenGate {
    private(set) var displays: [DisplayInfo] = []

    var dockDisplayID: CGDirectDisplayID?
    var orientation: DockOrientation = .bottom
    var hotZonePoints: Double = 8

    init() {
        refreshDisplays()
    }

    func refreshDisplays() {
        var result: [DisplayInfo] = []
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let id = CGDirectDisplayID(number.uint32Value)
            let bounds = CGDisplayBounds(id)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            let scale = screen.frame.width > 0 ? bounds.width / screen.frame.width : 1
            result.append(DisplayInfo(displayID: id, bounds: bounds, scale: scale))
        }
        displays = result
    }

    func display(containing point: CGPoint) -> CGDirectDisplayID? {
        displays.first { $0.bounds.contains(point) }?.displayID
    }

    /// If the point falls within the trigger zone of a non-Dock monitor, return the clamped position;
    /// otherwise return nil.
    func clampedPosition(for point: CGPoint) -> CGPoint? {
        guard let dockID = dockDisplayID,
              displays.contains(where: { $0.displayID == dockID })
        else { return nil }

        for display in displays where display.displayID != dockID {
            let zone = hotZone(on: display)
            if zone.contains(point) {
                let margin: CGFloat = 1
                switch orientation {
                case .bottom:
                    return CGPoint(x: point.x, y: zone.minY - margin)
                case .left:
                    return CGPoint(x: zone.maxX + margin, y: point.y)
                case .right:
                    return CGPoint(x: zone.minX - margin, y: point.y)
                }
            }
        }
        return nil
    }

    /// Dock trigger zone: an edge strip on non-Dock monitors aligned with the Dock's direction.
    private func hotZone(on display: DisplayInfo) -> CGRect {
        let h = CGFloat(hotZonePoints) * display.scale
        switch orientation {
        case .bottom:
            return CGRect(x: display.bounds.minX,
                          y: display.bounds.maxY - h,
                          width: display.bounds.width,
                          height: h)
        case .left:
            return CGRect(x: display.bounds.minX,
                          y: display.bounds.minY,
                          width: h,
                          height: display.bounds.height)
        case .right:
            return CGRect(x: display.bounds.maxX - h,
                          y: display.bounds.minY,
                          width: h,
                          height: display.bounds.height)
        }
    }
}
