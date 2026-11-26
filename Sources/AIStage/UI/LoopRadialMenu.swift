import AIStageCore
import AppKit
import CoreGraphics
import SwiftUI
import Vortex

// MARK: - Full-Saturation Loop Theme Palette

public enum LoopThemeColors {
    /// (primary, secondary). Every theme follows the same recipe as the reference blue:
    /// `primary` is the clean, vivid slice color; `secondary` is the same hue at ~70% brightness,
    /// used for the slice's inner edge and the preview-frame gradient. All primaries are mid-tone
    /// so the slice reads on both the light ring body and the dark (graphite) one.
    public static func colors(for theme: LoopAccentTheme) -> (primary: Color, secondary: Color) {
        switch theme {
        case .ocean:
            // Measured from the reference: slice #0071EC -> #0068DB, frame #0068DC -> #004FA9.
            return (
                Color(red: 0.000, green: 0.443, blue: 0.925),
                Color(red: 0.000, green: 0.310, blue: 0.663)
            )
        case .system:
            return systemAccentPair()
        case .appleGlass:
            // Frosted silver-blue: quiet, but still visible on the near-white ring body.
            return (
                Color(red: 0.52, green: 0.62, blue: 0.78),
                Color(red: 0.36, green: 0.45, blue: 0.60)
            )
        case .emerald:
            return (
                Color(red: 0.07, green: 0.68, blue: 0.47),
                Color(red: 0.03, green: 0.48, blue: 0.34)
            )
        case .sunset:
            return (
                Color(red: 0.96, green: 0.38, blue: 0.22),
                Color(red: 0.76, green: 0.22, blue: 0.16)
            )
        case .nebula:
            return (
                Color(red: 0.46, green: 0.35, blue: 0.92),
                Color(red: 0.32, green: 0.23, blue: 0.70)
            )
        case .monochrome:
            // Graphite: mid-gray so it contrasts with both the light and the dark ring.
            return (
                Color(white: 0.42),
                Color(white: 0.28)
            )
        case .custom:
            let base = color(fromHex: "#0071EC")
            return (base, deeperTone(of: base))
        }
    }

    /// Resolves primary & secondary palette colors using settings (including custom ColorPicker & ringColorDepth).
    public static func colors(for settings: StageSettings) -> (primary: Color, secondary: Color) {
        let basePrimary: Color
        let baseSecondary: Color
        if settings.radialTheme == .custom {
            basePrimary = color(fromHex: settings.customRingColorHex)
            baseSecondary = deeperTone(of: basePrimary)
        } else {
            let pair = colors(for: settings.radialTheme)
            basePrimary = pair.primary
            baseSecondary = pair.secondary
        }
        let depth = min(1.0, max(0.25, settings.ringColorDepth))
        return (
            applyDepth(basePrimary, depth: depth),
            applyDepth(baseSecondary, depth: depth)
        )
    }

    public static func color(fromHex hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let val = UInt64(cleaned, radix: 16) else {
            return Color(red: 0.000, green: 0.443, blue: 0.925)
        }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    public static func hexString(from color: Color) -> String {
        guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return "#0071EC" }
        let r = max(0, min(255, Int(round(ns.redComponent * 255.0))))
        let g = max(0, min(255, Int(round(ns.greenComponent * 255.0))))
        let b = max(0, min(255, Int(round(ns.blueComponent * 255.0))))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func deeperTone(of color: Color) -> Color {
        guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let deep = NSColor(hue: h, saturation: min(1.0, s * 1.06), brightness: max(0.08, b * 0.68), alpha: a)
        return Color(nsColor: deep)
    }

    private static func applyDepth(_ color: Color, depth: Double) -> Color {
        guard abs(depth - 0.85) > 0.01,
              let ns = NSColor(color).usingColorSpace(.sRGB)
        else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let satScale = CGFloat(0.42 + 0.72 * depth)
        let briScale = CGFloat(1.16 - 0.24 * depth)
        let adjusted = NSColor(
            hue: h,
            saturation: min(1.0, max(0.0, s * satScale)),
            brightness: min(1.0, max(0.08, b * briScale)),
            alpha: a
        )
        return Color(nsColor: adjusted)
    }

    /// Derives the pair from the user's accent color, keeping its full saturation instead of
    /// blending with black (which made the old blue look grey and flat).
    private static func systemAccentPair() -> (primary: Color, secondary: Color) {
        guard let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) else {
            return colors(for: .ocean)
        }
        var h: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        accent.getHue(&h, saturation: &sat, brightness: &bri, alpha: &alpha)
        if sat < 0.12 {
            // Graphite accent: keep it neutral rather than inventing a hue.
            return colors(for: .monochrome)
        }
        // Same hue for both: a clean vivid tone and a ~25% deeper one (no hue drift, no black mix).
        // Tuned so the default blue accent (#007AFF) lands on the reference: ~#0071EC / ~#0054A8.
        let primary = NSColor(hue: h, saturation: min(1, sat * 1.04), brightness: bri * 0.93, alpha: 1)
        let secondary = NSColor(hue: h, saturation: min(1, sat * 1.04), brightness: bri * 0.66, alpha: 1)
        return (Color(nsColor: primary), Color(nsColor: secondary))
    }
}

// MARK: - Shared Status Colors

public enum AIStageStatusColors {
    /// Single source for the "app is running" dot (ring, center emblem, preview).
    public static let running = Color(.displayP3, red: 0.20, green: 0.86, blue: 0.48)
}

// MARK: - Shared State

public enum LoopRadialMode: Equatable, Sendable {
    case appSwitcher
    case splitLayout
}

@MainActor
public final class LoopRadialState: ObservableObject {
    @Published public var isVisible: Bool = false
    @Published public var mode: LoopRadialMode = .appSwitcher
    @Published public var selectedIndex: Int? = nil
    /// Index picked on release; drives the fly-out confirmation while the ring fades away.
    @Published public var committedIndex: Int? = nil
    @Published public var lockedSplitApp: StageAppItem? = nil
    @Published public var splitSectorIndex: Int? = nil
    @Published public var splitOuterRingActive: Bool = false
    @Published public var wedgeRotationDegrees: Double = 0
    @Published public var pointerDistance: CGFloat = 0
    @Published public var anchorScreenID: String? = nil
    @Published public var sessionApps: [StageAppItem] = []
    @Published public var layoutTarget: RadialLayoutTarget = .stage
    @Published public var previewVisible: Bool = false
    @Published public var previewTargetRectLocal: CGRect = .zero
    @Published public var previewScreenFrameAppKit: CGRect = .zero
    @Published public var splitTargetPID: pid_t? = nil
    @Published public var isBlankAreaFillSession: Bool = false
    @Published public var pendingFillFrameQuartz: CGRect? = nil
    @Published public var customWindowScale: CGFloat = 1.0

    public init() {}
}

/// Click-through, non-activating overlay panel used for both the Loop ring and the position preview.
final class LoopOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect, level: NSWindow.Level) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.hidesOnDeactivate = false
        self.worksWhenModal = false
        self.ignoresMouseEvents = true
        self.level = level
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.animationBehavior = .none
    }
}

// MARK: - Controller (gesture engine + preview placement)

@MainActor
public final class LoopRadialController {
    private enum ActiveTriggerSource: Equatable {
        case none
        case mouse(buttonNumber: Int)
        case keyboardCombo
        case splitHotkey
        case optionScrollSplit
        case modifierHold(RadialModifierKey)
    }

    private enum TriggerStartKind {
        case none
        case appSwitcher(buttonNumber: Int)
        case splitLayout(buttonNumber: Int)
    }

    private let coordinator: StageCoordinator
    private let state = LoopRadialState()
    private let ringPanel: LoopOverlayPanel
    private let previewPanel: LoopOverlayPanel

    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var cgEventTap: CFMachPort?
    nonisolated(unsafe) private var cgRunLoopSource: CFRunLoopSource?

    private var triggerSource: ActiveTriggerSource = .none
    private var isHoldingTrigger = false
    private var isKeyboardLatched = false
    private var isResizeModifierHeld = false
    private var isResizeModifierLatched = false
    private var keyboardPressUptime: TimeInterval = 0
    private var activeButtonNumber: Int = -1
    private var downMouseAppKit: CGPoint = .zero
    private var ringCenterAppKit: CGPoint = .zero
    private var holdTimer: DispatchWorkItem?
    private var sessionGeneration: UInt64 = 0
    /// Latest pointer seen this session (AppKit coords); preferred over NSEvent.mouseLocation.
    var lastPointerAppKit: CGPoint?
    private var previewHideWork: DispatchWorkItem?
    private var ringHideWork: DispatchWorkItem?
    private var scrollAccumulator: CGFloat = 0
    private var lastScrollStepUptime: TimeInterval = 0
    private let deadzoneRadius: CGFloat = 22

