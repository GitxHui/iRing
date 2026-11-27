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
            button.toolTip = L10n.t("iRing — 灵动岛与快捷圆环", "iRing — Dynamic Island & Radial Ring")
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
        statusItem.button?.toolTip = L10n.t("iRing — 灵动岛与快捷圆环", "iRing — Dynamic Island & Radial Ring")

        // 1. Core Island & Screen Controls
        let toggleShortcut = coordinator.settings.effectiveToggleShortcut.displayString
        let toggleBase = coordinator.isStageHidden
            ? L10n.t("显示灵动岛", "Show Dynamic Island")
            : L10n.t("隐藏灵动岛", "Hide Dynamic Island")
        let toggleItem = NSMenuItem(
            title: "\(toggleBase)  (\(toggleShortcut))",
            action: #selector(handleToggleStage),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        if coordinator.settings.dockShape == .dynamicIsland {
            let pinItem = NSMenuItem(
                title: L10n.t("固定展开灵动岛", "Keep Island Expanded"),
                action: #selector(handleTogglePinned),
                keyEquivalent: ""
            )
            pinItem.target = self
            pinItem.state = coordinator.settings.dynamicIslandPinned ? .on : .off
            menu.addItem(pinItem)
        }

        if NSScreen.screens.count > 1 {
            let moveShortcut = coordinator.settings.effectiveMoveScreenShortcut.displayString
            let moveScreen = NSMenuItem(
                title: L10n.t("移到下一块显示器  (\(moveShortcut))", "Move to Next Display  (\(moveShortcut))"),
                action: #selector(handleMoveNextScreen),
                keyEquivalent: ""
            )
            moveScreen.target = self
            menu.addItem(moveScreen)
        }

        if coordinator.layoutMode == .split2 {
            let exitSplit = NSMenuItem(
                title: L10n.t("退出双屏对比", "Exit Split View"),
                action: #selector(handleExitSplit),
                keyEquivalent: ""
            )
            exitSplit.target = self
            menu.addItem(exitSplit)
        }

        menu.addItem(.separator())

        // 2. Core App Management & Settings
        let addItem = NSMenuItem(title: L10n.t("管理应用…", "Manage Apps…"), action: #selector(handleAddApp), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        let prefsItem = NSMenuItem(title: L10n.t("偏好设置…", "Settings…"), action: #selector(handleSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        if !coordinator.isAccessibilityTrusted {
            menu.addItem(.separator())
            let permItem = NSMenuItem(
                title: L10n.t("授权辅助功能权限…", "Grant Accessibility Permission…"),
                action: #selector(handleRequestPermission),
                keyEquivalent: ""
            )
            permItem.target = self
            permItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(permItem)

            let relaunchItem = NSMenuItem(
                title: L10n.t("重启 iRing 生效", "Relaunch iRing"),
                action: #selector(handleRelaunchSelf),
                keyEquivalent: ""
            )
            relaunchItem.target = self
            relaunchItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
            menu.addItem(relaunchItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L10n.t("退出 iRing", "Quit iRing"), action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private static func makeMenuBarLogoImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let px = rect.width
            let inset = px * 0.05
            let card = rect.insetBy(dx: inset, dy: inset)
            let radius = card.width * 0.24

            // Match desktop AppIcon.icns dark navy squircle gradient & subtle specular rim
            let cardPath = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.14, green: 0.20, blue: 0.38, alpha: 1.0),
                NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.22, alpha: 1.0)
            ])!
            gradient.draw(in: cardPath, angle: -55)

            NSColor.white.withAlphaComponent(0.28).setStroke()
            cardPath.lineWidth = 0.65
            cardPath.stroke()

            // Combined iRing "i + Ring" emblem (matching desktop AppIcon geometry)
            let ringCenter = NSPoint(x: px * 0.50, y: px * 0.555)
            let ringRadius = px * 0.242
            let ringStroke = px * 0.112
            let halfStroke = ringStroke * 0.5
            let azure = NSColor(calibratedRed: 0.05, green: 0.48, blue: 0.96, alpha: 1.0)
            let crispWhite = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 0.98)

            let openRing = NSBezierPath()
            openRing.appendArc(withCenter: ringCenter, radius: ringRadius, startAngle: 306.5, endAngle: 233.5, clockwise: false)
            openRing.lineWidth = ringStroke
            openRing.lineCapStyle = .round
            crispWhite.setStroke()
            openRing.stroke()

            let dotRadius = px * 0.050
            let dotCenterY = px * 0.353
            let dotRect = NSRect(
                x: ringCenter.x - dotRadius,
                y: dotCenterY - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            azure.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            let stemWidth = px * 0.098
            let stemTop = px * 0.276
            let stemHeight = px * 0.128
            let stemRect = NSRect(
                x: ringCenter.x - stemWidth * 0.5,
                y: stemTop - stemHeight,
                width: stemWidth,
                height: stemHeight
            )
            crispWhite.setFill()
            NSBezierPath(roundedRect: stemRect, xRadius: stemWidth * 0.5, yRadius: stemWidth * 0.5).fill()

            // Flush 12 o'clock azure accent sector
            let wedgePath = NSBezierPath()
            wedgePath.appendArc(withCenter: ringCenter, radius: ringRadius + halfStroke, startAngle: 59, endAngle: 121, clockwise: false)
            wedgePath.appendArc(withCenter: ringCenter, radius: max(0.8, ringRadius - halfStroke), startAngle: 121, endAngle: 59, clockwise: true)
            wedgePath.close()
            azure.setFill()
            wedgePath.fill()

            return true
        }
        img.isTemplate = false
        return img
    }

    @objc private func handleToggleStage() {
        coordinator.toggleStageVisibility()
    }

    @objc private func handleTogglePinned() {
        coordinator.toggleDynamicIslandPinned()
    }

    @objc private func handleExitSplit() {
        coordinator.exitSplitMode()
    }

    @objc private func handleMoveNextScreen() {
        coordinator.moveStageToNextScreen()
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
