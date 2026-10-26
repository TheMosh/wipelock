import CoreGraphics

/// Swallows every keyboard, mouse, trackpad and media-key event system-wide
/// with a HID-level event tap. Needs Accessibility permission.
///
/// If this process crashes or quits, macOS removes the tap and input comes back on its own.
final class InputBlocker {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Returns false when the tap can't be created, which almost always means
    /// the app hasn't been granted Accessibility access.
    func start() -> Bool {
        guard tap == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            // macOS switches off taps it thinks are slow; turn ours straight back on.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon, let tap = Unmanaged<InputBlocker>.fromOpaque(refcon).takeUnretainedValue().tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask.max,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        runLoopSource = nil
    }
}