    public init(coordinator: StageCoordinator) {
        self.coordinator = coordinator
        self.ringPanel = LoopOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 368, height: 368),
            level: .popUpMenu
        )
        self.previewPanel = LoopOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            level: NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        )

        ringPanel.contentView = Self.makeHost(LoopRadialRingView(coordinator: coordinator, state: state))
        previewPanel.contentView = Self.makeHost(LoopPreviewView(coordinator: coordinator, state: state))

        coordinator.onRadialKeyboardTriggerPressed = { [weak self] in
            self?.handleKeyboardComboPressed()
        }
        coordinator.onRadialKeyboardTriggerReleased = { [weak self] in
            self?.handleKeyboardComboReleased()
        }
        coordinator.onSplitRingHotkeyPressed = { [weak self] in
            self?.handleSplitHotkeyPressed()
        }
        coordinator.onSplitRingHotkeyReleased = { [weak self] in
            self?.handleSplitHotkeyReleased()
        }

        installMonitors()
        refreshEventTapIfTrusted()
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let tap = cgEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = cgRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private static func makeHost<V: View>(_ view: V) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        return hosting
    }

    public func refreshEventTapIfTrusted() {
        guard cgEventTap == nil, AXWindowController.isAccessibilityTrusted(promptIfNeeded: false) else { return }
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<LoopRadialController>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = controller.cgEventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                switch type {
                case .otherMouseDown:
                    let btn = Int(event.getIntegerValueField(.mouseEventButtonNumber))
                    if btn >= 2 {
                        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                        MainActor.assumeIsolated {
                            switch controller.tapShouldStartOtherMouseDown(buttonNumber: btn, flags: nsFlags) {
                            case .splitLayout(let b):
                                controller.beginSplitMouseSession(buttonNumber: b)
                            case .appSwitcher(let b):
                                controller.beginTriggerSession(buttonNumber: b)
                            case .none:
                                break
                            }
                        }
                    }
                    return Unmanaged.passUnretained(event)

                case .otherMouseDragged, .otherMouseUp:
                    let btn = Int(event.getIntegerValueField(.mouseEventButtonNumber))
                    guard controller.tapShouldCaptureOtherMouse(buttonNumber: btn) else {
                        return Unmanaged.passUnretained(event)
                    }
                    // The tap swallows these events, so NSEvent.mouseLocation stops updating;
                    // read the pointer from the event itself (Quartz, top-left origin).
                    let quartz = event.location
                    let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                    if type == .otherMouseDragged {
                        DispatchQueue.main.async { controller.handlePointerMoved(quartzLocation: quartz) }
                        return nil
                    }
                    DispatchQueue.main.async {
                        controller.lastPointerAppKit = controller.appKitPoint(fromQuartz: quartz)
                        controller.handleMouseTriggerUp(flags: nsFlags)
                    }
                    // Never swallow the button-up: the matching down was passed through, and
                    // eating the up leaves the session believing the button is still held
                    // (NSEvent.pressedMouseButtons stuck), which blocks island auto-collapse.
                    return Unmanaged.passUnretained(event)

                case .leftMouseDown:
                    guard controller.tapShouldConsumeLeftClick() else {
                        return Unmanaged.passUnretained(event)
                    }
                    DispatchQueue.main.async { controller.handleLatchedLeftClick() }
                    return nil

                case .flagsChanged:
                    let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                    DispatchQueue.main.async {
                        controller.handleModifierFlagsChanged(flags: nsFlags, keyCode: keyCode)
                    }
                    return Unmanaged.passUnretained(event)

                case .scrollWheel:
                    let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
                    let precise = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
                    let delta: CGFloat = precise
                        ? CGFloat(event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
                        : CGFloat(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
                    if controller.tapSessionActive() {
                        DispatchQueue.main.async {
                            controller.handleScroll(delta: delta, precise: precise, flags: nsFlags)
                        }
                        return nil
                    } else if controller.tapShouldStartOptionScrollSplit(flags: nsFlags) {
                        DispatchQueue.main.async {
                            controller.beginOptionScrollSplitSession(delta: delta, precise: precise)
                        }
                        return nil
                    }
                    return Unmanaged.passUnretained(event)

                case .keyDown:
                    let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
                    if controller.tapSessionActive() {
                        guard [48, 53, 36, 49, 123, 124, 125, 126].contains(code) else {
                            return Unmanaged.passUnretained(event)
                        }
                        DispatchQueue.main.async { controller.handleKey(code) }
                        return nil
                    } else if controller.tapCancelPendingModifierHoldIfNeeded() {
                        return Unmanaged.passUnretained(event)
                    }
                    return Unmanaged.passUnretained(event)

                default:
                    return Unmanaged.passUnretained(event)
                }
            },
            userInfo: refcon
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.cgEventTap = tap
        self.cgRunLoopSource = source
    }

    private func tapShouldStartOtherMouseDown(buttonNumber: Int, flags: NSEvent.ModifierFlags) -> TriggerStartKind {
        // Check dedicated Split Mouse Trigger FIRST so e.g. ⌥ + middle-click launches Split Ring
        // instead of App Switcher when radialTrigger is plain middleClickDrag.
        switch coordinator.settings.splitMouseTrigger {
        case .optionMiddle:
            if buttonNumber == 2 && flags.contains(.option) {
                return .splitLayout(buttonNumber: 2)
            }
        case .customMouse:
            if buttonNumber == coordinator.settings.splitCustomMouseButton
                && portableModifiers(from: flags) == coordinator.settings.splitCustomMouseModifiers {
                return .splitLayout(buttonNumber: buttonNumber)
            }
        case .optionScroll, .optionRight, .disabled:
            break
        }

        switch coordinator.settings.radialTrigger {
        case .middleClickDrag:
            return buttonNumber == 2 ? .appSwitcher(buttonNumber: 2) : .none
        case .optionMiddleClick:
            return (buttonNumber == 2 && flags.contains(.option)) ? .appSwitcher(buttonNumber: 2) : .none
        case .customMouse:
            let match = buttonNumber == coordinator.settings.radialCustomMouseButton
                && portableModifiers(from: flags) == coordinator.settings.radialCustomMouseModifiers
            return match ? .appSwitcher(buttonNumber: buttonNumber) : .none
        case .optionRightDrag, .disabled:
            return .none
        }
    }

    private nonisolated func tapShouldStartOptionScrollSplit(flags: NSEvent.ModifierFlags) -> Bool {
        MainActor.assumeIsolated {
            triggerSource == .none
                && !state.isVisible
                && coordinator.settings.splitMouseTrigger == .optionScroll
                && flags.contains(.option)
                && !flags.contains(.command)
                && !flags.contains(.control)
        }
    }

    private nonisolated func tapShouldCaptureOtherMouse(buttonNumber: Int) -> Bool {
        MainActor.assumeIsolated {
            guard state.isVisible, case .mouse(let activeBtn) = triggerSource else { return false }
            return activeBtn == buttonNumber
        }
    }

    private nonisolated func tapShouldConsumeLeftClick() -> Bool {
        MainActor.assumeIsolated {
            state.isVisible && (isKeyboardLatched || (isHoldingTrigger && state.mode == .appSwitcher))
        }
    }

    private nonisolated func tapCancelPendingModifierHoldIfNeeded() -> Bool {
        MainActor.assumeIsolated {
            if case .modifierHold = triggerSource, !state.isVisible {
                endTriggerSession(commit: false)
                return true
            }
            return false
        }
    }

    private nonisolated func tapSessionActive() -> Bool {
        MainActor.assumeIsolated { (isHoldingTrigger || isKeyboardLatched) && state.isVisible }
    }

    private func portableModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.control) { mask |= CustomKeyCombo.modControl }
        if flags.contains(.option) { mask |= CustomKeyCombo.modOption }
        if flags.contains(.shift) { mask |= CustomKeyCombo.modShift }
        if flags.contains(.command) { mask |= CustomKeyCombo.modCommand }
        return mask
    }

    private func isResizeModifierActive(flags: NSEvent.ModifierFlags = NSEvent.modifierFlags) -> Bool {
        state.pendingFillFrameQuartz == nil && coordinator.settings.ringResizeModifier.matches(flags)
    }

    private func latchForResizeModifier() {
        isResizeModifierLatched = true
        isResizeModifierHeld = true
        isHoldingTrigger = false
        isKeyboardLatched = true
        scrollAccumulator = 0
    }

    func handleMouseTriggerUp(flags: NSEvent.ModifierFlags) {
        if state.isVisible && (isResizeModifierHeld || isResizeModifierActive(flags: flags)) {
            latchForResizeModifier()
            return
        }
        endTriggerSession(commit: true)
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .otherMouseDown, .otherMouseDragged, .otherMouseUp,
            .rightMouseDown, .rightMouseDragged, .rightMouseUp,
            .leftMouseDown,
            .mouseMoved, .scrollWheel, .flagsChanged, .keyDown
        ]

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseEvent(event)
            }
        }
    }

    private func matchesTrigger(_ event: NSEvent) -> TriggerStartKind {
        let optHeld = event.modifierFlags.contains(.option)
        let isRight = (event.type == .rightMouseDown)
        let btn = isRight ? 1 : event.buttonNumber
        let mods = portableModifiers(from: event.modifierFlags)

        switch coordinator.settings.splitMouseTrigger {
        case .optionMiddle:
            if !isRight && btn == 2 && optHeld { return .splitLayout(buttonNumber: 2) }
        case .optionRight:
            if isRight && optHeld { return .splitLayout(buttonNumber: 1) }
        case .customMouse:
            if coordinator.settings.splitCustomMouseButton == 1 {
                if isRight && mods == coordinator.settings.splitCustomMouseModifiers {
                    return .splitLayout(buttonNumber: 1)
                }
            } else if !isRight && btn == coordinator.settings.splitCustomMouseButton && mods == coordinator.settings.splitCustomMouseModifiers {
                return .splitLayout(buttonNumber: btn)
            }
        case .optionScroll, .disabled:
            break
        }

        switch coordinator.settings.radialTrigger {
        case .disabled:
            return .none
        case .middleClickDrag:
            return (!isRight && btn == 2) ? .appSwitcher(buttonNumber: 2) : .none
        case .optionMiddleClick:
            return (!isRight && btn == 2 && optHeld) ? .appSwitcher(buttonNumber: 2) : .none
        case .optionRightDrag:
            return (isRight && optHeld) ? .appSwitcher(buttonNumber: 1) : .none
        case .customMouse:
            let targetBtn = coordinator.settings.radialCustomMouseButton
            let targetMods = coordinator.settings.radialCustomMouseModifiers
            let modsMatch = mods == targetMods
            if targetBtn == 1 {
                return (isRight && modsMatch) ? .appSwitcher(buttonNumber: 1) : .none
            }
            return (!isRight && btn == targetBtn && modsMatch) ? .appSwitcher(buttonNumber: targetBtn) : .none
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .otherMouseDown, .rightMouseDown:
            refreshEventTapIfTrusted()
            switch matchesTrigger(event) {
            case .splitLayout(let btn):
                beginSplitMouseSession(buttonNumber: btn)
            case .appSwitcher(let btn):
                beginTriggerSession(buttonNumber: btn)
            case .none:
                break
            }

        case .otherMouseDragged, .rightMouseDragged, .mouseMoved:
            guard isHoldingTrigger || isKeyboardLatched else { return }
            let btn = (event.type == .rightMouseDragged) ? 1 : event.buttonNumber
            if event.type != .mouseMoved {
                guard case .mouse(let activeBtn) = triggerSource, btn == activeBtn else { return }
            }
            handlePointerMoved()

        case .otherMouseUp, .rightMouseUp:
            guard !isResizeModifierLatched, case .mouse(let activeBtn) = triggerSource else { return }
            let btn = (event.type == .rightMouseUp) ? 1 : event.buttonNumber
            if btn == activeBtn {
                handleMouseTriggerUp(flags: event.modifierFlags)
            }

        case .leftMouseDown:
            guard cgEventTap == nil, state.isVisible else { return }
            if isKeyboardLatched || (isHoldingTrigger && state.mode == .appSwitcher) {
                handleLatchedLeftClick()
            }

        case .flagsChanged:
            guard cgEventTap == nil else { return }
            handleModifierFlagsChanged(flags: event.modifierFlags, keyCode: event.keyCode)

        case .keyDown:
            guard cgEventTap == nil else { return }
            if case .modifierHold = triggerSource, !state.isVisible {
                endTriggerSession(commit: false)
                return
            }
            if state.isVisible && (isHoldingTrigger || isKeyboardLatched) {
                handleKey(Int(event.keyCode))
            }

        case .scrollWheel:
            guard cgEventTap == nil else { return }
            if (isHoldingTrigger || isKeyboardLatched), state.isVisible {
                handleScroll(delta: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas, flags: event.modifierFlags)
            } else if tapShouldStartOptionScrollSplit(flags: event.modifierFlags) {
                beginOptionScrollSplitSession(delta: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas)
            }

        default:
            break
        }
    }

    private func prepareTriggerSnapshot() {
        holdTimer?.cancel()
        downMouseAppKit = NSEvent.mouseLocation
        scrollAccumulator = 0
        isResizeModifierHeld = false
        isResizeModifierLatched = false
        if coordinator.settings.showNotificationBadges {
            coordinator.refreshRuntimeInfo()
        }

        let screens = DisplayGeometry.allScreens()
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseQuartz = CGPoint(x: downMouseAppKit.x, y: primaryH - downMouseAppKit.y)
        state.anchorScreenID = DisplayGeometry.screen(containingQuartzPoint: mouseQuartz, screens: screens)?.id
        sessionGeneration &+= 1
        lastPointerAppKit = nil
        state.sessionApps = coordinator.radialDisplayedApps
        state.mode = .appSwitcher
        state.selectedIndex = nil
        state.committedIndex = nil
        state.lockedSplitApp = nil
        state.splitSectorIndex = nil
        state.splitOuterRingActive = false
        state.splitTargetPID = nil
        state.isBlankAreaFillSession = false
        state.pendingFillFrameQuartz = nil
        state.customWindowScale = 1.0
        state.pointerDistance = 0
        state.layoutTarget = .stage
    }

    private func configureSplitCursorHitTest() {
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseQuartz = CGPoint(x: downMouseAppKit.x, y: primaryH - downMouseAppKit.y)
        if let hit = AXWindowController.windowOwnerAtQuartzPoint(mouseQuartz) {
            state.splitTargetPID = hit.pid
            state.isBlankAreaFillSession = false
            let matched = hit.bundleID.flatMap { bid in
                coordinator.apps.first(where: { $0.bundleIdentifier == bid })
            }
            enterSplitRingMode(targetApp: matched)
        } else {
            state.splitTargetPID = nil
            state.isBlankAreaFillSession = true
            enterSplitRingMode(targetApp: nil)
        }
    }

    private func beginSplitMouseSession(buttonNumber: Int) {
        guard triggerSource == .none else { return }
        triggerSource = .mouse(buttonNumber: buttonNumber)
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = buttonNumber
        prepareTriggerSnapshot()
        configureSplitCursorHitTest()
        revealRing(centeredNear: downMouseAppKit)
        updatePreview()
    }

    private func beginOptionScrollSplitSession(delta: CGFloat, precise: Bool) {
        guard triggerSource == .none else { return }
        triggerSource = .optionScrollSplit
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = -1
        prepareTriggerSnapshot()
        configureSplitCursorHitTest()
        revealRing(centeredNear: downMouseAppKit)
        updatePreview()
        handleScroll(delta: delta, precise: precise, flags: .option)
    }

    private func beginTriggerSession(buttonNumber: Int) {
        guard triggerSource == .none else { return }
        triggerSource = .mouse(buttonNumber: buttonNumber)
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = buttonNumber
        prepareTriggerSnapshot()

        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.isHoldingTrigger, !self.state.isVisible else { return }
            self.revealRing(centeredNear: self.downMouseAppKit)
        }
        holdTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: timer)
    }

    private func handleKeyboardComboPressed() {
        if state.isVisible && isKeyboardLatched {
            endTriggerSession(commit: state.selectedIndex != nil)
            return
        }
        guard triggerSource == .none else { return }
        triggerSource = .keyboardCombo
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = -1
        keyboardPressUptime = ProcessInfo.processInfo.systemUptime
        prepareTriggerSnapshot()
        revealRing(centeredNear: downMouseAppKit)
    }

    private func handleKeyboardComboReleased() {
        guard triggerSource == .keyboardCombo else { return }
        let held = ProcessInfo.processInfo.systemUptime - keyboardPressUptime
        if state.selectedIndex != nil || held >= 0.25 {
            endTriggerSession(commit: true)
        } else if state.isVisible {
            isKeyboardLatched = true
            isHoldingTrigger = false
        } else {
            endTriggerSession(commit: false)
        }
    }

    private func handleSplitHotkeyPressed() {
        if state.isVisible && isKeyboardLatched && state.mode == .splitLayout {
            endTriggerSession(commit: true)
            return
        }
        guard triggerSource == .none else { return }
        triggerSource = .splitHotkey
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = -1
        keyboardPressUptime = ProcessInfo.processInfo.systemUptime
        prepareTriggerSnapshot()
        configureSplitCursorHitTest()
        revealRing(centeredNear: downMouseAppKit)
        updatePreview()
    }

    private func handleSplitHotkeyReleased() {
        guard triggerSource == .splitHotkey else { return }
        let held = ProcessInfo.processInfo.systemUptime - keyboardPressUptime
        if state.splitSectorIndex != nil || held >= 0.25 {
            endTriggerSession(commit: true)
        } else if state.isVisible {
            isKeyboardLatched = true
            isHoldingTrigger = false
        } else {
            endTriggerSession(commit: false)
        }
    }

    private func handleLatchedLeftClick() {
        guard state.isVisible else { return }
        if isHoldingTrigger && state.mode == .appSwitcher {
            toggleSplitRingMode()
            return
        }
        guard isKeyboardLatched else { return }
        endTriggerSession(commit: state.mode == .splitLayout || state.selectedIndex != nil)
    }

    private func frontmostStagedAppItem() -> StageAppItem? {
        guard let bid = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return nil }
        return coordinator.apps.first(where: { $0.bundleIdentifier == bid })
    }

    private func enterSplitRingMode(targetApp: StageAppItem?) {
        let speed = coordinator.settings.animationSpeed
        let anim: Animation? = speed.isInstant ? nil : .spring(response: max(0.16, speed.ringSpringResponse), dampingFraction: 0.78)
        withAnimation(anim) {
            state.mode = .splitLayout
            state.lockedSplitApp = targetApp
            state.selectedIndex = nil
            state.splitSectorIndex = nil
            state.splitOuterRingActive = false
            state.layoutTarget = .maximize
        }
        updateSplitSelection(for: lastPointerAppKit ?? NSEvent.mouseLocation)
        performHaptic(.generic)
    }

    private func toggleSplitRingMode() {
        if state.mode == .appSwitcher {
            let apps = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps : state.sessionApps
            let pickedItem: StageAppItem? = state.selectedIndex.flatMap { idx in
                idx >= 0 && idx < apps.count ? apps[idx] : nil
            } ?? frontmostStagedAppItem()
            enterSplitRingMode(targetApp: pickedItem)
        } else {
            let speed = coordinator.settings.animationSpeed
            let anim: Animation? = speed.isInstant ? nil : .spring(response: max(0.16, speed.ringSpringResponse), dampingFraction: 0.78)
            withAnimation(anim) {
                state.mode = .appSwitcher
                state.lockedSplitApp = nil
                state.splitSectorIndex = nil
                state.splitOuterRingActive = false
                state.layoutTarget = .stage
            }
            handlePointerMoved(quartzLocation: nil)
        }
    }

    private func matchesModifierHoldStart(_ modKey: RadialModifierKey, flags: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        let standard = flags.intersection([.control, .option, .shift, .command])
        switch modKey {
        case .rightOption:
            return keyCode == 61 && standard == .option
        case .rightCommand:
            return keyCode == 54 && standard == .command
        case .fnKey:
            return keyCode == 63 && flags.contains(.function) && standard.isEmpty
        case .controlOption:
            return [58, 59, 61, 62].contains(keyCode) && standard == [.control, .option]
        }
    }

    private func isModifierHoldStillActive(_ modKey: RadialModifierKey, flags: NSEvent.ModifierFlags) -> Bool {
        switch modKey {
        case .rightOption:
            return flags.contains(.option)
        case .rightCommand:
            return flags.contains(.command)
        case .fnKey:
            return flags.contains(.function)
        case .controlOption:
            return flags.contains(.control) && flags.contains(.option)
        }
    }

    private func handleModifierFlagsChanged(flags: NSEvent.ModifierFlags, keyCode: UInt16) {
        let resizeActive = isResizeModifierActive(flags: flags)
        isResizeModifierHeld = state.isVisible && resizeActive

        if isResizeModifierLatched {
            if !resizeActive {
                endTriggerSession(commit: true)
            }
            return
        }

        if case .optionScrollSplit = triggerSource {
            if !flags.contains(.option) {
                if state.isVisible && resizeActive {
                    latchForResizeModifier()
                } else {
                    endTriggerSession(commit: true)
                }
            }
            return
        }

        if case .modifierHold(let activeMod) = triggerSource {
            if !isModifierHoldStillActive(activeMod, flags: flags) {
                if state.isVisible && resizeActive {
                    latchForResizeModifier()
                } else {
                    endTriggerSession(commit: true)
                }
            }
            return
        }

        guard coordinator.settings.radialKeyboardMode == .modifierHold, triggerSource == .none else { return }
        let modKey = coordinator.settings.radialModifierKey
        guard matchesModifierHoldStart(modKey, flags: flags, keyCode: keyCode) else { return }

        triggerSource = .modifierHold(modKey)
        isHoldingTrigger = true
        isKeyboardLatched = false
        activeButtonNumber = -1
        prepareTriggerSnapshot()

        let timer = DispatchWorkItem { [weak self] in
            guard let self, self.isHoldingTrigger, !self.state.isVisible else { return }
            self.revealRing(centeredNear: self.downMouseAppKit)
        }
        holdTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: timer)
    }

    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard coordinator.settings.radialHapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    private func revealRing(centeredNear anchorAppKit: CGPoint) {
        ringHideWork?.cancel()
        ringHideWork = nil
        let panelSize = LoopArtworkMetrics.panelSize(for: coordinator.settings)
        let rectAppKit = DisplayGeometry.radialPanelRectAppKit(
            centeredAt: anchorAppKit,
            panelSize: panelSize,
            screens: DisplayGeometry.allScreens()
        )
        ringCenterAppKit = CGPoint(x: rectAppKit.midX, y: rectAppKit.midY)
        ringPanel.setFrame(rectAppKit, display: true)
        ringPanel.contentView?.frame = NSRect(origin: .zero, size: rectAppKit.size)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            self.ringPanel.animator().alphaValue = 1
        }
        ringPanel.alphaValue = 1
        ringPanel.orderFrontRegardless()
        let speed = coordinator.settings.animationSpeed
        let style = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? AppearAnimationStyle.flash
            : coordinator.settings.appearAnimationStyle
        if speed.isInstant {
            state.isVisible = true
        } else {
            let animation: Animation = switch style {
            case .roll: .spring(response: speed.ringSpringResponse * 1.25, dampingFraction: 0.82)
            case .flash: .easeOut(duration: max(0.08, speed.fadeOutDuration))
            }
            withAnimation(animation) {
                state.isVisible = true
            }
        }
        performHaptic(.generic)
    }

    func appKitPoint(fromQuartz p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: DisplayGeometry.primaryScreenHeight() - p.y)
    }

    func handlePointerMoved(quartzLocation: CGPoint? = nil) {
        // Events coming from our own tap are authoritative; the pressed-button poll and
        // NSEvent.mouseLocation can both be stale while the tap is swallowing the drag.
        if !isResizeModifierLatched, quartzLocation == nil, case .mouse(let btn) = triggerSource, btn >= 0 {
            let buttonMask = 1 << btn
            if (NSEvent.pressedMouseButtons & buttonMask) == 0 {
                handleMouseTriggerUp(flags: NSEvent.modifierFlags)
                return
            }
        }

        let current = quartzLocation.map(appKitPoint(fromQuartz:)) ?? NSEvent.mouseLocation
        lastPointerAppKit = current
        if state.isVisible && (isResizeModifierLatched || isResizeModifierHeld || isResizeModifierActive()) {
            return
        }
        if !state.isVisible {
            let moved = hypot(current.x - downMouseAppKit.x, current.y - downMouseAppKit.y)
            guard moved >= 8.0 else { return }
            holdTimer?.cancel()
            revealRing(centeredNear: downMouseAppKit)
        }

        if state.mode == .splitLayout {
            updateSplitSelection(for: current)
            return
        }

        let count = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps.count : state.sessionApps.count
        let result = DisplayGeometry.radialSelectedIndex(
            from: ringCenterAppKit,
            to: current,
            itemCount: count,
            deadzoneRadius: deadzoneRadius
        )
        state.pointerDistance = result.distance

        guard state.selectedIndex != result.index else { return }
        let speed = coordinator.settings.animationSpeed
        let springResp = max(0.14, speed.ringSpringResponse * 0.85)
        if let idx = result.index {
            let nextDeg = Self.shortestTargetDegrees(from: state.wedgeRotationDegrees, toIndex: idx, count: count)
            if state.selectedIndex == nil || speed.isInstant {
                state.wedgeRotationDegrees = nextDeg
            } else {
                withAnimation(.interactiveSpring(response: springResp, dampingFraction: 0.80)) {
                    state.wedgeRotationDegrees = nextDeg
                }
            }
            performHaptic(.alignment)
        }
        if speed.isInstant {
            state.selectedIndex = result.index
        } else {
            withAnimation(.interactiveSpring(response: springResp, dampingFraction: 0.78)) {
                state.selectedIndex = result.index
            }
        }
        updatePreview()
    }

    private func updateSplitSelection(for currentAppKit: CGPoint) {
        let outerRadius = max(136, CGFloat(coordinator.settings.radialRingDiameter) * 0.48)
        let res = DisplayGeometry.loopSplitTarget(
            from: ringCenterAppKit,
            to: currentAppKit,
            deadzoneRadius: deadzoneRadius,
            outerThirdRadius: outerRadius,
            centerDefault: .maximize
        )
        state.pointerDistance = hypot(currentAppKit.x - ringCenterAppKit.x, currentAppKit.y - ringCenterAppKit.y)
        let changedSector = state.splitSectorIndex != res.sectorIndex
        let changedOuter = state.splitOuterRingActive != res.isOuterRing
        let changedTarget = state.layoutTarget != res.target

        guard changedSector || changedOuter || changedTarget else { return }

        let speed = coordinator.settings.animationSpeed
        let springResp = max(0.14, speed.ringSpringResponse * 0.82)
        if let sector = res.sectorIndex {
            let nextDeg = Self.shortestTargetDegrees(from: state.wedgeRotationDegrees, toIndex: sector, count: 8)
            if state.splitSectorIndex == nil || speed.isInstant {
                state.wedgeRotationDegrees = nextDeg
            } else {
                withAnimation(.interactiveSpring(response: springResp, dampingFraction: 0.80)) {
                    state.wedgeRotationDegrees = nextDeg
                }
            }
        }
        if speed.isInstant {
            state.splitSectorIndex = res.sectorIndex
            state.splitOuterRingActive = res.isOuterRing
            state.layoutTarget = res.target
        } else {
            withAnimation(.interactiveSpring(response: springResp, dampingFraction: 0.78)) {
                state.splitSectorIndex = res.sectorIndex
                state.splitOuterRingActive = res.isOuterRing
                state.layoutTarget = res.target
            }
        }
        if changedSector || changedOuter {
            performHaptic(changedOuter ? .levelChange : .alignment)
        }
        updatePreview()
    }

    public static func shortestTargetDegrees(from current: Double, toIndex idx: Int, count: Int) -> Double {
        guard count > 0 else { return current }
        let target = 360.0 * Double(idx) / Double(count)
        var delta = (target - current).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return current + delta
    }

    func handleScroll(delta: CGFloat, precise: Bool, flags: NSEvent.ModifierFlags = NSEvent.modifierFlags) {
        guard (isHoldingTrigger || isKeyboardLatched), state.isVisible else { return }

        // Ring + Resize Modifier (default ⌘) + Scroll smoothly resizes the window preview box
        if state.pendingFillFrameQuartz == nil && coordinator.settings.ringResizeModifier.matches(flags) {
            scrollAccumulator += delta
            let threshold: CGFloat = precise ? 10 : 0.45
            guard abs(scrollAccumulator) >= threshold else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastScrollStepUptime >= 0.045 else { return }
            lastScrollStepUptime = now
            let stepDelta: CGFloat = scrollAccumulator > 0 ? 0.05 : -0.05
            scrollAccumulator = 0
            let nextScale = min(1.0, max(0.45, state.customWindowScale + stepDelta))
            if abs(nextScale - state.customWindowScale) > 0.005 {
                state.customWindowScale = nextScale
                performHaptic(.alignment)
                updatePreview()
            }
            return
        }

        scrollAccumulator += delta
        let threshold: CGFloat = precise ? 14 : 0.9
        guard abs(scrollAccumulator) >= threshold else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastScrollStepUptime >= 0.14 else {
            scrollAccumulator = 0
            return
        }
        lastScrollStepUptime = now
        let step = scrollAccumulator < 0 ? 1 : -1
        scrollAccumulator = 0
        if state.mode == .splitLayout {
            setLayout(state.layoutTarget.cycledVariant(step: step))
        } else {
            setLayout(state.layoutTarget.advanced(by: step))
        }
    }

    func handleKey(_ keyCode: Int) {
        switch keyCode {
        case 48:
            toggleSplitRingMode()
        case 53:
            endTriggerSession(commit: false)
        case 36:
            endTriggerSession(commit: state.mode == .splitLayout || state.selectedIndex != nil)
        case 123:
            if state.mode == .splitLayout {
                applySplitSector(sector: 6, layout: .leftHalf)
            } else {
                setLayout(.leftHalf)
            }
        case 124:
            if state.mode == .splitLayout {
                applySplitSector(sector: 2, layout: .rightHalf)
            } else {
                setLayout(.rightHalf)
            }
        case 126:
            if state.mode == .splitLayout {
                applySplitSector(sector: 0, layout: .maximize)
            } else {
                setLayout(.maximize)
            }
        case 125:
            if state.mode == .splitLayout {
                applySplitSector(sector: 4, layout: .bottomHalf)
            } else {
                setLayout(.stage)
            }
        case 49:
            state.splitSectorIndex = nil
            setLayout(.center)
        default:
            break
        }
    }

    private func applySplitSector(sector: Int?, layout: RadialLayoutTarget) {
        if let sector {
            state.wedgeRotationDegrees = Self.shortestTargetDegrees(from: state.wedgeRotationDegrees, toIndex: sector, count: 8)
        }
        state.splitSectorIndex = sector
        state.splitOuterRingActive = false
        setLayout(layout)
    }

    private func setLayout(_ target: RadialLayoutTarget) {
        guard target != state.layoutTarget else { return }
        let speed = coordinator.settings.animationSpeed
        if speed.isInstant {
            state.layoutTarget = target
        } else {
            withAnimation(.spring(response: max(0.14, speed.ringSpringResponse * 0.85), dampingFraction: 0.80)) {
                state.layoutTarget = target
            }
        }
        performHaptic(.levelChange)
        updatePreview()
    }

    private func resolvedPreviewFrameQuartz() -> CGRect? {
        if let pinned = state.pendingFillFrameQuartz {
            return pinned
        }
        guard let baseFrame = coordinator.radialTargetFrameQuartz(screenID: state.anchorScreenID, layout: state.layoutTarget) else {
            return nil
        }
        guard state.customWindowScale < 0.999 else {
            return baseFrame
        }
        let screens = DisplayGeometry.allScreens()
        let scr = (state.anchorScreenID.flatMap { id in screens.first(where: { $0.id == id }) })
            ?? DisplayGeometry.screen(containingQuartzRect: baseFrame, screens: screens)
        let bounds = scr?.visibleFrameQuartz ?? baseFrame
        return DisplayGeometry.scaledFrameQuartz(
            baseFrame,
            scale: state.customWindowScale,
            within: bounds,
            anchor: state.layoutTarget
        )
    }

    private func updatePreview() {
        let apps = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps : state.sessionApps
        let hasAppTarget = (state.mode == .splitLayout)
            || (state.pendingFillFrameQuartz != nil)
            || (state.selectedIndex.map { $0 >= 0 && $0 < apps.count } == true)
        guard coordinator.settings.showRadialPreview,
              state.isVisible,
              hasAppTarget,
              let frameQ = resolvedPreviewFrameQuartz()
        else {
            hidePreview()
            return
        }

        let screens = DisplayGeometry.allScreens()
        let screenInfo = (state.anchorScreenID.flatMap { id in screens.first(where: { $0.id == id }) })
            ?? DisplayGeometry.screen(containingQuartzRect: frameQ, screens: screens)
            ?? screens.first
        guard let screenInfo else {
            hidePreview()
            return
        }

        previewHideWork?.cancel()
        previewHideWork = nil

        let screenAppKit = screenInfo.frameAppKit
        let targetAppKit = DisplayGeometry.quartzToAppKit(frameQ, primaryHeight: DisplayGeometry.primaryScreenHeight()).integral
        let localRect = CGRect(
            x: targetAppKit.minX - screenAppKit.minX,
            y: screenAppKit.maxY - targetAppKit.maxY,
            width: max(40, targetAppKit.width),
            height: max(40, targetAppKit.height)
        )
        let speed = coordinator.settings.animationSpeed

        let needsPanelSetup = !state.previewVisible || !previewPanel.isVisible || state.previewScreenFrameAppKit != screenAppKit
        if needsPanelSetup {
            state.previewScreenFrameAppKit = screenAppKit
            previewPanel.setFrame(screenAppKit, display: true)
            previewPanel.contentView?.frame = NSRect(origin: .zero, size: screenAppKit.size)
            if speed.isInstant {
                state.previewTargetRectLocal = localRect
                state.previewVisible = true
                previewPanel.alphaValue = 1
                previewPanel.orderFrontRegardless()
            } else {
                state.previewTargetRectLocal = localRect.insetBy(dx: localRect.width * 0.035, dy: localRect.height * 0.035)
                state.previewVisible = false
                previewPanel.alphaValue = 1
                previewPanel.orderFrontRegardless()
                let anim = Animation.spring(response: max(0.14, speed.previewFrameDuration), dampingFraction: 0.80)
                withAnimation(anim) {
                    state.previewTargetRectLocal = localRect
                    state.previewVisible = true
                }
            }
        } else if speed.isInstant {
            state.previewTargetRectLocal = localRect
        } else {
            let anim = Animation.spring(response: max(0.14, speed.previewFrameDuration), dampingFraction: 0.80)
            withAnimation(anim) {
                state.previewTargetRectLocal = localRect
            }
        }
        ringPanel.orderFrontRegardless()
    }

    private func hidePreview() {
        guard state.previewVisible || previewPanel.isVisible else { return }
        let speed = coordinator.settings.animationSpeed
        if speed.isInstant {
            state.previewVisible = false
            previewPanel.alphaValue = 0
            previewPanel.orderOut(nil)
            return
        }
        let fade = max(0.08, speed.fadeOutDuration)
        withAnimation(.easeOut(duration: fade)) {
            state.previewVisible = false
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.state.previewVisible else { return }
            self.previewPanel.alphaValue = 0
            self.previewPanel.orderOut(nil)
        }
        previewHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.02, execute: work)
    }

    func endTriggerSession(commit: Bool) {
        guard isHoldingTrigger || isKeyboardLatched || state.isVisible || triggerSource != .none else { return }
        holdTimer?.cancel()
        holdTimer = nil
        let wasVisible = state.isVisible
        let currentMode = state.mode
        let lockedApp = state.lockedSplitApp
        let targetPID = state.splitTargetPID
        let isBlankFill = state.isBlankAreaFillSession
        let pinnedFillFrame = state.pendingFillFrameQuartz
        let ordered = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps : state.sessionApps
        var picked = state.selectedIndex
        if wasVisible && commit && currentMode == .appSwitcher && picked == nil && !ordered.isEmpty {
            picked = DisplayGeometry.radialSelectedIndex(
                from: ringCenterAppKit,
                to: lastPointerAppKit ?? NSEvent.mouseLocation,
                itemCount: ordered.count,
                deadzoneRadius: deadzoneRadius
            ).index
        }
        let layout = state.layoutTarget
        let screenID = state.anchorScreenID
        let savedRingCenter = ringCenterAppKit
        let savedCustomScale = state.customWindowScale
        let resolvedFrame = resolvedPreviewFrameQuartz()

        // Step 1 -> Step 2 transition: if Split Ring was summoned over blank desktop,
        // release pins the split preview rect and opens App Ring to let the user choose which app fills it.
        if wasVisible && commit && currentMode == .splitLayout && isBlankFill, let fillFrame = resolvedFrame {
            triggerSource = .keyboardCombo
            isHoldingTrigger = false
            isKeyboardLatched = true
            isResizeModifierHeld = false
            isResizeModifierLatched = false
            activeButtonNumber = -1
            scrollAccumulator = 0
            state.pendingFillFrameQuartz = fillFrame
            state.isBlankAreaFillSession = false
            state.splitTargetPID = nil
            state.lockedSplitApp = nil
            state.splitSectorIndex = nil
            state.splitOuterRingActive = false
            state.selectedIndex = nil
            let speed = coordinator.settings.animationSpeed
            let anim: Animation? = speed.isInstant ? nil : .spring(response: max(0.16, speed.ringSpringResponse), dampingFraction: 0.78)
            withAnimation(anim) {
                state.mode = .appSwitcher
            }
            state.isVisible = true
            updatePreview()
            performHaptic(.generic)
            return
        }

        triggerSource = .none
        isHoldingTrigger = false
        isKeyboardLatched = false
        isResizeModifierHeld = false
        isResizeModifierLatched = false
        activeButtonNumber = -1
        scrollAccumulator = 0

        guard wasVisible else {
            state.selectedIndex = nil
            state.splitSectorIndex = nil
            state.lockedSplitApp = nil
            state.splitTargetPID = nil
            state.isBlankAreaFillSession = false
            state.pendingFillFrameQuartz = nil
            state.customWindowScale = 1.0
            state.mode = .appSwitcher
            state.sessionApps = []
            return
        }

        let isCommitApp = (currentMode == .appSwitcher && commit && picked != nil)
        let isCommitSplit = (currentMode == .splitLayout && commit)
        let frame = (isCommitApp || isCommitSplit) ? (pinnedFillFrame ?? resolvedFrame) : nil

        let speed = coordinator.settings.animationSpeed
        let didCommitApp = isCommitApp && picked.map { $0 >= 0 && $0 < ordered.count } == true
        let didCommit = didCommitApp || isCommitSplit
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if speed.isInstant {
            state.isVisible = false
            state.selectedIndex = nil
            state.committedIndex = nil
            state.splitSectorIndex = nil
            state.lockedSplitApp = nil
            state.splitTargetPID = nil
            state.isBlankAreaFillSession = false
            state.pendingFillFrameQuartz = nil
            state.customWindowScale = 1.0
            state.mode = .appSwitcher
            state.sessionApps = []
            ringPanel.alphaValue = 0
            ringPanel.orderOut(nil)
        } else {
            let fade = didCommit && !reduceMotion ? max(0.20, speed.fadeOutDuration * 1.5) : speed.fadeOutDuration
            withAnimation(.easeOut(duration: fade)) {
                state.committedIndex = didCommitApp ? picked : nil
                state.selectedIndex = nil
                state.isVisible = false
            }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = fade
                self.ringPanel.animator().alphaValue = 0
            }
            let generation = sessionGeneration
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.state.isVisible else { return }
                self.ringPanel.orderOut(nil)
                if self.sessionGeneration == generation {
                    self.state.committedIndex = nil
                    self.state.splitSectorIndex = nil
                    self.state.lockedSplitApp = nil
                    self.state.splitTargetPID = nil
                    self.state.isBlankAreaFillSession = false
                    self.state.pendingFillFrameQuartz = nil
                    self.state.customWindowScale = 1.0
                    self.state.mode = .appSwitcher
                    self.state.sessionApps = []
                }
            }
            ringHideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.02, execute: work)
        }
        hidePreview()

        if didCommitApp, let idx = picked {
            let metrics = LoopArtworkMetrics(settings: coordinator.settings, count: ordered.count)
            let angle = -Double.pi / 2.0 + 2.0 * Double.pi * Double(idx) / Double(max(1, ordered.count))
            let iconSide = metrics.iconSize * 1.26
            let cx = savedRingCenter.x + CGFloat(cos(angle)) * metrics.orbit
            let cy = savedRingCenter.y - CGFloat(sin(angle)) * metrics.orbit
            let sourceRect = CGRect(x: cx - iconSide * 0.5, y: cy - iconSide * 0.5, width: iconSide, height: iconSide)
            let treatAsSplit = layout.isSplitLayout || pinnedFillFrame != nil || savedCustomScale < 0.999
            coordinator.switchToApp(
                bundleID: ordered[idx].bundleIdentifier,
                overrideFrameQuartz: frame,
                sourceIconRectAppKit: sourceRect,
                isSplitLayout: treatAsSplit
            )
        } else if isCommitSplit, let targetFrame = frame {
            let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let lockedApp, lockedApp.bundleIdentifier != frontBundle && targetPID == nil {
                let metrics = LoopArtworkMetrics(settings: coordinator.settings, count: max(1, ordered.count))
                let iconSide = metrics.centerIconSize
                let sourceRect = CGRect(
                    x: savedRingCenter.x - iconSide * 0.5,
                    y: savedRingCenter.y - iconSide * 0.5,
                    width: iconSide,
                    height: iconSide
                )
                coordinator.switchToApp(
                    bundleID: lockedApp.bundleIdentifier,
                    overrideFrameQuartz: targetFrame,
                    sourceIconRectAppKit: sourceRect,
                    isSplitLayout: layout.isSplitLayout || savedCustomScale < 0.999
                )
            } else if let targetPID {
                coordinator.applyFrameToWindow(pid: targetPID, frameQuartz: targetFrame, screenID: screenID)
            } else {
                coordinator.applySplitLayoutToFrontmostWindow(layout: layout, screenID: screenID, overrideFrameQuartz: targetFrame)
            }
        }
    }
}

