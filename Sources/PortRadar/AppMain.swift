import AppKit
import SwiftUI

@main
struct PortRadarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class StatusPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedInstance: AppDelegate?
    private var statusItem: NSStatusItem!
    private var panel: StatusPanel!
    private var hostingController: NSHostingController<PopoverContentView>!
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.sharedInstance = self
        setupStatusItem()
        setupPanel()
        
        PortScannerEngine.shared.onUpdate = { [weak self] in
            self?.updateStatusButton()
        }
        updateStatusButton()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "PortRadar — Dev Port & Localhost Manager (⌃⌘P)"
        }
    }
    
    private func setupPanel() {
        hostingController = NSHostingController(rootView: PopoverContentView())
        hostingController.sizingOptions = [.preferredContentSize]
        
        panel = StatusPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        
        let hostView = hostingController.view
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostView
    }
    
    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        togglePanel(sender)
    }
    
    func togglePanelFromHotkey() {
        guard let button = statusItem.button else { return }
        togglePanel(button)
    }
    
    private func togglePanel(_ sender: NSStatusBarButton) {
        if panel.isVisible {
            closePanel()
        } else {
            PortScannerEngine.shared.scanNow()
            showPanel(relativeTo: sender)
        }
    }
    
    private func showPanel(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        let panelWidth: CGFloat = max(620, fittingSize.width)
        let panelHeight: CGFloat = max(440, fittingSize.height)
        
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame
        
        var x = round(buttonFrameInScreen.midX - (panelWidth / 2))
        let minX = visibleFrame.minX + 10
        let maxX = visibleFrame.maxX - panelWidth - 10
        x = max(minX, min(x, maxX))
        
        PanelGeometryModel.shared.arrowX = buttonFrameInScreen.midX - x
        
        var y = round(buttonFrameInScreen.minY - panelHeight - 2)
        if y < visibleFrame.minY + 10 {
            y = visibleFrame.minY + 10
        }
        if y + panelHeight > visibleFrame.maxY - 2 {
            y = visibleFrame.maxY - panelHeight - 2
        }
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel.invalidateShadow()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            Task { @MainActor in
                AppDelegate.sharedInstance?.closePanel()
            }
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    AppDelegate.sharedInstance?.closePanel()
                }
                return nil
            }
            return event
        }
    }
    
    func closePanel() {
        panel.orderOut(nil)
        if let gm = globalClickMonitor {
            NSEvent.removeMonitor(gm)
            globalClickMonitor = nil
        }
        if let lm = localKeyMonitor {
            NSEvent.removeMonitor(lm)
            localKeyMonitor = nil
        }
    }
    
    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let devCount = PortScannerEngine.shared.devServerCount
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        if let img = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "PortRadar")?.withSymbolConfiguration(config) {
            img.isTemplate = true
            button.image = img
            button.imagePosition = .imageLeading
            button.title = devCount > 0 ? " \(devCount)" : ""
        }
    }
}
