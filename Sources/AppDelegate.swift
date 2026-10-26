import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let durationKey = "lockDuration"
    private static let defaultDuration = 10
    private static let durationChoices = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    private var statusItem: NSStatusItem!
    private let blocker = InputBlocker()
    private var overlays: [OverlayWindow] = []
    private var timer: Timer?
    private var endDate = Date()

    private var duration: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: Self.durationKey)
            return saved > 0 ? saved : Self.defaultDuration
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.durationKey)
            updateTooltip()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "bubbles.and.sparkles", accessibilityDescription: "WipeLock")
                ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: "WipeLock")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateTooltip()

        if !AXIsProcessTrusted() {
            // Shows the system "would like to control this computer" prompt.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if timer != nil { endLock() }
    }

    // MARK: - Status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
            || event?.modifierFlags.contains(.option) == true
        if wantsMenu {
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            startLock()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let lockItem = NSMenuItem(title: "Lock for \(duration) Seconds", action: #selector(lockFromMenu), keyEquivalent: "")
        lockItem.target = self
        menu.addItem(lockItem)
        menu.addItem(.separator())

        let durationMenu = NSMenu()
        for seconds in Self.durationChoices {
            let item = NSMenuItem(title: "\(seconds) seconds", action: #selector(chooseDuration(_:)), keyEquivalent: "")
            item.target = self
            item.tag = seconds
            item.state = seconds == duration ? .on : .off
            durationMenu.addItem(item)
        }
        let durationItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        if !AXIsProcessTrusted() {
            menu.addItem(.separator())
            let grantItem = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grantItem.target = self
            menu.addItem(grantItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WipeLock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func updateTooltip() {
        statusItem?.button?.toolTip = "WipeLock: click to lock the keyboard and mouse for \(duration) seconds. Right-click for options."
    }

    @objc private func lockFromMenu() {
        // Let the menu finish closing before input goes dark.
        DispatchQueue.main.async { self.startLock() }
    }

    @objc private func chooseDuration(_ sender: NSMenuItem) {
        duration = sender.tag
    }

    // MARK: - Lock

    private func startLock() {
        guard timer == nil else { return }
        guard AXIsProcessTrusted(), blocker.start() else {
            showPermissionAlert()
            return
        }

        endDate = Date().addingTimeInterval(TimeInterval(duration))
        overlays = NSScreen.screens.map { OverlayWindow(screen: $0) }

        activate()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching,
                                     .disableForceQuit, .disableSessionTermination, .disableHideApplication]
        for overlay in overlays { overlay.orderFrontRegardless() }
        overlays.first?.makeKey()
        CGAssociateMouseAndMouseCursorPosition(0)
        NSCursor.hide()

        tick()
        let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func tick() {
        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else {
            endLock()
            return
        }
        let seconds = Int(remaining.rounded(.up))
        for overlay in overlays { overlay.setSeconds(seconds) }
    }

    private func endLock() {
        timer?.invalidate()
        timer = nil
        blocker.stop()
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
        NSApp.presentationOptions = []
        for overlay in overlays { overlay.orderOut(nil) }
        overlays.removeAll()
        // Hand focus back to whichever app was in front before the lock.
        NSApp.hide(nil)
    }

    // MARK: - Permission

    private func showPermissionAlert() {
        activate()
        let alert = NSAlert()
        alert.messageText = "WipeLock needs Accessibility access"
        alert.informativeText = """
            To block the keyboard and mouse, turn on WipeLock in System Settings → Privacy & Security → Accessibility, then click the menu bar icon again.

            If WipeLock is already listed and switched on, remove it with the − button and add it again (this is needed after rebuilding the app).
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