// MARK: - Live Popup Ring Wrapper

private struct LoopRadialRingView: View {
    @ObservedObject var coordinator: StageCoordinator
    @ObservedObject var state: LoopRadialState

    var body: some View {
        let apps = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps : state.sessionApps
        let lockedRenderItem: LoopRadialRenderItem? = state.lockedSplitApp.map {
            LoopRadialRenderItem(
                id: $0.bundleIdentifier,
                name: $0.displayName,
                icon: coordinator.discovery.icon(for: $0),
                isRunning: coordinator.runtimeInfo[$0.bundleIdentifier]?.isRunning == true
            )
        }
        LoopRadialArtwork(
            items: apps.map {
                LoopRadialRenderItem(
                    id: $0.bundleIdentifier,
                    name: $0.displayName,
                    icon: coordinator.discovery.icon(for: $0),
                    isRunning: coordinator.runtimeInfo[$0.bundleIdentifier]?.isRunning == true,
                    badgeLabel: coordinator.settings.showNotificationBadges ? coordinator.runtimeInfo[$0.bundleIdentifier]?.badgeLabel : nil
                )
            },
            selectedIndex: state.selectedIndex,
            committedIndex: state.committedIndex,
            wedgeRotationDegrees: state.wedgeRotationDegrees,
            isShown: state.isVisible,
            settings: coordinator.settings,
            isAccessibilityTrusted: coordinator.isAccessibilityTrusted,
            continuousAnimation: state.isVisible,
            useBehindWindowBlur: true,
            mode: state.mode,
            layoutTarget: state.layoutTarget,
            splitSectorIndex: state.splitSectorIndex,
            splitOuterRingActive: state.splitOuterRingActive,
            lockedSplitAppItem: lockedRenderItem
        )
    }
}

