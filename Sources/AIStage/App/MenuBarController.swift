import AIStageCore
import AppKit
import Foundation

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let coordinator: StageCoordinator
    private let dockController: DockPanelController
    private let menu = NSMenu()

    public init(coordinator: StageCoordinator, dockController: DockPanelController) {
        self.coordinator = coordinator
        self.dockController = dockController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let img = Self.makeMenuBarLogoImage()
            button.image = img
            button.toolTip = "iRing — 灵动岛与快捷圆环工作台"
        }

        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = !coordinator.settings.hideMenuBarIcon
        coordinator.onMenuBarVisibilityShouldChange = { [weak self] visible in
            self?.statusItem.isVisible = visible
        }
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. Stage Actions
        let toggleShortcut = coordinator.settings.effectiveToggleShortcut.displayString
        let toggleTitle = coordinator.isStageHidden
            ? "呼出工作台 (\(toggleShortcut))"
            : "呼出 / 隐藏工作台 (\(toggleShortcut))"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(handleToggleStage), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        if coordinator.layoutMode == .split2 {
            let exitSplit = NSMenuItem(title: "退出双屏对比", action: #selector(handleExitSplit), keyEquivalent: "")
            exitSplit.target = self
            menu.addItem(exitSplit)
        }

        let moveScreen = NSMenuItem(title: "移动工作台到下一块显示器 (\(coordinator.settings.effectiveMoveScreenShortcut.displayString))", action: #selector(handleMoveNextScreen), keyEquivalent: "")
        moveScreen.target = self
        menu.addItem(moveScreen)

        menu.addItem(.separator())

        // 2. Quick switch managed apps
        for (idx, item) in coordinator.displayedApps.enumerated() {
            let rt = coordinator.runtimeInfo[item.bundleIdentifier]
            let statusMark = (rt?.isRunning == true) ? "●" : "○"
            let badgeText = (rt?.badgeLabel?.isEmpty == false) ? " [\(rt!.badgeLabel!)]" : ""
            let memText = (rt?.memoryMB ?? 0) > 0 ? "  (\(rt!.memoryMB) MB)" : ""
            let shortcutHint = (idx < 9 && coordinator.settings.numberSwitchModifier.symbolPrefix != nil)
                ? "  \(coordinator.settings.numberSwitchModifier.symbolPrefix!)\(idx + 1)"
                : ""
            let menuItem = NSMenuItem(
                title: "\(statusMark) \(item.displayName)\(badgeText)\(memText)\(shortcutHint)",
                action: #selector(handleSelectApp(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = item.bundleIdentifier
            if item.bundleIdentifier == coordinator.activeBundleID {
                menuItem.state = .on
            }
            let icon = coordinator.discovery.icon(for: item).copy() as? NSImage
            icon?.size = NSSize(width: 16, height: 16)
            menuItem.image = icon
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())

        // 3. Manual App Management & Preferences
        let addItem = NSMenuItem(title: "添加 / 管理应用…", action: #selector(handleAddApp), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        let prefsItem = NSMenuItem(title: "偏好设置…", action: #selector(handleSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        if !coordinator.isAccessibilityTrusted {
            menu.addItem(.separator())
            let permItem = NSMenuItem(title: "⚠️ 授权辅助功能权限…", action: #selector(handleRequestPermission), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)

            let relaunchItem = NSMenuItem(title: "🔄 已开启权限？重启 iRing 生效", action: #selector(handleRelaunchSelf), keyEquivalent: "")
            relaunchItem.target = self
            menu.addItem(relaunchItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 iRing", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private static func makeMenuBarLogoImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            let ringCenter = NSPoint(x: 9.0, y: 11.2)
            let ringRadius: CGFloat = 4.6
            let ringStroke: CGFloat = 2.0

            NSColor.black.setStroke()
            let openRing = NSBezierPath()
            openRing.appendArc(withCenter: ringCenter, radius: ringRadius, startAngle: 308, endAngle: 232, clockwise: false)
            openRing.lineWidth = ringStroke
            openRing.lineCapStyle = .round
            openRing.stroke()

            NSColor.black.setFill()
            let dotR: CGFloat = 1.15
            let dotCenterY = ringCenter.y - ringRadius
            NSBezierPath(ovalIn: NSRect(x: 9.0 - dotR, y: dotCenterY - dotR, width: dotR * 2, height: dotR * 2)).fill()

            let stemRect = NSRect(x: 9.0 - 1.0, y: 1.5, width: 2.0, height: 2.8)
            NSBezierPath(roundedRect: stemRect, xRadius: 1.0, yRadius: 1.0).fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    @objc private func handleToggleStage() {
        coordinator.toggleStageVisibility()
    }

    @objc private func handleExitSplit() {
        coordinator.exitSplitMode()
    }

    @objc private func handleMoveNextScreen() {
        coordinator.moveStageToNextScreen()
    }

    @objc private func handleSelectApp(_ sender: NSMenuItem) {
        guard let bid = sender.representedObject as? String else { return }
        coordinator.switchToApp(bundleID: bid)
    }

    @objc private func handleAddApp() {
        dockController.showAddAppWindow()
    }

    @objc private func handleSettings() {
        dockController.showSettingsWindow()
    }

    @objc private func handleRequestPermission() {
        coordinator.requestAccessibilityPermission()
    }

    @objc private func handleRelaunchSelf() {
        coordinator.relaunchSelf()
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
