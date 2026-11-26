import AIStageCore
import AppKit
import Foundation

@main
@MainActor
final class AIStageAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: StageCoordinator!
    private var dockController: DockPanelController!
    private var loopRadialController: LoopRadialController!
    private var menuBarController: MenuBarController!

    private static var retainedDelegate: AIStageAppDelegate?

    static func main() {
        let app = NSApplication.shared
        // Accessory app: keeps the left-edge Liquid Glass Dock non-activating (zero focus steal on switch)
        app.setActivationPolicy(.accessory)
        let delegate = AIStageAppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                NSLog("[AIStage] Another instance is already running; bringing existing instance forward.")
                others.first?.activate(options: [])
                NSApp.terminate(nil)
                return
            }
        }

        coordinator = StageCoordinator()
        dockController = DockPanelController(coordinator: coordinator)
        loopRadialController = LoopRadialController(coordinator: coordinator)
        menuBarController = MenuBarController(coordinator: coordinator, dockController: dockController)
        coordinator.start()
        dockController.showOnboardingWindowIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator?.summonStageGroup()
        if coordinator?.settings.hideMenuBarIcon == true || coordinator?.settings.dockShape == .radialOnly {
            dockController?.showSettingsWindow()
        }
        return true
    }
}