// MARK: - Reusable Multi-Style Saturated Loop Artwork + 120fps Particle Engine

public struct LoopRadialRenderItem: Identifiable {
    public let id: String
    public let name: String
    public let icon: NSImage
    public let isRunning: Bool
    public let badgeLabel: String?

    public init(id: String, name: String, icon: NSImage, isRunning: Bool, badgeLabel: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isRunning = isRunning
        self.badgeLabel = badgeLabel
    }
}

public struct LoopRadialArtwork: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let items: [LoopRadialRenderItem]
    public let selectedIndex: Int?
    public let committedIndex: Int?
    public let wedgeRotationDegrees: Double
    public let isShown: Bool
    public let settings: StageSettings
    public let isAccessibilityTrusted: Bool
    public let continuousAnimation: Bool
    public let useBehindWindowBlur: Bool
    public let mode: LoopRadialMode
    public let layoutTarget: RadialLayoutTarget
    public let splitSectorIndex: Int?
    public let splitOuterRingActive: Bool
    public let lockedSplitAppItem: LoopRadialRenderItem?

    @State private var burstTime: TimeInterval = 0
    @State private var burstAngleRad: Double = -.pi / 2

    public static func panelSize(for settings: StageSettings) -> CGFloat {
        LoopArtworkMetrics.panelSize(for: settings)
    }

    public init(
        items: [LoopRadialRenderItem],
        selectedIndex: Int?,
        committedIndex: Int? = nil,
        wedgeRotationDegrees: Double,
        isShown: Bool,
        settings: StageSettings,
        isAccessibilityTrusted: Bool,
        continuousAnimation: Bool = true,
        useBehindWindowBlur: Bool = true,
        mode: LoopRadialMode = .appSwitcher,
        layoutTarget: RadialLayoutTarget = .stage,
        splitSectorIndex: Int? = nil,
        splitOuterRingActive: Bool = false,
        lockedSplitAppItem: LoopRadialRenderItem? = nil
    ) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.committedIndex = committedIndex
        self.wedgeRotationDegrees = wedgeRotationDegrees
        self.isShown = isShown
        self.settings = settings
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.continuousAnimation = continuousAnimation
        self.useBehindWindowBlur = useBehindWindowBlur
        self.mode = mode
        self.layoutTarget = layoutTarget
        self.splitSectorIndex = splitSectorIndex
        self.splitOuterRingActive = splitOuterRingActive
        self.lockedSplitAppItem = lockedSplitAppItem
    }

    private var metrics: LoopArtworkMetrics {
        LoopArtworkMetrics(settings: settings, count: mode == .splitLayout ? 8 : items.count)
    }

    private var palette: (primary: Color, secondary: Color) {
        LoopThemeColors.colors(for: settings)
    }

    /// Reduce Motion always maps to the plain fade.
    private var appearStyle: AppearAnimationStyle {
        reduceMotion ? .flash : settings.appearAnimationStyle
    }

    public var body: some View {
        ZStack {
            particlesLayer
            if mode == .splitLayout && splitOuterRingActive {
                Circle()
                    .strokeBorder(
                        palette.primary.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])
                    )
                    .frame(width: metrics.ringDiameter + 28, height: metrics.ringDiameter + 28)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            ringBody(metrics: metrics, palette: palette)
            if mode == .splitLayout && splitSectorIndex == nil {
                Circle()
                    .strokeBorder(palette.primary.opacity(0.85), lineWidth: 3)
                    .frame(width: max(20, metrics.ringDiameter - metrics.thickness * 2), height: max(20, metrics.ringDiameter - metrics.thickness * 2))
            }
            if mode != .splitLayout {
                satellitesLayer(metrics: metrics, accent: palette.primary)
            }
            centerEmblemLayer
        }
        .modifier(LoopAppearEffect(style: appearStyle, isShown: isShown))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: selectedIndex) { _, newValue in
            handleSelectionChange(newValue)
        }
        .onChange(of: splitSectorIndex) { _, newValue in
            guard mode == .splitLayout, let sec = newValue else { return }
            burstAngleRad = -Double.pi / 2.0 + Double(sec) * (.pi / 4.0)
            burstTime = ProcessInfo.processInfo.systemUptime
        }
    }

    private func handleSelectionChange(_ newValue: Int?) {
        guard let idx = newValue, !items.isEmpty else { return }
        let step: Double = (2.0 * Double.pi) / Double(items.count)
        burstAngleRad = -Double.pi / 2.0 + step * Double(idx)
        burstTime = ProcessInfo.processInfo.systemUptime
    }

    @ViewBuilder
    private var particlesLayer: some View {
        let pStyle = settings.effectiveParticleStyle
        if pStyle != .off && isShown && !reduceMotion {
            if pStyle.isVortexStyle {
                LoopVortexParticleLayer(
                    style: pStyle,
                    metrics: metrics,
                    palette: palette,
                    selectedIndex: selectedIndex,
                    burstTime: burstTime,
                    burstAngleRad: burstAngleRad,
                    activeTimeline: continuousAnimation,
                    frameRate: selectedIndex == nil ? 60 : 120
                )
            } else {
                LoopParticleCanvas(
                    style: pStyle,
                    metrics: metrics,
                    palette: palette,
                    selectedIndex: selectedIndex,
                    wedgeRotationDegrees: wedgeRotationDegrees,
                    burstTime: burstTime,
                    burstAngleRad: burstAngleRad,
                    activeTimeline: continuousAnimation,
                    frameRate: selectedIndex == nil ? 60 : 120,
                    isDark: colorScheme == .dark
                )
            }
        }
    }

    private func satellitesLayer(metrics: LoopArtworkMetrics, accent: Color) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
            LoopArtworkSatellite(
                item: item,
                index: idx,
                count: items.count,
                metrics: metrics,
                selectedIndex: selectedIndex,
                committedIndex: committedIndex,
                isShown: isShown,
                accent: accent,
                appearStyle: appearStyle
            )
        }
    }

    @ViewBuilder
    private var centerEmblemLayer: some View {
        if mode == .splitLayout {
            if let app = lockedSplitAppItem {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: min(36, metrics.centerIconSize * 0.72), height: min(36, metrics.centerIconSize * 0.72))
                    .shadow(color: .black.opacity(0.22), radius: 4)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        } else if let idx = selectedIndex, idx >= 0, idx < items.count {
            let picked = items[idx]
            Image(nsImage: picked.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: metrics.centerIconSize, height: metrics.centerIconSize)
                .saturation(picked.isRunning ? 1.0 : 0.78)
                .overlay(alignment: .topTrailing) {
                    if let badge = picked.badgeLabel, !badge.isEmpty {
                        LoopRedBadge(label: badge)
                            .offset(x: 4, y: -3)
                    }
                }
                .shadow(color: .black.opacity(0.24), radius: 6, y: 2)
                .transition(.scale(scale: 0.72).combined(with: .opacity))
                .id(picked.id)
        } else if items.isEmpty {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func ringBody(metrics: LoopArtworkMetrics, palette: (primary: Color, secondary: Color)) -> some View {
        switch settings.radialStyle {
        case .classicTahoe, .squircle:
            saturatedTahoeRingBody(metrics: metrics, palette: palette)
        case .appleGlow:
            appleIntelligenceGlowBody(metrics: metrics, palette: palette)
        case .solidDial:
            solidDialBody(metrics: metrics, palette: palette)
        case .minimalHalo:
            minimalHaloBody(metrics: metrics, palette: palette)
        }
    }

    @ViewBuilder
    private func backdropBlurView(
        mask: LoopBlurView.MaskKind,
        diameter: CGFloat,
        cornerRadius: CGFloat,
        thickness: CGFloat,
        isCircle: Bool,
        isSolidDisc: Bool = false
    ) -> some View {
        let mat = nativeGlassMaterial(for: settings.glassStyle)
        let alpha = nativeGlassBlurAlpha(style: settings.glassStyle, opacity: settings.glassOpacity)
        if useBehindWindowBlur {
            LoopBlurView(material: mat, mask: mask, blurAlpha: alpha)
        } else if isSolidDisc {
            Circle().fill(previewSwiftUIMaterial)
        } else if isCircle {
            Circle().strokeBorder(previewSwiftUIMaterial, lineWidth: thickness)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(previewSwiftUIMaterial, lineWidth: thickness)
        }
    }

    private var previewSwiftUIMaterial: Material {
        switch settings.glassStyle {
        case .clear: return .ultraThinMaterial
        case .regular: return .regularMaterial
        case .frosted: return .thickMaterial
        }
    }

    @ViewBuilder
    private func strokeRingMask(isCircle: Bool, cornerRadius: CGFloat, thickness: CGFloat) -> some View {
        if isCircle {
            Circle().strokeBorder(.black, lineWidth: thickness)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.black, lineWidth: thickness)
        }
    }

    private var isAppleGlassTheme: Bool {
        settings.radialTheme == .appleGlass
    }

    private func activeWedgeOverlay(
        metrics: LoopArtworkMetrics,
        palette: (primary: Color, secondary: Color),
        sweep: Double? = nil
    ) -> some View {
        let hasSelection = (mode == .splitLayout) ? (splitSectorIndex != nil) : (selectedIndex != nil)
        let targetSweep = (mode == .splitLayout) ? 45.0 : (sweep ?? metrics.wedgeSweep)
        let spec = settings.glassSpecularIntensity
        let outerR = metrics.ringDiameter / 2
        let innerR = settings.radialStyle == .solidDial ? 0 : max(0, outerR - metrics.thickness)
        let stops: [Gradient.Stop] = (isAppleGlassTheme && colorScheme == .dark)
            ? [
                .init(color: palette.secondary.opacity(0.62), location: 0),
                .init(color: Color.white.opacity(colorScheme == .dark ? (0.30 + spec * 0.25) : (0.55 + spec * 0.35)), location: 1)
            ]
            : [
                .init(color: palette.primary.mix(with: palette.secondary, by: 0.30), location: 0),
                .init(color: palette.primary, location: 1)
            ]
        return RadialGradient(
            stops: stops,
            center: .center,
            startRadius: innerR,
            endRadius: outerR
        )
        .overlay {
            LinearGradient(
                colors: [Color.white.opacity(isAppleGlassTheme ? (0.20 + spec * 0.26) : 0.06), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .mask {
            LoopPieSliceShape(
                sweepDegrees: hasSelection ? targetSweep : 6
            )
            .animation(
                (reduceMotion || settings.animationSpeed.isInstant) ? nil : .spring(response: 0.30, dampingFraction: 0.72),
                value: hasSelection
            )
            .rotationEffect(.degrees(wedgeRotationDegrees))
        }
        .opacity(hasSelection ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.14), value: hasSelection)
    }

    // 1 & 2. Saturated Loop Tahoe Ring & Squircle (NSVisualEffectView OUTSIDE .compositingGroup)
    private func saturatedTahoeRingBody(
        metrics: LoopArtworkMetrics,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        let d = metrics.ringDiameter
        let cr = metrics.cornerRadius
        let thickness = metrics.thickness
        let isCircle = cr >= d / 2 - 2
        let maskKind: LoopBlurView.MaskKind = isCircle
            ? .donut(diameter: d, thickness: thickness)
            : .squircleDonut(diameter: d, cornerRadius: cr, thickness: thickness)
        let frost = settings.glassOpacity
        let spec = settings.glassSpecularIntensity
        let innerRimColor: Color = .white.opacity(colorScheme == .dark ? spec * (isAppleGlassTheme ? 0.68 : 0.50) : spec * (isAppleGlassTheme ? 1.0 : 0.92))
        let outerRimColor: Color = .white.opacity(colorScheme == .dark ? spec * (isAppleGlassTheme ? 0.68 : 0.45) : spec * (isAppleGlassTheme ? 1.0 : 0.88))
        // Near-opaque frosted body: the glass slider only fine-tunes it, so a very low
        // setting can no longer turn the ring into a grey, see-through smear.
        let ringTint: Color = colorScheme == .dark
            ? Color(white: 0.20).opacity(0.72 + frost * 0.24)
            : Color(red: 0.95, green: 0.955, blue: 0.965).opacity(0.80 + frost * 0.18)

        return ZStack {
            backdropBlurView(mask: maskKind, diameter: d, cornerRadius: cr, thickness: thickness, isCircle: isCircle)
                .frame(width: d, height: d)

            ZStack {
                Color.clear
                    .overlay(ringTint)
                    .overlay(activeWedgeOverlay(metrics: metrics, palette: palette))
                    .mask {
                        strokeRingMask(isCircle: isCircle, cornerRadius: cr, thickness: thickness)
                    }

                Group {
                    if isCircle {
                        Circle().strokeBorder(outerRimColor, lineWidth: isAppleGlassTheme ? 1.0 : 0.85)
                        Circle()
                            .inset(by: thickness - 0.5)
                            .strokeBorder(lineWidth: 0.75)
                            .foregroundStyle(innerRimColor)
                            .mask {
                                LinearGradient(colors: [.white, .clear, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .strokeBorder(outerRimColor, lineWidth: isAppleGlassTheme ? 1.0 : 0.85)
                        RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .inset(by: thickness - 0.5)
                            .strokeBorder(lineWidth: 0.75)
                            .foregroundStyle(innerRimColor)
                            .mask {
                                LinearGradient(colors: [.white, .clear, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                    }
                }
            }
            .compositingGroup()
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.16), radius: 16, y: 6)
    }

    // 3. Apple Intelligence Flowing Multi-Color Aurora Ring
    private func appleIntelligenceGlowBody(
        metrics: LoopArtworkMetrics,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        let d = metrics.ringDiameter
        let cr = metrics.cornerRadius
        let thickness = metrics.thickness
        let hasSelection = selectedIndex != nil
        let isCircle = cr >= d / 2 - 2
        let maskKind: LoopBlurView.MaskKind = isCircle
            ? .donut(diameter: d, thickness: thickness)
            : .squircleDonut(diameter: d, cornerRadius: cr, thickness: thickness)
        // Display-P3 stops with an intermediate between each hue pair so the angular gradient
        // never passes through muddy sRGB midpoints (e.g. orange→green turning brown).
        let auroraColors: [Color] = [
            Color(.displayP3, red: 0.10, green: 0.50, blue: 1.00),
            Color(.displayP3, red: 0.45, green: 0.40, blue: 1.00),
            Color(.displayP3, red: 0.74, green: 0.34, blue: 0.94),
            Color(.displayP3, red: 0.98, green: 0.30, blue: 0.62),
            Color(.displayP3, red: 1.00, green: 0.36, blue: 0.36),
            Color(.displayP3, red: 1.00, green: 0.60, blue: 0.22),
            Color(.displayP3, red: 0.98, green: 0.82, blue: 0.30),
            Color(.displayP3, red: 0.45, green: 0.88, blue: 0.48),
            Color(.displayP3, red: 0.30, green: 0.82, blue: 0.92),
            Color(.displayP3, red: 0.10, green: 0.50, blue: 1.00)
        ]
        let animateAurora = isShown && continuousAnimation && !reduceMotion

        return ZStack {
            backdropBlurView(mask: maskKind, diameter: d, cornerRadius: cr, thickness: thickness, isCircle: isCircle)
                .frame(width: d, height: d)

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animateAurora)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = (time * 42.0).truncatingRemainder(dividingBy: 360.0)
                // Counter-rotating, slower phase for the soft outer bloom gives the flow depth.
                let bloomPhase = (-time * 27.0).truncatingRemainder(dividingBy: 360.0)
                ZStack {
                    // Layered glow: wide diffuse bloom + medium haze under the crisp rim.
                    Group {
                        if isCircle {
                            Circle()
                                .strokeBorder(AngularGradient(colors: auroraColors, center: .center, angle: .degrees(bloomPhase)), lineWidth: 12)
                                .blur(radius: 12)
                                .opacity(hasSelection ? 0.30 : 0.42)
                            Circle()
                                .strokeBorder(AngularGradient(colors: auroraColors, center: .center, angle: .degrees(phase)), lineWidth: 5)
                                .blur(radius: 4)
                                .opacity(0.55)
                        } else {
                            RoundedRectangle(cornerRadius: cr, style: .continuous)
                                .strokeBorder(AngularGradient(colors: auroraColors, center: .center, angle: .degrees(bloomPhase)), lineWidth: 12)
                                .blur(radius: 12)
                                .opacity(hasSelection ? 0.30 : 0.42)
                            RoundedRectangle(cornerRadius: cr, style: .continuous)
                                .strokeBorder(AngularGradient(colors: auroraColors, center: .center, angle: .degrees(phase)), lineWidth: 5)
                                .blur(radius: 4)
                                .opacity(0.55)
                        }
                    }
                    .allowsHitTesting(false)

                    Color.black.opacity(colorScheme == .dark ? 0.46 : 0.36)
                        .overlay {
                            AngularGradient(colors: auroraColors, center: .center, angle: .degrees(phase))
                                .opacity(hasSelection ? 0.30 : 0.46)
                        }
                        .overlay(activeWedgeOverlay(metrics: metrics, palette: palette).opacity(0.96))
                        .mask {
                            strokeRingMask(isCircle: isCircle, cornerRadius: cr, thickness: thickness)
                        }

                    Group {
                        if isCircle {
                            Circle()
                                .strokeBorder(
                                    AngularGradient(colors: auroraColors, center: .center, angle: .degrees(phase)),
                                    lineWidth: 1.4
                                )
                                .opacity(0.85)
                        } else {
                            RoundedRectangle(cornerRadius: cr, style: .continuous)
                                .strokeBorder(
                                    AngularGradient(colors: auroraColors, center: .center, angle: .degrees(phase)),
                                    lineWidth: 1.4
                                )
                                .opacity(0.85)
                        }
                    }
                }
                .compositingGroup()
            }
        }
        .frame(width: d, height: d)
        .shadow(color: palette.primary.opacity(hasSelection ? 0.38 : 0.24), radius: 16, y: 4)
    }

    // 4. Solid VisionOS Translucent Disc + Vivid Pie Wedge
    private func solidDialBody(
        metrics: LoopArtworkMetrics,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        let d = metrics.ringDiameter
        let frost = settings.glassOpacity
        let spec = settings.glassSpecularIntensity
        let discTint: Color = colorScheme == .dark
            ? Color(white: 0.20).opacity(0.72 + frost * 0.24)
            : Color(red: 0.95, green: 0.955, blue: 0.965).opacity(0.80 + frost * 0.18)
        let discRim: Color = .white.opacity(colorScheme == .dark ? spec * 0.65 : spec * 0.95)

        return ZStack {
            backdropBlurView(
                mask: .circle(diameter: d),
                diameter: d,
                cornerRadius: d / 2,
                thickness: d / 2,
                isCircle: true,
                isSolidDisc: true
            )
            .frame(width: d, height: d)

            ZStack {
                Circle().fill(discTint)
                activeWedgeOverlay(metrics: metrics, palette: palette)
                    .opacity(0.94)
                    .clipShape(Circle())
                Circle()
                    .strokeBorder(discRim, lineWidth: isAppleGlassTheme ? 1.0 : 0.85)
            }
            .compositingGroup()
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.16), radius: 16, y: 6)
    }

    // 5. Minimal Architectural Halo
    private func minimalHaloBody(
        metrics: LoopArtworkMetrics,
        palette: (primary: Color, secondary: Color)
    ) -> some View {
        let d = metrics.ringDiameter
        let thin = min(16, max(8, metrics.thickness))
        let hasSelection = selectedIndex != nil
        let frost = settings.glassOpacity
        let spec = settings.glassSpecularIntensity
        let haloBase: Color = colorScheme == .dark ? .white.opacity(frost * 0.48) : .white.opacity(frost * 0.90)

        return ZStack {
            backdropBlurView(
                mask: .donut(diameter: d, thickness: thin),
                diameter: d,
                cornerRadius: d / 2,
                thickness: thin,
                isCircle: true
            )
            .frame(width: d, height: d)

            ZStack {
                Circle()
                    .strokeBorder(haloBase, lineWidth: thin)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: thin)

                if hasSelection {
                    activeWedgeOverlay(
                        metrics: metrics,
                        palette: palette,
                        sweep: max(36, metrics.wedgeSweep * 0.90)
                    )
                    .mask {
                        Circle().strokeBorder(.black, lineWidth: thin)
                    }
                    .shadow(color: palette.primary.opacity(0.50), radius: 7)
                }

                if isAppleGlassTheme {
                    Circle().strokeBorder(Color.white.opacity(spec * 0.90), lineWidth: 0.8)
                }
            }
            .compositingGroup()
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.18), radius: 10)
    }
}

// MARK: - Appear Effects (卷动 / 闪现，仅作用于 Loop 圆环)

/// Geometry of the ring while hidden; the reveal/hide animation interpolates to identity.
struct LoopAppearEffect: ViewModifier {
    let style: AppearAnimationStyle
    let isShown: Bool

    func body(content: Content) -> some View {
        switch style {
        case .roll:
            // Tips forward around the horizontal axis with perspective, like a window
            // curling into place, while settling from slightly smaller.
            content
                .rotation3DEffect(
                    .degrees(isShown ? 0 : 68),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    perspective: 0.55
                )
                .scaleEffect(isShown ? 1.0 : 0.88)
                .opacity(isShown ? 1.0 : 0.0)
        case .flash:
            content
                .scaleEffect(isShown ? 1.0 : 0.97)
                .opacity(isShown ? 1.0 : 0.0)
        }
    }
}

// MARK: - Ring Particles: slice rim glow + burst at the pointed app (no ambient particles)

/// Smooths the wedge angle inside the particle canvas so the rim glow follows the slice's own
/// spring instead of jumping to the target. A reference type so the per-frame draw can update it.
private final class LoopGlintTracker {
    var angle: Double?
    var lastTime: TimeInterval = 0
}

/// Real-time physics particle layer powered by Vortex (MIT) around the radial ring.
private struct LoopVortexParticleLayer: View {
    let style: LoopParticleStyle
    let metrics: LoopArtworkMetrics
    let palette: (primary: Color, secondary: Color)
    let selectedIndex: Int?
    let burstTime: TimeInterval
    let burstAngleRad: Double
    let activeTimeline: Bool
    var frameRate: Int = 60

    @State private var systemVersion: Int = 0

    var body: some View {
        GeometryReader { geo in
            let side = max(120, min(geo.size.width, geo.size.height))
            let ringNorm = min(0.46, max(0.18, Double(metrics.ringDiameter * 0.54) / Double(side)))
            let system = Self.makeSystem(
                style: style,
                ringRadiusNorm: ringNorm,
                palette: palette,
                isEnergetic: activeTimeline || selectedIndex != nil
            )

            VortexViewReader { proxy in
                VortexView(system, targetFrameRate: frameRate) {
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .blendMode(.plusLighter)
                        .tag("circle")
                    Image(systemName: "sparkle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .blendMode(.plusLighter)
                        .tag("sparkle")
                }
                .id("\(style.rawValue)-\(systemVersion)")
                .allowsHitTesting(false)
                .onChange(of: burstTime) { _, _ in
                    let r = Double(metrics.ringDiameter * 0.58)
                    let px = Double(geo.size.width) * 0.5 + cos(burstAngleRad) * r
                    let py = Double(geo.size.height) * 0.5 + sin(burstAngleRad) * r
                    proxy.move(to: CGPoint(x: px, y: py))
                    proxy.burst()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        proxy.move(to: CGPoint(x: Double(geo.size.width) * 0.5, y: Double(geo.size.height) * 0.5))
                    }
                }
                .onChange(of: style) { _, _ in
                    systemVersion &+= 1
                }
                .onChange(of: palette.primary) { _, _ in
                    systemVersion &+= 1
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func vortexColor(_ color: SwiftUI.Color, opacity: Double = 1.0) -> VortexSystem.Color {
        let ns = NSColor(color).usingColorSpace(.sRGB)
            ?? NSColor.controlAccentColor.usingColorSpace(.sRGB)
            ?? NSColor.systemBlue
        return VortexSystem.Color(
            red: Double(ns.redComponent),
            green: Double(ns.greenComponent),
            blue: Double(ns.blueComponent),
            opacity: Double(ns.alphaComponent) * opacity
        )
    }

    private static func makeSystem(
        style: LoopParticleStyle,
        ringRadiusNorm: Double,
        palette: (primary: Color, secondary: Color),
        isEnergetic: Bool
    ) -> VortexSystem {
        let p1 = vortexColor(palette.primary)
        let p1Soft = vortexColor(palette.primary, opacity: 0.85)
        let p1Fade = vortexColor(palette.primary, opacity: 0)
        let p2 = vortexColor(palette.secondary)
        let p2Fade = vortexColor(palette.secondary, opacity: 0)

        switch style {
        case .vortexMagic:
            return VortexSystem(
                tags: ["sparkle"],
                shape: .ring(radius: ringRadiusNorm),
                birthRate: isEnergetic ? 52 : 24,
                burstCount: 28,
                burstCountVariation: 8,
                lifespan: 1.25,
                speed: 0.08,
                speedVariation: 0.25,
                angleRange: .degrees(360),
                angularSpeedVariation: [0, 0, 8],
                colors: .random(p1, p2, .white, p1Soft),
                size: 0.42,
                sizeVariation: 0.35,
                sizeMultiplierAtDeath: 0.01
            )

        case .vortexFireworks:
            let blueFade = VortexSystem.Color(red: 0, green: 122.0 / 255.0, blue: 1, opacity: 0)
            let orangeFade = VortexSystem.Color(red: 1, green: 149.0 / 255.0, blue: 0, opacity: 0)
            let explosion = VortexSystem(
                tags: ["circle"],
                spawnOccasion: .onDeath,
                birthRate: 60_000,
                emissionLimit: 160,
                speed: 0.46,
                speedVariation: 0.65,
                angleRange: .degrees(360),
                acceleration: [0, 0.85],
                dampingFactor: 3.4,
                colors: .randomRamp(
                    [.white, p1, p1Fade],
                    [.white, p2, p2Fade],
                    [.white, .cyan, blueFade],
                    [.white, .pink, orangeFade]
                ),
                size: 0.16,
                sizeVariation: 0.08,
                sizeMultiplierAtDeath: 0
            )
            return VortexSystem(
                tags: ["circle"],
                secondarySystems: [explosion],
                shape: .ring(radius: ringRadiusNorm),
                birthRate: isEnergetic ? 4.0 : 1.8,
                burstCount: 5,
                lifespan: 0.44,
                speed: 0.55,
                speedVariation: 0.35,
                angleRange: .degrees(360),
                dampingFactor: 2.2,
                colors: .ramp(.white, p1),
                size: 0.16,
                stretchFactor: 3.0
            )

        case .vortexSpark:
            return VortexSystem(
                tags: ["circle"],
                shape: .ring(radius: ringRadiusNorm),
                birthRate: isEnergetic ? 115 : 48,
                burstCount: 36,
                burstCountVariation: 10,
                lifespan: 0.95,
                speed: 0.85,
                speedVariation: 0.45,
                angleRange: .degrees(360),
                acceleration: [0, 1.35],
                dampingFactor: 3.2,
                colors: .ramp(.white, p1, p2Fade),
                size: 0.13,
                sizeVariation: 0.08,
                stretchFactor: 6.0
            )

        default:
            return VortexSystem(tags: ["circle"], birthRate: 0)
        }
    }
}

private struct LoopParticleCanvas: View {
    let style: LoopParticleStyle
    let metrics: LoopArtworkMetrics
    let palette: (primary: Color, secondary: Color)
    let selectedIndex: Int?
    let wedgeRotationDegrees: Double
    let burstTime: TimeInterval
    let burstAngleRad: Double
    let activeTimeline: Bool
    var frameRate: Double = 120
    var isDark: Bool = false

    @State private var tracker = LoopGlintTracker()

    private static func noise(_ i: Int, _ salt: Int) -> Double {
        let x = sin(Double(i * 127 + salt * 311) * 12.9898) * 43758.5453
        return x - floor(x)
    }

    private static func circle(_ p: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }

    private static func fourPointStar(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, rotation: Double) -> Path {
        var path = Path()
        for idx in 0..<8 {
            let r = (idx % 2 == 0) ? outerRadius : innerRadius
            let a = rotation + Double(idx) * (.pi / 4.0)
            let pt = CGPoint(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r)
            if idx == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / frameRate, paused: !activeTimeline)) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            Canvas { ctx, size in
                draw(ctx: &ctx, size: size, now: now)
            }
        }
        .allowsHitTesting(false)
    }

    private func smoothedSliceAngle(now: TimeInterval, hasSelection: Bool) -> Double {
        let targetRad = (wedgeRotationDegrees - 90.0) * .pi / 180.0
        let dt = min(0.05, max(0, now - tracker.lastTime))
        tracker.lastTime = now
        if let current = tracker.angle, hasSelection {
            let diff = atan2(sin(targetRad - current), cos(targetRad - current))
            tracker.angle = current + diff * (1 - exp(-dt / 0.06))
        } else {
            tracker.angle = targetRad
        }
        return tracker.angle ?? targetRad
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringR = metrics.ringDiameter / 2
        let hasSelection = selectedIndex != nil
        let sliceRad = smoothedSliceAngle(now: now, hasSelection: hasSelection)
        let halfSweep = metrics.wedgeSweep * .pi / 360.0

        switch style {
        case .off, .vortexMagic, .vortexFireworks, .vortexSpark:
            return
        case .sparkBurst:
            drawRimArcGlow(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, halfSweep: halfSweep, hasSelection: hasSelection)
            drawSparkBurst(ctx: &ctx, center: center, now: now)
        case .orbitalDust:
            drawRimArcGlow(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, halfSweep: halfSweep, hasSelection: hasSelection)
            drawOrbitalDust(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, hasSelection: hasSelection, now: now)
        case .auroraRibbon:
            drawAuroraRibbon(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, halfSweep: halfSweep, hasSelection: hasSelection, now: now)
        case .liquidRipple:
            drawLiquidRipple(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, halfSweep: halfSweep, hasSelection: hasSelection, now: now)
        case .starlightConfetti:
            drawRimArcGlow(ctx: &ctx, center: center, ringR: ringR, sliceRad: sliceRad, halfSweep: halfSweep, hasSelection: hasSelection)
            drawStarlightConfetti(ctx: &ctx, center: center, now: now)
        }
    }

    private func drawRimArcGlow(
        ctx: inout GraphicsContext,
        center: CGPoint,
        ringR: CGFloat,
        sliceRad: Double,
        halfSweep: Double,
        hasSelection: Bool
    ) {
        guard hasSelection else { return }
        let rimR = ringR + 3
        var rim = Path()
        rim.addArc(
            center: center,
            radius: rimR,
            startAngle: .radians(sliceRad - halfSweep),
            endAngle: .radians(sliceRad + halfSweep),
            clockwise: false
        )
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.stroke(
                rim,
                with: .color(palette.primary.opacity(isDark ? 0.85 : 0.70)),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
        }
    }

    private func drawSparkBurst(ctx: inout GraphicsContext, center: CGPoint, now: TimeInterval) {
        let life: TimeInterval = 0.52
        let elapsed = now - burstTime
        guard burstTime > 0, elapsed >= 0, elapsed < life else { return }

        let glow = palette.primary
        let core = isDark ? Color.white : palette.primary
        let t = elapsed / life
        let fade = pow(1 - t, 1.5)
        let iconCenter = CGPoint(
            x: center.x + cos(burstAngleRad) * metrics.orbit,
            y: center.y + sin(burstAngleRad) * metrics.orbit
        )
        let startR = metrics.iconSize * 0.56
        let sparkCount = 14
        struct Spark { let head: CGPoint; let tail: CGPoint; let width: CGFloat; let isCore: Bool }
        var sparks: [Spark] = []

        for k in 0..<sparkCount {
            let a = Double(k) / Double(sparkCount) * 2 * .pi + (Self.noise(k, 7) - 0.5) * 0.35
            let speed = 58 + Self.noise(k, 8) * 72
            let drag = 6.4
            func dist(_ tt: Double) -> Double { speed * (1 - exp(-drag * tt)) / drag }
            let d1 = startR + dist(elapsed)
            let d0 = startR + dist(max(0, elapsed - 0.07))
            sparks.append(Spark(
                head: CGPoint(x: iconCenter.x + cos(a) * d1, y: iconCenter.y + sin(a) * d1),
                tail: CGPoint(x: iconCenter.x + cos(a) * d0, y: iconCenter.y + sin(a) * d0),
                width: CGFloat(1.1 + Self.noise(k, 9) * 1.2) * CGFloat(1 - t * 0.68),
                isCore: k % 3 == 0
            ))
        }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            for sp in sparks {
                var p = Path()
                p.move(to: sp.tail)
                p.addLine(to: sp.head)
                layer.stroke(p, with: .color(glow.opacity(0.70 * fade)), style: StrokeStyle(lineWidth: sp.width * 2.6, lineCap: .round))
            }
        }
        for sp in sparks {
            var p = Path()
            p.move(to: sp.tail)
            p.addLine(to: sp.head)
            ctx.stroke(p, with: .color((sp.isCore ? core : glow).opacity(fade)), style: StrokeStyle(lineWidth: sp.width, lineCap: .round))
        }

        let rippleR = metrics.iconSize * (0.55 + 0.45 * (1 - pow(1 - t, 3)))
        ctx.stroke(
            Self.circle(iconCenter, rippleR),
            with: .color(glow.opacity(0.55 * fade)),
            style: StrokeStyle(lineWidth: 1.5 * CGFloat(1 - t) + 0.5)
        )
    }

    private func drawOrbitalDust(
        ctx: inout GraphicsContext,
        center: CGPoint,
        ringR: CGFloat,
        sliceRad: Double,
        hasSelection: Bool,
        now: TimeInterval
    ) {
        let moteCount = 24
        let glow = palette.primary
        let accent = palette.secondary
        let core = isDark ? Color.white : palette.primary
        let baseOrbitR = ringR + 8

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.2))
            for idx in 0..<moteCount {
                let speed = 0.42 + Self.noise(idx, 11) * 0.48
                let theta = Double(idx) / Double(moteCount) * 2 * .pi + now * speed
                let radialDrift = sin(now * (1.8 + Self.noise(idx, 13)) + Double(idx)) * 7.5
                let r = baseOrbitR + CGFloat(radialDrift)
                let pt = CGPoint(x: center.x + CGFloat(cos(theta)) * r, y: center.y + CGFloat(sin(theta)) * r)

                let angleDiff = abs(atan2(sin(theta - sliceRad), cos(theta - sliceRad)))
                let focusBoost: Double = hasSelection ? max(0, 1.0 - angleDiff / 1.1) : 0.22
                let alpha = (0.28 + 0.58 * focusBoost) * (0.75 + 0.25 * sin(now * 2.4 + Double(idx)))
                let dotR = CGFloat(1.3 + Self.noise(idx, 17) * 1.8 + focusBoost * 1.2)
                let color = (idx % 3 == 0) ? accent : glow
                layer.fill(Self.circle(pt, dotR * 1.4), with: .color(color.opacity(alpha * 0.72)))
            }
        }

        for idx in 0..<moteCount {
            let speed = 0.42 + Self.noise(idx, 11) * 0.48
            let theta = Double(idx) / Double(moteCount) * 2 * .pi + now * speed
            let radialDrift = sin(now * (1.8 + Self.noise(idx, 13)) + Double(idx)) * 7.5
            let r = baseOrbitR + CGFloat(radialDrift)
            let pt = CGPoint(x: center.x + CGFloat(cos(theta)) * r, y: center.y + CGFloat(sin(theta)) * r)
            let angleDiff = abs(atan2(sin(theta - sliceRad), cos(theta - sliceRad)))
            let focusBoost: Double = hasSelection ? max(0, 1.0 - angleDiff / 1.1) : 0.22
            let alpha = 0.32 + 0.62 * focusBoost
            let dotR = CGFloat(0.9 + Self.noise(idx, 17) * 1.1 + focusBoost * 0.7)
            ctx.fill(Self.circle(pt, dotR), with: .color((focusBoost > 0.55 ? core : glow).opacity(alpha)))
        }

        let elapsed = now - burstTime
        let pulseLife: TimeInterval = 0.48
        if burstTime > 0, elapsed >= 0, elapsed < pulseLife {
            let t = elapsed / pulseLife
            let fade = pow(1 - t, 1.6)
            let iconCenter = CGPoint(x: center.x + cos(burstAngleRad) * metrics.orbit, y: center.y + sin(burstAngleRad) * metrics.orbit)
            let pulseR = metrics.iconSize * (0.52 + 0.40 * (1 - pow(1 - t, 3)))
            ctx.stroke(Self.circle(iconCenter, pulseR), with: .color(core.opacity(0.65 * fade)), style: StrokeStyle(lineWidth: 1.4))
        }
    }

    private func drawAuroraRibbon(
        ctx: inout GraphicsContext,
        center: CGPoint,
        ringR: CGFloat,
        sliceRad: Double,
        halfSweep: Double,
        hasSelection: Bool,
        now: TimeInterval
    ) {
        let ribbonR = ringR + 5
        let phaseA = now * 0.95
        let phaseB = -now * 0.65

        var arcA = Path()
        arcA.addArc(center: center, radius: ribbonR, startAngle: .radians(phaseA), endAngle: .radians(phaseA + 2.3), clockwise: false)
        var arcB = Path()
        arcB.addArc(center: center, radius: ribbonR + 3, startAngle: .radians(phaseB), endAngle: .radians(phaseB + 1.9), clockwise: false)

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.stroke(arcA, with: .color(palette.primary.opacity(isDark ? 0.68 : 0.55)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            layer.stroke(arcB, with: .color(palette.secondary.opacity(isDark ? 0.60 : 0.48)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            if hasSelection {
                var focusArc = Path()
                focusArc.addArc(center: center, radius: ringR + 3, startAngle: .radians(sliceRad - halfSweep * 1.15), endAngle: .radians(sliceRad + halfSweep * 1.15), clockwise: false)
                layer.stroke(focusArc, with: .color((isDark ? Color.white : palette.primary).opacity(0.75)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }

            for orbIdx in 0..<4 {
                let a = now * (0.55 + Double(orbIdx) * 0.14) + Double(orbIdx) * (.pi / 2.0)
                let rr = ribbonR + CGFloat(sin(now * 1.7 + Double(orbIdx)) * 5)
                let pt = CGPoint(x: center.x + CGFloat(cos(a)) * rr, y: center.y + CGFloat(sin(a)) * rr)
                layer.fill(Self.circle(pt, 5.5), with: .color((orbIdx % 2 == 0 ? palette.primary : palette.secondary).opacity(0.50)))
            }
        }

        let elapsed = now - burstTime
        let waveLife: TimeInterval = 0.55
        if burstTime > 0, elapsed >= 0, elapsed < waveLife {
            let t = elapsed / waveLife
            let fade = pow(1 - t, 1.5)
            let span = 0.35 + t * 1.45
            var pulseArc = Path()
            pulseArc.addArc(center: center, radius: ribbonR + CGFloat(t * 8), startAngle: .radians(burstAngleRad - span * 0.5), endAngle: .radians(burstAngleRad + span * 0.5), clockwise: false)
            ctx.stroke(pulseArc, with: .color((isDark ? Color.white : palette.primary).opacity(0.75 * fade)), style: StrokeStyle(lineWidth: 2.2 * CGFloat(1 - t * 0.5), lineCap: .round))
        }
    }

    private func drawLiquidRipple(
        ctx: inout GraphicsContext,
        center: CGPoint,
        ringR: CGFloat,
        sliceRad: Double,
        halfSweep: Double,
        hasSelection: Bool,
        now: TimeInterval
    ) {
        let rimColor = isDark ? Color.white.opacity(0.68) : palette.primary.opacity(0.65)
        if hasSelection {
            var glint = Path()
            glint.addArc(center: center, radius: ringR + 2.5, startAngle: .radians(sliceRad - halfSweep * 0.85), endAngle: .radians(sliceRad + halfSweep * 0.85), clockwise: false)
            ctx.stroke(glint, with: .color(rimColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }

        let life: TimeInterval = 0.62
        let elapsed = now - burstTime
        guard burstTime > 0, elapsed >= 0, elapsed < life else { return }

        let iconCenter = CGPoint(x: center.x + cos(burstAngleRad) * metrics.orbit, y: center.y + sin(burstAngleRad) * metrics.orbit)
        let strokeBase = isDark ? Color.white : palette.primary

        for ringIdx in 0..<3 {
            let delay = Double(ringIdx) * 0.08
            let localElapsed = elapsed - delay
            guard localElapsed >= 0 else { continue }
            let duration = life - delay
            let t = min(1, localElapsed / max(0.1, duration))
            let eased = 1 - pow(1 - t, 3)
            let fade = pow(1 - t, 1.65)
            let radius = metrics.iconSize * (0.48 + 0.68 * eased)
            let width = CGFloat((ringIdx == 0 ? 2.0 : 1.3) * (1 - t * 0.6))
            ctx.stroke(
                Self.circle(iconCenter, radius),
                with: .color(strokeBase.opacity((ringIdx == 0 ? 0.72 : 0.48) * fade)),
                style: StrokeStyle(lineWidth: width)
            )
        }
    }

    private func drawStarlightConfetti(ctx: inout GraphicsContext, center: CGPoint, now: TimeInterval) {
        let life: TimeInterval = 0.62
        let elapsed = now - burstTime
        guard burstTime > 0, elapsed >= 0, elapsed < life else { return }

        let glow = palette.primary
        let accent = palette.secondary
        let core = isDark ? Color.white : palette.primary
        let t = elapsed / life
        let fade = pow(1 - t, 1.45)
        let iconCenter = CGPoint(x: center.x + cos(burstAngleRad) * metrics.orbit, y: center.y + sin(burstAngleRad) * metrics.orbit)

        for idx in 0..<12 {
            let baseAngle = Double(idx) / 12.0 * 2 * .pi + (Self.noise(idx, 21) - 0.5) * 0.35
            let speed = 34 + Self.noise(idx, 23) * 48
            let drag = 4.2
            let dist = metrics.iconSize * 0.44 + speed * (1 - exp(-drag * elapsed)) / drag
            let liftY = CGFloat(-elapsed * (10 + Self.noise(idx, 27) * 14))
            let pt = CGPoint(x: iconCenter.x + CGFloat(cos(baseAngle) * dist), y: iconCenter.y + CGFloat(sin(baseAngle) * dist) + liftY)

            let scaleFade = CGFloat(1 - t * 0.55)
            let outerR = CGFloat(3.4 + Self.noise(idx, 29) * 2.8) * scaleFade
            let rot = elapsed * (idx % 2 == 0 ? 1.8 : -1.8) + Self.noise(idx, 31)
            let starPath = Self.fourPointStar(center: pt, outerRadius: outerR, innerRadius: outerR * 0.34, rotation: rot)
            let fillColor = (idx % 3 == 0) ? core : ((idx % 2 == 0) ? glow : accent)

            ctx.fill(starPath, with: .color(fillColor.opacity(fade * 0.92)))
        }
    }
}

private struct LoopArtworkMetrics {
    let ringDiameter: CGFloat
    let thickness: CGFloat
    let cornerRadius: CGFloat
    let iconSize: CGFloat
    let centerIconSize: CGFloat
    let orbit: CGFloat
    let wedgeSweep: Double

    init(settings: StageSettings, count: Int) {
        let overall = CGFloat(settings.radialRingDiameter)
        ringDiameter = min(192, max(122, (overall * 0.505).rounded()))
        let rawThickness = CGFloat(settings.radialThickness)
        thickness = min(ringDiameter * 0.42, max(10, rawThickness))
        let ratio = min(1.0, max(0.22, settings.radialStyle == .squircle ? min(0.75, settings.radialCornerRatio) : settings.radialCornerRatio))
        cornerRadius = (ringDiameter / 2.0) * CGFloat(ratio)
        iconSize = min(76, max(24, CGFloat(settings.radialIconSize)))
        let maxCenter: CGFloat = (settings.radialStyle == .solidDial)
            ? (ringDiameter * 0.46)
            : max(32, (ringDiameter - thickness * 2) * 0.76)
        centerIconSize = min(maxCenter, max(26, (iconSize * 0.96).rounded()))
        orbit = ringDiameter / 2 + 16 + iconSize / 2
        wedgeSweep = count > 0 ? min(100, max(38, 360.0 / Double(count))) : 0
    }

    static func panelSize(for settings: StageSettings) -> CGFloat {
        let m = LoopArtworkMetrics(settings: settings, count: 6)
        let maxExtent = (m.orbit + 6) + (m.iconSize * 1.28 / 2.0) + 28
        return max(CGFloat(settings.radialRingDiameter) + 68, ceil(maxExtent * 2.0))
    }
}

private struct LoopArtworkSatellite: View {
    let item: LoopRadialRenderItem
    let index: Int
    let count: Int
    let metrics: LoopArtworkMetrics
    let selectedIndex: Int?
    var committedIndex: Int? = nil
    let isShown: Bool
    let accent: Color
    var appearStyle: AppearAnimationStyle = .roll

    var body: some View {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(1, count))
        let isCommitted = !isShown && committedIndex == index
        let isSelected = selectedIndex == index || isCommitted
        let anySelected = selectedIndex != nil
        // On commit the picked icon swells and drifts outward while the rest fold inward.
        // "闪现" keeps icons in place and only fades; the other styles fly them out from the center.
        let flash = appearStyle == .flash
        let hiddenRadius = flash ? metrics.orbit : metrics.orbit * 0.58
        let hiddenScale: CGFloat = flash ? 1.0 : 0.45
        let targetRadius = isCommitted
            ? metrics.orbit + 14
            : (isShown ? (metrics.orbit + (isSelected ? 5 : 0)) : hiddenRadius)
        let targetScale: CGFloat = isCommitted ? 1.55 : (!isShown ? hiddenScale : (isSelected ? 1.26 : (anySelected ? 0.92 : 1.0)))
        let iconSaturation: Double = item.isRunning ? 1.0 : (isSelected ? 0.95 : 0.28)
        let iconOpacity: Double = !isShown
            ? 0.0
            : (item.isRunning
               ? (isSelected || !anySelected ? 1.0 : 0.88)
               : (isSelected ? 0.98 : (anySelected ? 0.42 : 0.54)))

        Image(nsImage: item.icon)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: metrics.iconSize, height: metrics.iconSize)
            .saturation(iconSaturation)
            .background {
                // Always in the tree so the glow fades instead of popping in/out.
                RoundedRectangle(cornerRadius: metrics.iconSize * 0.28, style: .continuous)
                    .fill(accent.opacity(isSelected ? 0.30 : 0))
                    .blur(radius: 8)
            }
            .overlay(alignment: .topTrailing) {
                if let badge = item.badgeLabel, !badge.isEmpty {
                    LoopRedBadge(label: badge)
                        .offset(x: 4, y: -3)
                }
            }
            .shadow(color: .black.opacity(isSelected ? 0.30 : 0.16), radius: isSelected ? 7 : 3, y: 2)
            .scaleEffect(targetScale)
            .opacity(iconOpacity)
            .offset(x: cos(angle) * targetRadius, y: sin(angle) * targetRadius)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.72)
                    .delay(isShown ? Double(index) * 0.014 : 0),
                value: isShown
            )
            .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.78), value: selectedIndex)
    }
}

private struct LoopRedBadge: View {
    let label: String
    private var displayLabel: String { label.count > 3 ? "99+" : label }

    var body: some View {
        let single = displayLabel.count <= 1
        Text(displayLabel)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, single ? 0 : 4)
            .frame(minWidth: 15, minHeight: 15)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.27, blue: 0.23),
                                Color(red: 0.90, green: 0.16, blue: 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.6))
            )
            .shadow(color: Color.black.opacity(0.28), radius: 2, y: 1)
    }
}

