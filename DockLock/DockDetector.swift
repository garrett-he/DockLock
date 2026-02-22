import CoreGraphics
import AppKit

/// Locate the monitor currently hosting the Dock via system window list, and read Dock orientation.
/// No screen recording permission required: kCGWindowOwnerName / kCGWindowBounds are unrestricted.
enum DockDetector {
    static func detect() -> (displayID: CGDirectDisplayID, orientation: DockOrientation)? {
        let orientation = readOrientation()
        guard let bounds = dockWindowBounds() else { return nil }
        let displayID = containingDisplay(for: bounds) ?? CGMainDisplayID()
        return (displayID, orientation)
    }

    private static func readOrientation() -> DockOrientation {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        switch prefs?.string(forKey: "orientation") {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    /// Find the main window bounds for the Dock. When auto-hide is enabled, the window may be off-screen,
    /// so we use the window with the largest overlap area with any display.
    private static func dockWindowBounds() -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let dockWindows = list.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" }
        guard !dockWindows.isEmpty else { return nil }

        var best: CGRect?
        var bestOverlap: CGFloat = -1
        for window in dockWindows {
            guard let bounds = bounds(of: window), bounds.width * bounds.height > 0 else { continue }
            let overlap = activeDisplayBounds()
                .map { $0.intersection(bounds).width * $0.intersection(bounds).height }
                .max() ?? 0
            if overlap > bestOverlap {
                bestOverlap = overlap
                best = bounds
            }
        }
        return best
    }

    private static func bounds(of window: [String: Any]) -> CGRect? {
        guard let dict = window[kCGWindowBounds as String] as? [String: NSNumber],
              let x = dict["X"]?.doubleValue,
              let y = dict["Y"]?.doubleValue,
              let w = dict["Width"]?.doubleValue,
              let h = dict["Height"]?.doubleValue
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids
    }

    private static func activeDisplayBounds() -> [CGRect] {
        activeDisplayIDs().map { CGDisplayBounds($0) }
    }

    /// The display containing the window's center point; if the center is outside all screens (auto-hidden),
    /// fall back to the display with the largest overlap area.
    private static func containingDisplay(for bounds: CGRect) -> CGDirectDisplayID? {
        let ids = activeDisplayIDs()
        guard !ids.isEmpty else { return nil }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let exact = ids.first(where: { CGDisplayBounds($0).contains(center) }) {
            return exact
        }
        return ids.max { a, b in
            CGDisplayBounds(a).intersection(bounds).width * CGDisplayBounds(a).intersection(bounds).height
                < CGDisplayBounds(b).intersection(bounds).width * CGDisplayBounds(b).intersection(bounds).height
        }
    }
}