// MARK: - Loop Preview View (120Hz Screen-Space Morphing Frosted Glass Card)

private struct LoopPreviewView: View {
    @ObservedObject var coordinator: StageCoordinator
    @ObservedObject var state: LoopRadialState

    private var previewMaterial: Material {
        switch coordinator.settings.glassStyle {
        case .clear: return .ultraThinMaterial
        case .regular: return .regularMaterial
        case .frosted: return .thickMaterial
        }
    }

    var body: some View {
        let palette = LoopThemeColors.colors(for: coordinator.settings)
        let radius = CGFloat(coordinator.settings.previewCornerRadius)
        let borderW = CGFloat(coordinator.settings.previewBorderThickness)
        let apps = state.sessionApps.isEmpty ? coordinator.radialDisplayedApps : state.sessionApps
        let isPureSplitPreview = (state.mode == .splitLayout) || (state.pendingFillFrameQuartz != nil)
        let activeItem: StageAppItem? = isPureSplitPreview
            ? nil
            : state.selectedIndex.flatMap { $0 >= 0 && $0 < apps.count ? apps[$0] : nil }
        let targetRect = state.previewTargetRectLocal

        GeometryReader { _ in
            if targetRect.width > 12, targetRect.height > 12 {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(previewMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [palette.primary.opacity(0.12), palette.secondary.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    if let item = activeItem {
                        let isRunning = coordinator.runtimeInfo[item.bundleIdentifier]?.isRunning == true
                        VStack(spacing: 10) {
                            Image(nsImage: coordinator.discovery.icon(for: item))
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .saturation(isRunning ? 1.0 : 0.78)
                                .shadow(color: .black.opacity(0.22), radius: 8, y: 3)

                            Text(item.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(16)
                    }

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.26), lineWidth: 1)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: coordinator.settings.radialTheme == .appleGlass
                                    ? [Color.white.opacity(0.90), palette.secondary.opacity(0.80)]
                                    : [palette.primary, palette.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: borderW
                        )
                        .shadow(color: palette.primary.opacity(0.32), radius: 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .frame(width: targetRect.width, height: targetRect.height)
                .position(x: targetRect.midX, y: targetRect.midY)
                .opacity(state.previewVisible ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Geometric Shapes & Blur Helpers

/// Pie wedge pointing straight up (-90°); callers rotate it with `.rotationEffect`.
private struct LoopPieSliceShape: Shape {
    var sweepDegrees: Double
    private let centerAngleDegrees: Double = -90.0

    init(sweepDegrees: Double) {
        self.sweepDegrees = sweepDegrees
    }

    var animatableData: Double {
        get { sweepDegrees }
        set { sweepDegrees = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        var p = Path()
        p.move(to: c)
        p.addArc(
            center: c,
            radius: r,
            startAngle: .degrees(centerAngleDegrees - sweepDegrees / 2.0),
            endAngle: .degrees(centerAngleDegrees + sweepDegrees / 2.0),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

private func nativeGlassMaterial(for style: AppleGlassStyle) -> NSVisualEffectView.Material {
    switch style {
    case .clear: return .underWindowBackground
    case .regular: return .hudWindow
    case .frosted: return .menu
    }
}

private func nativeGlassBlurAlpha(style: AppleGlassStyle, opacity: Double) -> CGFloat {
    switch style {
    case .clear: return min(1.0, max(0.42, CGFloat(0.42 + opacity * 0.75)))
    case .regular: return min(1.0, max(0.55, CGFloat(0.58 + opacity * 0.60)))
    case .frosted: return min(1.0, max(0.72, CGFloat(0.74 + opacity * 0.36)))
    }
}

private struct LoopBlurView: NSViewRepresentable {
    enum MaskKind: Equatable {
        case donut(diameter: CGFloat, thickness: CGFloat)
        case squircleDonut(diameter: CGFloat, cornerRadius: CGFloat, thickness: CGFloat)
        case circle(diameter: CGFloat)
        case roundedRect(radius: CGFloat)
        case full
    }

    let material: NSVisualEffectView.Material
    let mask: MaskKind
    var blurAlpha: CGFloat = 1.0

    final class Coordinator {
        var lastMask: MaskKind?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = blurAlpha
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.alphaValue = blurAlpha
        guard context.coordinator.lastMask != mask else { return }
        context.coordinator.lastMask = mask
        switch mask {
        case .full:
            view.maskImage = nil
        case .donut(let diameter, let thickness):
            view.maskImage = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
                let path = NSBezierPath(ovalIn: rect)
                let inner = rect.insetBy(dx: thickness, dy: thickness)
                if inner.width > 0, inner.height > 0 {
                    path.append(NSBezierPath(ovalIn: inner))
                }
                path.windingRule = .evenOdd
                NSColor.black.setFill()
                path.fill()
                return true
            }
        case .squircleDonut(let diameter, let cornerRadius, let thickness):
            view.maskImage = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
                let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                let inner = rect.insetBy(dx: thickness, dy: thickness)
                if inner.width > 0, inner.height > 0 {
                    let innerCR = max(2, cornerRadius - thickness)
                    path.append(NSBezierPath(roundedRect: inner, xRadius: innerCR, yRadius: innerCR))
                }
                path.windingRule = .evenOdd
                NSColor.black.setFill()
                path.fill()
                return true
            }
        case .circle(let diameter):
            view.maskImage = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(ovalIn: rect).fill()
                return true
            }
        case .roundedRect(let radius):
            let side = radius * 2 + 1
            let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
                return true
            }
            image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
            image.resizingMode = .stretch
            view.maskImage = image
        }
    }
}
