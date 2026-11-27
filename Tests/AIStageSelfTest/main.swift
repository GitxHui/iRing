import AIStageCore
import CoreGraphics
import Foundation

var passed = 0
var failed = 0

func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if condition {
        passed += 1
        print("  [PASS] \(message)")
    } else {
        failed += 1
        print("  [FAIL] \(message) (\(file):\(line))")
    }
}

print("Running AIStageCore Self-Tests...")

// 1. Quartz <-> AppKit round-trip on primary & negative-X secondary display
do {
    let primaryHeight: CGFloat = 1080
    let primaryQ = CGRect(x: 200, y: 80, width: 1100, height: 800)
    let primaryA = DisplayGeometry.quartzToAppKit(primaryQ, primaryHeight: primaryHeight)
    expect(primaryA == CGRect(x: 200, y: 200, width: 1100, height: 800), "Primary Quartz->AppKit conversion")
    expect(DisplayGeometry.appKitToQuartz(primaryA, primaryHeight: primaryHeight) == primaryQ, "Primary AppKit->Quartz round-trip")

    let leftQ = CGRect(x: -1500, y: 40, width: 1200, height: 900)
    let leftA = DisplayGeometry.quartzToAppKit(leftQ, primaryHeight: primaryHeight)
    expect(leftA == CGRect(x: -1500, y: 140, width: 1200, height: 900), "Secondary negative-X Quartz->AppKit conversion")
    expect(DisplayGeometry.appKitToQuartz(leftA, primaryHeight: primaryHeight) == leftQ, "Secondary negative-X round-trip")

    let scrPrimary = DisplayGeometry.ScreenInfo(
        id: "primary",
        frameAppKit: CGRect(x: 0, y: 0, width: 2304, height: 1296),
        visibleFrameAppKit: CGRect(x: 0, y: 75, width: 2304, height: 1191),
        primaryHeight: 1296
    )
    let scrSecondary = DisplayGeometry.ScreenInfo(
        id: "secondary",
        frameAppKit: CGRect(x: -1512, y: 314, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: -1512, y: 314, width: 1512, height: 950),
        primaryHeight: 1296
    )
    let pickedPrimary = DisplayGeometry.screen(containingQuartzPoint: CGPoint(x: 600, y: 500), screens: [scrPrimary, scrSecondary])
    let pickedSecondary = DisplayGeometry.screen(containingQuartzPoint: CGPoint(x: -700, y: 200), screens: [scrPrimary, scrSecondary])
    expect(pickedPrimary?.id == "primary" && pickedSecondary?.id == "secondary", "Point-to-screen lookup resolves primary and negative-X secondary displays accurately")

    // Magnetic 4-edge normalized distance snap (standard + ultrawide + secondary display)
    let ultrawide = DisplayGeometry.ScreenInfo(
        id: "ultrawide",
        frameAppKit: CGRect(x: 0, y: 0, width: 3440, height: 1440),
        visibleFrameAppKit: CGRect(x: 0, y: 60, width: 3440, height: 1355),
        primaryHeight: 1440
    )
    expect(
        DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: 1720, y: 80), on: ultrawide) == .top
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: 1720, y: 1320), on: ultrawide) == .bottom
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: 180, y: 400), on: ultrawide) == .left
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: 3260, y: 400), on: ultrawide) == .right,
        "nearestEdge snaps cleanly to top/bottom/left/right without ultrawide bias"
    )
    expect(
        DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: -1460, y: 450), on: scrSecondary) == .left
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: -60, y: 450), on: scrSecondary) == .right
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: -756, y: 50), on: scrSecondary) == .top
            && DisplayGeometry.nearestEdge(forQuartzPoint: CGPoint(x: -756, y: 940), on: scrSecondary) == .bottom,
        "nearestEdge handles negative-X secondary display coordinates accurately"
    )

    // Loop Radial Menu Sector Math & Edge Clamping
    let anchor = CGPoint(x: 500, y: 500)
    let deadzone = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 510, y: 510), itemCount: 4)
    expect(deadzone.index == nil, "Radial center deadzone returns nil (release to cancel)")

    let topPick = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 500, y: 560), itemCount: 4)
    let rightPick = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 560, y: 500), itemCount: 4)
    let bottomPick = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 500, y: 440), itemCount: 4)
    let leftPick = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 440, y: 500), itemCount: 4)
    expect(topPick.index == 0 && rightPick.index == 1 && bottomPick.index == 2 && leftPick.index == 3, "Radial 4-sector angles resolve top/right/bottom/left clockwise")

    let wrapPick = DisplayGeometry.radialSelectedIndex(from: anchor, to: CGPoint(x: 472, y: 552), itemCount: 7)
    expect(wrapPick.index == 6, "Radial 7-item upper-left wrap-around resolves final sector")

    let clampedPrimary = DisplayGeometry.radialPanelRectAppKit(centeredAt: CGPoint(x: 10, y: 80), panelSize: 300, screens: [scrPrimary, scrSecondary])
    expect(clampedPrimary.minX >= scrPrimary.visibleFrameAppKit.minX + 8 && clampedPrimary.minY >= scrPrimary.visibleFrameAppKit.minY + 8, "Radial panel clamps cleanly inside primary screen edges")

    let clampedSecondary = DisplayGeometry.radialPanelRectAppKit(centeredAt: CGPoint(x: -1505, y: 1280), panelSize: 300, screens: [scrPrimary, scrSecondary])
    expect(clampedSecondary.minX >= scrSecondary.visibleFrameAppKit.minX + 8 && clampedSecondary.maxY <= scrSecondary.visibleFrameAppKit.maxY - 8, "Radial panel clamps cleanly inside negative-X secondary edges")

    // Loop-style position preview layouts
    let baseStage = CGRect(x: 100, y: 60, width: 1600, height: 1000)
    let leftL = DisplayGeometry.radialLayoutFrameQuartz(.leftHalf, base: baseStage, screen: scrPrimary, splitGap: 8)
    let rightL = DisplayGeometry.radialLayoutFrameQuartz(.rightHalf, base: baseStage, screen: scrPrimary, splitGap: 8)
    expect(leftL.minX == baseStage.minX && rightL.maxX == baseStage.maxX && rightL.minX - leftL.maxX == 8, "Loop preview left/right halves split the stage with exact gap")
    let maxL = DisplayGeometry.radialLayoutFrameQuartz(.maximize, base: baseStage, screen: scrPrimary, splitGap: 8)
    expect(maxL == scrPrimary.visibleFrameQuartz.integral, "Loop preview maximize fills the visible screen")
    let centerL = DisplayGeometry.radialLayoutFrameQuartz(.center, base: baseStage, screen: scrPrimary, splitGap: 8)
    expect(baseStage.contains(centerL) && abs(centerL.midX - baseStage.midX) <= 1, "Loop preview center layout stays centered inside the stage")
    expect(RadialLayoutTarget.stage.advanced(by: -1) == .center && RadialLayoutTarget.center.advanced(by: 1) == .stage, "Loop layout targets cycle with wrap-around")
}

// 2. Dynamic Island & Loop Radial Stage math on primary & negative-X secondary monitors
do {
    let secondary = DisplayGeometry.ScreenInfo(
        id: "left",
        frameAppKit: CGRect(x: -1512, y: 314, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: -1512, y: 314, width: 1512, height: 950),
        primaryHeight: 1080
    )
    var settings = StageSettings()
    settings.dockGap = 10
    settings.outerMargin = 8

    // Dynamic Island Mode: notched built-in display & non-notched external display
    let notchedScreen = DisplayGeometry.ScreenInfo(
        id: "builtin",
        frameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 950),
        primaryHeight: 982,
        safeAreaTop: 32,
        notchWidth: 185
    )
    var islandSettings = settings
    islandSettings.dockShape = .dynamicIsland
    islandSettings.iconSize = 44
    islandSettings.magnificationScale = 1.42

    let (collapsedNotch, notchStage) = DisplayGeometry.dynamicIslandFramesQuartz(
        on: notchedScreen,
        settings: islandSettings,
        expanded: false,
        desiredExpandedWidth: 420
    )
    expect(collapsedNotch.minY == notchedScreen.frameQuartz.minY, "Collapsed Dynamic Island flush with top notch edge")
    expect(collapsedNotch.width >= 185 + 110, "Collapsed Dynamic Island wings clear physical 185pt camera notch cleanly")
    expect(abs(collapsedNotch.midX - notchedScreen.frameQuartz.midX) <= 1, "Collapsed Dynamic Island centered horizontally")
    expect(notchStage.width == notchedScreen.visibleFrameQuartz.width - 16, "Dynamic Island leaves 100% stage width untouched")

    let (expandedNotch, _) = DisplayGeometry.dynamicIslandFramesQuartz(
        on: notchedScreen,
        settings: islandSettings,
        expanded: true,
        desiredExpandedWidth: 440
    )
    expect(expandedNotch.width >= 185 + 230 && expandedNotch.height > 32 + 44 + 24, "Expanded notched Dynamic Island clears camera notch in both header ears and vertical tray")

    let (expandedExternal, extStage) = DisplayGeometry.dynamicIslandFramesQuartz(
        on: secondary,
        settings: islandSettings,
        expanded: true,
        desiredExpandedWidth: 440
    )
    expect(expandedExternal.minY == secondary.frameQuartz.minY, "Expanded external Dynamic Island anchored at screen top")
    expect(expandedExternal.width == 440 && expandedExternal.height > collapsedNotch.height, "Expanded Dynamic Island opens downward for apps + magnification")
    expect(extStage.height == secondary.visibleFrameQuartz.height - 16, "Expanded Dynamic Island preserves full stage height")

    // Bottom / Left / Right Dynamic Island edge geometries
    var bottomSettings = islandSettings
    bottomSettings.islandPosition = .bottom
    let (collapsedBottom, _) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: bottomSettings, expanded: false, desiredExpandedWidth: 440)
    let (expandedBottom, bottomStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: bottomSettings, expanded: true, desiredExpandedWidth: 440)
    expect(collapsedBottom.maxY == secondary.visibleFrameQuartz.maxY && expandedBottom.maxY == secondary.visibleFrameQuartz.maxY, "Bottom Dynamic Island anchored to bottom visible edge")
    expect(DisplayGeometry.popDirection(for: expandedBottom, on: secondary, shape: .dynamicIsland, islandPosition: .bottom) == .up && bottomStage == extStage, "Bottom Dynamic Island pops upward and preserves full stage")

    var leftSettings = islandSettings
    leftSettings.islandPosition = .left
    let (collapsedLeft, _) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: leftSettings, expanded: false, desiredExpandedWidth: 440)
    let (expandedLeft, leftStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: leftSettings, expanded: true, desiredExpandedWidth: 440)
    expect(collapsedLeft.minX == secondary.visibleFrameQuartz.minX && expandedLeft.minX == secondary.visibleFrameQuartz.minX, "Left Dynamic Island anchored flush to left edge")
    expect(expandedLeft.height == 440 && expandedLeft.width > collapsedLeft.width && DisplayGeometry.popDirection(for: expandedLeft, on: secondary, shape: .dynamicIsland, islandPosition: .left) == .right && leftStage == extStage, "Left Dynamic Island expands vertically rightward and preserves full stage")

    var rightSettings = islandSettings
    rightSettings.islandPosition = .right
    let (collapsedRight, _) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: rightSettings, expanded: false, desiredExpandedWidth: 440)
    let (expandedRight, rightStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: rightSettings, expanded: true, desiredExpandedWidth: 440)
    expect(collapsedRight.maxX == secondary.visibleFrameQuartz.maxX && expandedRight.maxX == secondary.visibleFrameQuartz.maxX, "Right Dynamic Island anchored flush to right edge")
    expect(expandedRight.height == 440 && expandedRight.width > collapsedRight.width && DisplayGeometry.popDirection(for: expandedRight, on: secondary, shape: .dynamicIsland, islandPosition: .right) == .left && rightStage == extStage, "Right Dynamic Island expands vertically leftward and preserves full stage")

    // Perpendicular drawer expansion across all 4 edges
    var topPerp = islandSettings
    topPerp.islandPosition = .top
    topPerp.islandExpandAxis = .perpendicular
    let (expTopPerpNotch, _) = DisplayGeometry.dynamicIslandFramesQuartz(on: notchedScreen, settings: topPerp, expanded: true, desiredExpandedWidth: 360)
    expect(expTopPerpNotch.minY == notchedScreen.frameQuartz.minY && expTopPerpNotch.width >= 185 + 16 && expTopPerpNotch.height > expTopPerpNotch.width, "Top perpendicular Dynamic Island opens downward as a vertical column clearing the hardware notch")

    var bottomPerp = islandSettings
    bottomPerp.islandPosition = .bottom
    bottomPerp.islandExpandAxis = .perpendicular
    let (expBottomPerp, bottomPerpStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: bottomPerp, expanded: true, desiredExpandedWidth: 360)
    expect(expBottomPerp.maxY == secondary.visibleFrameQuartz.maxY && expBottomPerp.height == 360 && expBottomPerp.width < expBottomPerp.height && bottomPerpStage == extStage, "Bottom perpendicular Dynamic Island opens upward as a vertical column and preserves full stage")

    var leftPerp = islandSettings
    leftPerp.islandPosition = .left
    leftPerp.islandExpandAxis = .perpendicular
    let (expLeftPerp, leftPerpStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: leftPerp, expanded: true, desiredExpandedWidth: 380)
    expect(expLeftPerp.minX == secondary.visibleFrameQuartz.minX && expLeftPerp.width == 380 && expLeftPerp.width > expLeftPerp.height && leftPerpStage == extStage, "Left perpendicular Dynamic Island slides out horizontally and preserves full stage")

    var rightPerp = islandSettings
    rightPerp.islandPosition = .right
    rightPerp.islandExpandAxis = .perpendicular
    let (expRightPerp, rightPerpStage) = DisplayGeometry.dynamicIslandFramesQuartz(on: secondary, settings: rightPerp, expanded: true, desiredExpandedWidth: 380)
    expect(expRightPerp.maxX == secondary.visibleFrameQuartz.maxX && expRightPerp.width == 380 && expRightPerp.width > expRightPerp.height && rightPerpStage == extStage, "Right perpendicular Dynamic Island slides out horizontally and preserves full stage")

    expect(!islandSettings.isExpandedIslandVertical && !leftPerp.isExpandedIslandVertical && topPerp.isExpandedIslandVertical && leftSettings.isExpandedIslandVertical, "isExpandedIslandVertical resolves alongEdge vs perpendicular accurately")

    // Loop RadialOnly Mode: 100% full-screen reading area
    var radialOnlySettings = settings
    radialOnlySettings.dockShape = .radialOnly
    let (_, radialStage) = DisplayGeometry.dockAndStageFramesQuartz(
        on: secondary,
        customDockOriginQuartz: nil,
        settings: radialOnlySettings,
        desiredDockHeight: 300
    )
    expect(radialStage.width == secondary.visibleFrameQuartz.width - 16 && radialStage.height == secondary.visibleFrameQuartz.height - 16, "Radial-Only mode keeps 100% full-screen stage")

    // Parabolic magnification wave math
    let peak = StageSettings.magnificationFactor(distance: 0, iconSize: 44, maxScale: 1.45)
    let mid = StageSettings.magnificationFactor(distance: 45, iconSize: 44, maxScale: 1.45)
    let far = StageSettings.magnificationFactor(distance: 200, iconSize: 44, maxScale: 1.45)
    expect(abs(peak - 1.45) < 0.0001 && mid > 1.0 && mid < peak && far == 1.0, "Parabolic magnification wave peaks smoothly and decays monotonically to 1.0")
}

// 3. 50/50 split frames inside locked stage
do {
    let stage = CGRect(x: 100, y: 50, width: 1208, height: 800)
    let (left, right) = DisplayGeometry.splitFrames(forStage: stage, splitGap: 8)
    expect(left == CGRect(x: 100, y: 50, width: 600, height: 800), "Split left frame exact")
    expect(right == CGRect(x: 708, y: 50, width: 600, height: 800), "Split right frame exact")
    expect(right.minX - left.maxX == 8 && right.maxX == stage.maxX, "Split gap & right edge exact")
}

// 5. Persistence & legacy settings migration
do {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("aistage-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let store = PersistenceStore(directoryURL: tmpDir)
    var settings = StageSettings()
    settings.dockShape = .radialOnly
    settings.horizontalDockHeight = 62
    settings.circularDockDiameter = 210
    settings.hideInactiveStagedApps = true
    settings.launchAtLogin = true
    settings.hideMenuBarIcon = true
    settings.animationSpeed = .relaxed
    settings.includePadding = false
    settings.showRadialPreview = false
    settings.radialHapticsEnabled = false
    settings.useScreenWithCursor = false
    settings.moveCursorWithWindow = true
    settings.multiScreenAppPolicy = .keepOriginalScreen
    settings.radialParticleStyle = .vortexFireworks
    settings.windowPopAnimationStyle = .off
    settings.smoothWindowTransitions = false
    settings.splitRingHotkeyEnabled = false
    settings.splitRingShortcut = CustomKeyCombo(keyCode: 13, modifiers: CustomKeyCombo.modCommand)
    settings.splitMouseTrigger = .optionRight
    settings.splitCustomMouseButton = 4
    settings.splitCustomMouseModifiers = CustomKeyCombo.modControl
    settings.ringResizeModifier = .option
    settings.customRingColorHex = "#FF4488"
    settings.ringColorDepth = 0.60
    settings.customToggleShortcut = CustomKeyCombo(keyCode: 40, modifiers: CustomKeyCombo.modCommand | CustomKeyCombo.modShift)
    settings.customMoveScreenShortcut = CustomKeyCombo(keyCode: 96, modifiers: 0)
    settings.radialKeyboardMode = .keyCombo
    settings.radialKeyboardShortcut = CustomKeyCombo(keyCode: 12, modifiers: CustomKeyCombo.modOption)
    settings.radialModifierKey = .fnKey
    settings.radialTrigger = .customMouse
    settings.radialCustomMouseButton = 4
    settings.radialCustomMouseModifiers = CustomKeyCombo.modOption
    settings.dynamicIslandTheme = .appleGlass
    settings.islandPosition = .left
    settings.islandExpandAxis = .perpendicular
    settings.glassStyle = .frosted
    settings.glassOpacity = 0.42
    settings.glassSpecularIntensity = 0.85
    settings.hasCompletedOnboarding = true
    settings.radialIconSize = 58
    settings.customDockHeight = 520
    settings.numberSwitchModifier = .command
    settings.radialStyle = .squircle
    settings.radialTheme = .appleGlass
    settings.radialThickness = 22
    settings.radialCornerRatio = 0.52
    settings.previewBorderThickness = 6
    settings.previewCornerRadius = 18

    let config = PersistedStageConfig(
        apps: [
            StageAppItem(bundleIdentifier: "com.openai.codex", displayName: "ChatGPT", appPath: "/Applications/ChatGPT.app"),
            StageAppItem(bundleIdentifier: "com.anthropic.claudefordesktop", displayName: "Claude", appPath: "/Applications/Claude.app")
        ],
        pinnedScreenID: "main",
        customDockOriginQuartz: CodablePoint(CGPoint(x: -1350, y: 110)),
        lastActiveBundleID: "com.openai.codex",
        settings: settings
    )
    store.save(config)
    expect(store.load() == config, "PersistenceStore JSON round-trip matches")

    let legacyJSON = """
    {"dockShape": "vertical", "dockWidth": 64, "dockGap": 8, "splitGap": 8, "toggleHotkey": "option_space", "numberSwitchModifier": "option", "smartZOrder": true, "matchWindowHeight": false}
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(StageSettings.self, from: legacyJSON)
    expect(decoded.outerMargin == 8 && decoded.hideInactiveStagedApps == false, "Legacy config keeps default outerMargin & hideInactiveStagedApps")
    expect(decoded.dockShape == .dynamicIsland, "Legacy vertical/horizontal/circular dockShape migrates cleanly to Dynamic Island")
    expect(decoded.dynamicIslandTheme == .obsidian && DynamicIslandTheme.allCases == [.obsidian, .appleGlass], "DynamicIslandTheme defaults to obsidian and offers appleGlass")
    expect(decoded.islandPosition == .top && DockEdgePosition.allCases == [.top, .bottom, .left, .right], "islandPosition defaults to top and supports all 4 edges")
    expect(decoded.islandExpandAxis == .alongEdge && IslandExpandAxis.allCases == [.alongEdge, .perpendicular], "islandExpandAxis defaults to alongEdge and supports alongEdge/perpendicular")
    expect(decoded.glassStyle == .clear && AppleGlassStyle.allCases == [.clear, .regular, .frosted], "AppleGlassStyle defaults to clear and offers clear/regular/frosted")
    expect(abs(decoded.glassOpacity - 0.18) < 0.001 && abs(decoded.glassSpecularIntensity - 0.65) < 0.001 && decoded.hasCompletedOnboarding == false, "Legacy config gets native glass defaults and hasCompletedOnboarding=false")
    expect(decoded.radialIconSize == 46, "Legacy config gets default radialIconSize (46pt)")

    let legacyLayoutData = "\"card_grid\"".data(using: .utf8)!
    let migratedLayout = try JSONDecoder().decode(StageLayoutMode.self, from: legacyLayoutData)
    expect(StageLayoutMode.allCases == [.monocleStack, .split2] && migratedLayout == .monocleStack, "StageLayoutMode keeps only monocleStack & split2 and migrates legacy card_grid")

    let freshDefaults = StageSettings()
    expect(freshDefaults.dockShape == .dynamicIsland, "Default dockShape is Dynamic Island")
    expect(freshDefaults.followActiveScreen == false, "Default followActiveScreen is false (explicit drag to move Dock across screens)")
    expect(freshDefaults.radialTrigger == .middleClickDrag, "Default radialTrigger is middleClickDrag")
    expect(freshDefaults.radialRingDiameter == 300 && freshDefaults.radialIconSize == 46 && freshDefaults.radialThickness == 32 && freshDefaults.radialParticleEffects == true, "Upgraded 300pt/46pt/32pt radial ring, logo size & particle defaults")
    expect(freshDefaults.radialStyle == .classicTahoe && LoopRadialStyle.allCases.count == 5, "5 curated Loop radial styles available with classicTahoe default")
    expect(freshDefaults.radialTheme == .ocean && LoopAccentTheme.allCases.count == 8 && LoopAccentTheme.allCases.contains(.appleGlass) && LoopAccentTheme.allCases.contains(.custom), "8 ring color themes available including appleGlass and custom with ocean default")
    expect(LoopRadialStyle.squircle.defaultCornerRatio < 0.7 && LoopRadialStyle.classicTahoe.defaultCornerRatio == 1.0, "Squircle vs circle corner curvature presets")
    expect(freshDefaults.numberSwitchModifier == .disabled, "Default numberSwitchModifier is disabled (no accidental global Cmd+1..9 hijacking)")
    expect(freshDefaults.scrollWheelSwitchesApp == false, "Default scrollWheelSwitchesApp is false")
    expect(freshDefaults.autoScaleIndicator == true && freshDefaults.magnificationScale > 1.0, "Default adaptive indicator & magnification enabled")

    let legacyFollowDecoded = try JSONDecoder().decode(StageSettings.self, from: legacyJSON)
    expect(legacyFollowDecoded.followActiveScreen == false && legacyFollowDecoded.radialTrigger == .middleClickDrag, "Legacy config defaults followActiveScreen=false & radialTrigger=middleClickDrag")
    expect(legacyFollowDecoded.radialStyle == .classicTahoe && legacyFollowDecoded.radialTheme == .ocean && legacyFollowDecoded.previewBorderThickness == 5.5, "Legacy config gets Loop style & preview defaults")

    var smallIcons = StageSettings()
    smallIcons.iconSize = 28
    var largeIcons = StageSettings()
    largeIcons.iconSize = 64
    expect(smallIcons.effectiveIndicatorSize < largeIcons.effectiveIndicatorSize, "Adaptive indicator dot scales proportionally with iconSize")
    expect(smallIcons.effectiveDockThickness < largeIcons.effectiveDockThickness, "Dock thickness scales proportionally with iconSize")

    let minimalJSON = """
    {"dockWidth": 66}
    """.data(using: .utf8)!
    let minimalDecoded = try JSONDecoder().decode(StageSettings.self, from: minimalJSON)
    expect(minimalDecoded.numberSwitchModifier == .disabled && minimalDecoded.scrollWheelSwitchesApp == false, "Minimal JSON gets safe disabled numberSwitchModifier & scrollWheelSwitchesApp defaults")

    // Loop-inspired Behavior settings: defaults, speed ordering, includePadding & legacy decode
    expect(AnimationSpeedPreset.allCases == [.instant, .fast, .smooth, .relaxed], "AnimationSpeedPreset exposes 4 stops in order")
    expect(AnimationSpeedPreset.instant.isInstant && AnimationSpeedPreset.from(sliderIndex: 2) == .smooth, "AnimationSpeedPreset sliderIndex & isInstant map cleanly")
    expect(
        AnimationSpeedPreset.instant.dockFrameDuration < AnimationSpeedPreset.fast.dockFrameDuration
            && AnimationSpeedPreset.fast.dockFrameDuration < AnimationSpeedPreset.smooth.dockFrameDuration
            && AnimationSpeedPreset.smooth.dockFrameDuration < AnimationSpeedPreset.relaxed.dockFrameDuration
            && AnimationSpeedPreset.fast.ringSpringResponse < AnimationSpeedPreset.smooth.ringSpringResponse
            && AnimationSpeedPreset.smooth.ringSpringResponse < AnimationSpeedPreset.relaxed.ringSpringResponse
            && AnimationSpeedPreset.fast.previewFrameDuration < AnimationSpeedPreset.relaxed.previewFrameDuration
            && AnimationSpeedPreset.fast.fadeOutDuration < AnimationSpeedPreset.relaxed.fadeOutDuration,
        "Animation speed timings scale monotonically from instant to relaxed"
    )
    expect(
        !freshDefaults.launchAtLogin
            && !freshDefaults.hideMenuBarIcon
            && freshDefaults.animationSpeed == .fast
            && freshDefaults.includePadding
            && freshDefaults.showRadialPreview
            && freshDefaults.radialHapticsEnabled
            && freshDefaults.useScreenWithCursor
            && !freshDefaults.moveCursorWithWindow,
        "Loop-inspired behavior defaults match clean out-of-the-box UX"
    )
    expect(
        !minimalDecoded.launchAtLogin
            && !minimalDecoded.hideMenuBarIcon
            && minimalDecoded.animationSpeed == .fast
            && minimalDecoded.includePadding
            && minimalDecoded.showRadialPreview
            && minimalDecoded.radialHapticsEnabled
            && minimalDecoded.useScreenWithCursor
            && !minimalDecoded.moveCursorWithWindow,
        "Minimal JSON cleanly migrates all Loop behavior defaults"
    )

    var noPadSettings = StageSettings()
    noPadSettings.outerMargin = 14
    noPadSettings.includePadding = true
    expect(noPadSettings.effectiveOuterMargin == 14, "effectiveOuterMargin honors outerMargin when includePadding is true")
    noPadSettings.includePadding = false
    expect(noPadSettings.effectiveOuterMargin == 0, "effectiveOuterMargin zeroes margin when includePadding is false")
    let testScr = DisplayGeometry.ScreenInfo(
        id: "pad-test",
        frameAppKit: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1440, height: 875),
        primaryHeight: 900
    )
    let (_, noPadStage) = DisplayGeometry.dynamicIslandFramesQuartz(
        on: testScr,
        settings: noPadSettings,
        expanded: false,
        desiredExpandedWidth: 380
    )
    expect(noPadStage == testScr.visibleFrameQuartz.integral, "includePadding=false expands stage edge-to-edge across visibleFrame")

    // Custom keyboard shortcuts & Loop keyboard/mouse trigger settings
    let cmdShiftK = CustomKeyCombo(keyCode: 40, modifiers: CustomKeyCombo.modCommand | CustomKeyCombo.modShift)
    let f5Key = CustomKeyCombo(keyCode: 96, modifiers: 0)
    let bareLetter = CustomKeyCombo(keyCode: 40, modifiers: 0)
    expect(
        CustomKeyCombo.optionSpace.displayString == "⌥ Space"
            && CustomKeyCombo.controlOptionRight.displayString == "⌃⌥→"
            && cmdShiftK.displayString == "⇧⌘K"
            && f5Key.displayString == "F5",
        "CustomKeyCombo formats modifier glyphs and function keys cleanly"
    )
    expect(
        CustomKeyCombo.isFunctionKey(96)
            && f5Key.isValidShortcut
            && cmdShiftK.isValidShortcut
            && !bareLetter.isValidShortcut,
        "CustomKeyCombo accepts modified keys and function keys while rejecting bare letters"
    )
    expect(
        freshDefaults.effectiveToggleShortcut == .optionSpace
            && freshDefaults.effectiveMoveScreenShortcut == .controlOptionRight
            && freshDefaults.radialKeyboardMode == .modifierHold
            && freshDefaults.activeRadialKeyboardShortcut == nil
            && freshDefaults.radialKeyboardShortcut == .optionQ
            && freshDefaults.radialModifierKey == .leftOption,
        "Default effective shortcuts and trackpad-ready leftOption modifierHold defaults resolve cleanly"
    )
    var customTrig = StageSettings()
    customTrig.customToggleShortcut = cmdShiftK
    customTrig.radialKeyboardMode = .keyCombo
    customTrig.radialTrigger = .customMouse
    customTrig.radialCustomMouseButton = 3
    customTrig.radialCustomMouseModifiers = CustomKeyCombo.modOption
    L10n.setLanguage(.zhHans)
    let zhMouseDisplay = customTrig.customMouseTriggerDisplayString
    L10n.setLanguage(.en)
    let enMouseDisplay = customTrig.customMouseTriggerDisplayString
    L10n.setLanguage(.zhHans)
    expect(
        customTrig.effectiveToggleShortcut == cmdShiftK
            && customTrig.activeRadialKeyboardShortcut == .optionQ
            && zhMouseDisplay == "⌥ + 鼠标侧键 4"
            && enMouseDisplay == "⌥ + Mouse Button 4",
        "Customized shortcut, radial key combo & mouse button display string resolve accurately in zh/en"
    )
    expect(
        minimalDecoded.customToggleShortcut == nil
            && minimalDecoded.customMoveScreenShortcut == nil
            && minimalDecoded.radialKeyboardMode == .modifierHold
            && minimalDecoded.radialKeyboardShortcut == .optionQ
            && minimalDecoded.radialModifierKey == .leftOption
            && minimalDecoded.radialCustomMouseButton == 3,
        "Legacy JSON cleanly migrates custom shortcut & trackpad trigger defaults"
    )

    // Multi-screen / switch-window behavior policy & 5 Loop particle styles
    expect(
        MultiScreenAppPolicy.allCases == [.keepOriginalScreen, .smartKeepOtherScreen, .followDockScreen]
            && freshDefaults.multiScreenAppPolicy == .keepOriginalScreen
            && minimalDecoded.multiScreenAppPolicy == .keepOriginalScreen,
        "MultiScreenAppPolicy defaults to keepOriginalScreen (non-resizing focus) and migrates minimal configs"
    )
    expect(
        DisplayGeometry.shouldPreserveExistingWindowFrame(
            policy: .smartKeepOtherScreen,
            windowScreenID: "secondary",
            dockScreenID: "primary",
            hasExplicitOverrideFrame: false,
            forceAlignToDockScreen: false
        ) == true
            && DisplayGeometry.shouldPreserveExistingWindowFrame(
                policy: .smartKeepOtherScreen,
                windowScreenID: "primary",
                dockScreenID: "primary",
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == false
            && DisplayGeometry.shouldPreserveExistingWindowFrame(
                policy: .smartKeepOtherScreen,
                windowScreenID: "secondary",
                dockScreenID: "primary",
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: true
            ) == false
            && DisplayGeometry.shouldPreserveExistingWindowFrame(
                policy: .smartKeepOtherScreen,
                windowScreenID: "secondary",
                dockScreenID: "primary",
                hasExplicitOverrideFrame: true,
                forceAlignToDockScreen: false
            ) == false
            && DisplayGeometry.shouldPreserveExistingWindowFrame(
                policy: .followDockScreen,
                windowScreenID: "secondary",
                dockScreenID: "primary",
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == false
            && DisplayGeometry.shouldPreserveExistingWindowFrame(
                policy: .keepOriginalScreen,
                windowScreenID: "primary",
                dockScreenID: "primary",
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == true,
        "shouldPreserveExistingWindowFrame enforces all 3 multi-screen policies and override flags"
    )
    expect(
        LoopParticleStyle.allCases.count == 9
            && LoopParticleStyle.vortexMagic.isVortexStyle
            && LoopParticleStyle.vortexFireworks.isVortexStyle
            && LoopParticleStyle.vortexSpark.isVortexStyle
            && !LoopParticleStyle.sparkBurst.isVortexStyle
            && freshDefaults.effectiveParticleStyle == .sparkBurst
            && minimalDecoded.effectiveParticleStyle == .sparkBurst,
        "LoopParticleStyle offers off + 5 Canvas + 3 Vortex presets with sparkBurst default"
    )
    let legacyGeniePopJSON = """
    {"windowPopAnimationStyle": "genie"}
    """.data(using: .utf8)!
    let legacyGenieDecoded = try JSONDecoder().decode(StageSettings.self, from: legacyGeniePopJSON)
    expect(
        WindowPopAnimationStyle.allCases == [.off, .genie]
            && WindowPopAnimationStyle.off.duration == 0.0
            && WindowPopAnimationStyle.genie.duration > 0.3
            && WindowPopAnimationStyle.genie.effectiveDuration(speed: .instant) == 0.0
            && WindowPopAnimationStyle.genie.effectiveDuration(speed: .relaxed) > WindowPopAnimationStyle.genie.effectiveDuration(speed: .fast)
            && freshDefaults.windowPopAnimationStyle == .off
            && minimalDecoded.windowPopAnimationStyle == .off
            && legacyGenieDecoded.windowPopAnimationStyle == .off
            && freshDefaults.smoothWindowTransitions == true
            && minimalDecoded.smoothWindowTransitions == true
            && freshDefaults.splitRingHotkeyEnabled == true
            && minimalDecoded.splitRingHotkeyEnabled == true
            && freshDefaults.effectiveSplitRingShortcut == .optionS
            && minimalDecoded.effectiveSplitRingShortcut == .optionS
            && freshDefaults.splitMouseTrigger == .optionMiddle
            && minimalDecoded.splitMouseTrigger == .optionMiddle
            && freshDefaults.ringResizeModifier == .command
            && minimalDecoded.ringResizeModifier == .command
            && abs(freshDefaults.ringColorDepth - 0.85) < 0.001
            && minimalDecoded.customRingColorHex == "#0071EC",
        "Genie window pop is disabled cleanly across fresh and legacy configs while split triggers preserve"
    )

    // DisplayGeometry.scaledFrameQuartz (Ring + Modifier + Scroll resize)
    let splitBounds = CGRect(x: 0, y: 0, width: 1512, height: 950)
    let halfL = CGRect(x: 0, y: 0, width: 752, height: 950)
    let halfR = CGRect(x: 760, y: 0, width: 752, height: 950)
    let scaledL = DisplayGeometry.scaledFrameQuartz(halfL, scale: 0.70, within: splitBounds, anchor: .leftHalf)
    let scaledR = DisplayGeometry.scaledFrameQuartz(halfR, scale: 0.70, within: splitBounds, anchor: .rightHalf)
    let scaledC = DisplayGeometry.scaledFrameQuartz(splitBounds, scale: 0.30, within: splitBounds, anchor: .center)
    expect(
        scaledL.minX == 0 && scaledL.width < halfL.width
            && scaledR.maxX == halfR.maxX && scaledR.minX > halfR.minX
            && scaledC.width >= round(splitBounds.width * 0.45) - 1,
        "DisplayGeometry.scaledFrameQuartz anchors left/right/center cleanly and clamps minimum 45% scale"
    )

    // Loop 11-layout frames (halves + 4 quarters + keep/max/center) & 8-way LoopSplitTarget compass
    let layoutBase = CGRect(x: 0, y: 30, width: 1512, height: 900)
    let layoutScreen = DisplayGeometry.ScreenInfo(
        id: "loop-test",
        frameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 950),
        primaryHeight: 982
    )
    let lh = DisplayGeometry.radialLayoutFrameQuartz(.leftHalf, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let rh = DisplayGeometry.radialLayoutFrameQuartz(.rightHalf, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let th = DisplayGeometry.radialLayoutFrameQuartz(.topHalf, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let bh = DisplayGeometry.radialLayoutFrameQuartz(.bottomHalf, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let tlq = DisplayGeometry.radialLayoutFrameQuartz(.topLeftQuarter, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let trq = DisplayGeometry.radialLayoutFrameQuartz(.topRightQuarter, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let blq = DisplayGeometry.radialLayoutFrameQuartz(.bottomLeftQuarter, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let brq = DisplayGeometry.radialLayoutFrameQuartz(.bottomRightQuarter, base: layoutBase, screen: layoutScreen, splitGap: 8)
    let legacyThirdDecoded = (try? JSONDecoder().decode(RadialLayoutTarget.self, from: "\"left_third\"".data(using: .utf8)!)) ?? .maximize
    expect(
        RadialLayoutTarget.allCases.count == 11
            && RadialLayoutTarget.leftHalf.isSplitLayout
            && RadialLayoutTarget.topRightQuarter.isSplitLayout
            && !RadialLayoutTarget.stage.isSplitLayout
            && !RadialLayoutTarget.maximize.isSplitLayout
            && RadialLayoutTarget.topHalf.cycledVariant(step: 1) == .maximize
            && RadialLayoutTarget.bottomHalf.cycledVariant(step: 1) == .center
            && RadialLayoutTarget.leftHalf.cycledVariant(step: 1) == .leftHalf
            && legacyThirdDecoded == .stage
            && lh.minX == 0 && abs((rh.minX - lh.maxX) - 8) < 1 && rh.maxX == 1512
            && abs((bh.minY - th.maxY) - 8) < 1
            && tlq.maxY == th.maxY && trq.maxX == rh.maxX && blq.minY == bh.minY && brq.minY == bh.minY,
        "Halves, 4 quarters, keep/maximize/center & cycledVariant compute cleanly without thirds"
    )

    let ringAnchor = CGPoint(x: 750, y: 500)
    let cRes = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 755, y: 502))
    let inLeft = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 680, y: 500))
    let outLeft = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 560, y: 500))
    let inRight = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 820, y: 500))
    let outRight = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 940, y: 500))
    let inTopRight = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 810, y: 560))
    let outBottom = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 750, y: 310))
    let outTop = DisplayGeometry.loopSplitTarget(from: ringAnchor, to: CGPoint(x: 750, y: 700))
    expect(
        cRes.target == .maximize && cRes.sectorIndex == nil
            && inLeft.target == .leftHalf && !inLeft.isOuterRing
            && outLeft.target == .leftHalf && !outLeft.isOuterRing
            && inRight.target == .rightHalf && !inRight.isOuterRing
            && outRight.target == .rightHalf && !outRight.isOuterRing
            && inTopRight.target == .topRightQuarter
            && outBottom.target == .bottomHalf && !outBottom.isOuterRing
            && outTop.target == .topHalf && !outTop.isOuterRing,
        "Loop 8-way compass resolves center, 4 halves, and 4 quarters cleanly at all distances"
    )

    // WindowFrameAnimator cubic ease-out interpolation
    let startRect = CGRect(x: 100, y: 200, width: 400, height: 300)
    let endRect = CGRect(x: 500, y: 200, width: 800, height: 700)
    let midRect = WindowFrameAnimator.interpolatedFrame(from: startRect, to: endRect, progress: 0.5)
    expect(
        WindowFrameAnimator.interpolatedFrame(from: startRect, to: endRect, progress: 0.0) == startRect
            && abs(midRect.origin.x - 450.0) < 0.01
            && abs(midRect.size.width - 750.0) < 0.01
            && WindowFrameAnimator.interpolatedFrame(from: startRect, to: endRect, progress: 1.0) == endRect,
        "WindowFrameAnimator.interpolatedFrame applies cubic ease-out (0.875 at t=0.5)"
    )
    let legacyNoParticlesJSON = """
    {"radialParticleEffects": false}
    """.data(using: .utf8)!
    let legacyNoParticles = try JSONDecoder().decode(StageSettings.self, from: legacyNoParticlesJSON)
    expect(
        legacyNoParticles.effectiveParticleStyle == .off,
        "Legacy radialParticleEffects=false migrates cleanly to LoopParticleStyle.off"
    )
    let legacyScaleAppear = try JSONDecoder().decode(
        AppearAnimationStyle.self,
        from: "\"scale\"".data(using: .utf8)!
    )
    let explicitFlashAppear = try JSONDecoder().decode(
        AppearAnimationStyle.self,
        from: "\"flash\"".data(using: .utf8)!
    )
    expect(
        ScrollWheelBehavior.browse.switchesApp(optionHeld: false) == false
            && ScrollWheelBehavior.browse.switchesApp(optionHeld: true) == true
            && ScrollWheelBehavior.switchApps.switchesApp(optionHeld: false) == true
            && ScrollWheelBehavior.switchApps.switchesApp(optionHeld: true) == false
            && ScrollWheelBehavior.browseOnly.switchesApp(optionHeld: true) == false
            && AppearAnimationStyle.allCases == [.roll, .flash]
            && legacyScaleAppear == .roll
            && explicitFlashAppear == .flash,
        "ScrollWheelBehavior and ring-only AppearAnimationStyle [.roll, .flash] resolve accurately"
    )

    // Dock badge normalization & multi-key lookup (bundleID, appPath, display/localized title)
    let badgeSnapshot = AXWindowController.DockBadgeSnapshot(
        byBundleID: ["com.tencent.xinwechat": "3"],
        byAppPath: ["/Applications/QQ.app": "12"],
        byTitleLower: ["feishu": "5"]
    )
    expect(
        AXWindowController.normalizedBadgeLabel(from: " 7 ") == "7"
            && AXWindowController.normalizedBadgeLabel(from: NSNumber(value: 18)) == "18"
            && AXWindowController.normalizedBadgeLabel(from: "•") == "•"
            && AXWindowController.normalizedBadgeLabel(from: "0") == nil
            && AXWindowController.normalizedBadgeLabel(from: NSNumber(value: 0)) == nil
            && AXWindowController.normalizedBadgeLabel(from: "  ") == nil
            && badgeSnapshot.badge(
                forBundleID: "com.tencent.xinWeChat",
                appURL: URL(fileURLWithPath: "/Applications/OtherLocation/WeChat.app"),
                displayName: "微信"
            ) == "3"
            && badgeSnapshot.badge(
                forBundleID: "com.tencent.qq",
                appURL: URL(fileURLWithPath: "/Applications/QQ.app"),
                displayName: "QQ"
            ) == "12"
            && badgeSnapshot.badge(
                forBundleID: "com.bytedance.feishu",
                appURL: URL(fileURLWithPath: "/Applications/Lark.app"),
                displayName: "Lark",
                localizedName: "Feishu"
            ) == "5",
        "DockBadgeSnapshot normalizes badge strings/numbers and matches bundleID, path, and localized names"
    )

    // Per-display fail-safe hiding under hideInactiveStagedApps
    let mainScreenInfo = DisplayGeometry.ScreenInfo(
        id: "main",
        frameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 950),
        primaryHeight: 982
    )
    let extScreenInfo = DisplayGeometry.ScreenInfo(
        id: "ext",
        frameAppKit: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        visibleFrameAppKit: CGRect(x: -1920, y: 0, width: 1920, height: 1055),
        primaryHeight: 982
    )
    let mainWinRect = CGRect(x: 100, y: 80, width: 1200, height: 800)
    let extWinRect = CGRect(x: -1600, y: 40, width: 1200, height: 800)
    expect(
        DisplayGeometry.shouldHideAppOnScreenSwitch(
            appWindowFramesQuartz: [],
            targetScreenID: "main",
            screens: [mainScreenInfo]
        ) == true
            && DisplayGeometry.shouldHideAppOnScreenSwitch(
                appWindowFramesQuartz: [mainWinRect],
                targetScreenID: "main",
                screens: [mainScreenInfo, extScreenInfo]
            ) == true
            && DisplayGeometry.shouldHideAppOnScreenSwitch(
                appWindowFramesQuartz: [extWinRect],
                targetScreenID: "main",
                screens: [mainScreenInfo, extScreenInfo]
            ) == false
            && DisplayGeometry.shouldHideAppOnScreenSwitch(
                appWindowFramesQuartz: [mainWinRect, extWinRect],
                targetScreenID: "main",
                screens: [mainScreenInfo, extScreenInfo]
            ) == false
            && DisplayGeometry.shouldHideAppOnScreenSwitch(
                appWindowFramesQuartz: [],
                targetScreenID: "main",
                screens: [mainScreenInfo, extScreenInfo]
            ) == false,
        "shouldHideAppOnScreenSwitch protects secondary-screen & multi-window apps on dual displays"
    )
}

// 5b. Radial app ordering & unlaunched filtering
do {
    let minData = "{}".data(using: .utf8)!
    let decodedSettings = try JSONDecoder().decode(StageSettings.self, from: minData)
    let decodedConfig = try JSONDecoder().decode(PersistedStageConfig.self, from: minData)
    expect(
        decodedSettings.radialAppOrderMode == .addedOrder
            && decodedSettings.showInactiveAppsInRing == true
            && decodedConfig.appUsageCounts.isEmpty
            && decodedConfig.appLastUsedTimestamps.isEmpty,
        "RadialAppOrderMode and PersistedStageConfig usage maps decode with clean defaults"
    )

    let a = StageAppItem(bundleIdentifier: "com.test.a", displayName: "A", appPath: "/Applications/A.app")
    let b = StageAppItem(bundleIdentifier: "com.test.b", displayName: "B", appPath: "/Applications/B.app")
    let c = StageAppItem(bundleIdentifier: "com.test.c", displayName: "C", appPath: "/Applications/C.app")
    let items = [a, b, c]

    var cfg = PersistedStageConfig(
        apps: items,
        settings: StageSettings(),
        appUsageCounts: ["com.test.c": 9, "com.test.a": 3],
        appLastUsedTimestamps: ["com.test.c": 200, "com.test.a": 100, "com.test.b": 300]
    )
    cfg.settings.radialAppOrderMode = .frequentFirst
    cfg.settings.showInactiveAppsInRing = false
    let rtData = try JSONEncoder().encode(cfg)
    let rtCfg = try JSONDecoder().decode(PersistedStageConfig.self, from: rtData)
    expect(
        rtCfg.appUsageCounts["com.test.c"] == 9
            && rtCfg.appLastUsedTimestamps["com.test.b"] == 300
            && rtCfg.settings.radialAppOrderMode == .frequentFirst
            && rtCfg.settings.showInactiveAppsInRing == false,
        "PersistedStageConfig usage counts & radial ordering settings round-trip cleanly"
    )

    let addedRunningFirst = StageSettings.orderedRadialApps(
        apps: items,
        runningBundleIDs: ["com.test.b"],
        usageCounts: ["com.test.c": 10],
        lastUsedTimestamps: [:],
        orderMode: .addedOrder,
        sortRunningFirst: true,
        showInactiveApps: true
    )
    expect(
        addedRunningFirst.map(\.bundleIdentifier) == ["com.test.b", "com.test.a", "com.test.c"],
        "orderedRadialApps addedOrder keeps running first then added order"
    )

    let frequentOrder = StageSettings.orderedRadialApps(
        apps: items,
        runningBundleIDs: ["com.test.a"],
        usageCounts: ["com.test.c": 12, "com.test.a": 4, "com.test.b": 4],
        lastUsedTimestamps: ["com.test.a": 50, "com.test.b": 90],
        orderMode: .frequentFirst,
        sortRunningFirst: true,
        showInactiveApps: true
    )
    expect(
        frequentOrder.map(\.bundleIdentifier) == ["com.test.c", "com.test.b", "com.test.a"],
        "orderedRadialApps frequentFirst ranks highest usage first with recency tie-breaker"
    )

    let filteredRunning = StageSettings.orderedRadialApps(
        apps: items,
        runningBundleIDs: ["com.test.c"],
        usageCounts: [:],
        lastUsedTimestamps: [:],
        orderMode: .addedOrder,
        sortRunningFirst: true,
        showInactiveApps: false
    )
    let fallbackEmptyRunning = StageSettings.orderedRadialApps(
        apps: items,
        runningBundleIDs: [],
        usageCounts: [:],
        lastUsedTimestamps: [:],
        orderMode: .addedOrder,
        sortRunningFirst: true,
        showInactiveApps: false
    )
    expect(
        filteredRunning.map(\.bundleIdentifier) == ["com.test.c"]
            && fallbackEmptyRunning.map(\.bundleIdentifier) == ["com.test.a", "com.test.b", "com.test.c"],
        "orderedRadialApps hides unlaunched apps unless none are running (auto-fallback)"
    )
}

// 5c. Custom Dynamic Island width/height/padding settings & bounds clamping
do {
    let minData = "{}".data(using: .utf8)!
    let decoded = try JSONDecoder().decode(StageSettings.self, from: minData)
    expect(
        decoded.islandCustomWidth == 0
            && decoded.islandCustomHeight == 0
            && decoded.islandContentPadding == 18,
        "Dynamic Island custom width/height/padding decode with clean defaults"
    )

    let extScreen = DisplayGeometry.ScreenInfo(
        id: "ext",
        frameAppKit: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1920, height: 1055),
        primaryHeight: 1080
    )

    var s = StageSettings()
    s.islandPosition = .top
    let collapsedDefault = DisplayGeometry.dynamicIslandFramesQuartz(on: extScreen, settings: s, expanded: false, desiredExpandedWidth: 420).island
    s.islandCustomWidth = 760
    s.islandCustomHeight = 128
    let collapsedWithCustom = DisplayGeometry.dynamicIslandFramesQuartz(on: extScreen, settings: s, expanded: false, desiredExpandedWidth: 420).island
    let topCustom = DisplayGeometry.dynamicIslandFramesQuartz(on: extScreen, settings: s, expanded: true, desiredExpandedWidth: 420).island

    s.islandPosition = .left
    s.islandCustomWidth = 110
    s.islandCustomHeight = 640
    let leftCustom = DisplayGeometry.dynamicIslandFramesQuartz(on: extScreen, settings: s, expanded: true, desiredExpandedWidth: 420).island

    var tooSmall = StageSettings()
    tooSmall.islandPosition = .top
    tooSmall.iconSize = 52
    tooSmall.islandCustomHeight = 40
    let clampedTop = DisplayGeometry.dynamicIslandFramesQuartz(on: extScreen, settings: tooSmall, expanded: true, desiredExpandedWidth: 420).island
    let expectedMinTop = DisplayGeometry.minExpandedIslandDepth(
        settings: tooSmall,
        topBand: DisplayGeometry.islandHeaderInset,
        isVerticalTray: false
    )

    expect(
        collapsedDefault == collapsedWithCustom
            && topCustom.width == 760
            && topCustom.height == 128
            && leftCustom.width == 110
            && leftCustom.height == 640
            && clampedTop.height >= expectedMinTop,
        "DisplayGeometry applies custom expanded island width/height while clamping minimum safe depth"
    )
}

// 5d. Beta 2: AppLanguage localization, Dock magnification off/on, & collapsed-island number hotkeys
do {
    expect(
        AppLanguage.allCases == [.system, .zhHans, .en]
            && L10n.resolve(.system, preferredLanguages: ["zh-Hans-CN"]) == .zhHans
            && L10n.resolve(.system, preferredLanguages: ["en-US"]) == .en
            && L10n.resolve(.en, preferredLanguages: ["zh-Hans-CN"]) == .en
            && L10n.resolve(.zhHans, preferredLanguages: ["en-US"]) == .zhHans,
        "AppLanguage resolves explicit and system locales cleanly"
    )

    L10n.setLanguage(.en)
    let enDockLabel = DockShapeMode.dynamicIsland.label
    let enSplitLabel = RadialLayoutTarget.leftHalf.label
    L10n.setLanguage(.zhHans)
    let zhDockLabel = DockShapeMode.dynamicIsland.label
    let zhSplitLabel = RadialLayoutTarget.leftHalf.label
    expect(
        enDockLabel == "Dynamic Island"
            && enSplitLabel == "Left Half 1/2"
            && zhDockLabel == "灵动岛"
            && zhSplitLabel == "左半屏 1/2",
        "L10n dynamically switches enum display labels between English and Simplified Chinese"
    )

    // NumberSwitchModifier presets, custom modifier mask, and JSON round-trip
    var numSettings = StageSettings()
    expect(
        numSettings.effectiveNumberSwitchModifiers == nil
            && numSettings.effectiveNumberSwitchSymbolPrefix == nil,
        "Default number switch hotkey is safely disabled out of the box"
    )
    numSettings.numberSwitchModifier = .command
    expect(
        numSettings.effectiveNumberSwitchModifiers == CustomKeyCombo.modCommand
            && numSettings.effectiveNumberSwitchSymbolPrefix == "⌘",
        "Explicit command number switch hotkey resolves to ⌘"
    )
    numSettings.numberSwitchModifier = .controlOption
    expect(
        numSettings.effectiveNumberSwitchModifiers == (CustomKeyCombo.modControl | CustomKeyCombo.modOption)
            && numSettings.effectiveNumberSwitchSymbolPrefix == "⌃⌥",
        "Preset controlOption number switch resolves to ⌃⌥"
    )
    numSettings.numberSwitchModifier = .custom
    numSettings.customNumberSwitchModifiers = CustomKeyCombo.modControl | CustomKeyCombo.modShift
    expect(
        numSettings.effectiveNumberSwitchModifiers == (CustomKeyCombo.modControl | CustomKeyCombo.modShift)
            && numSettings.effectiveNumberSwitchSymbolPrefix == "⌃⇧",
        "Custom number switch modifier mask resolves cleanly"
    )
    numSettings.numberSwitchModifier = .disabled
    expect(
        numSettings.effectiveNumberSwitchModifiers == nil
            && numSettings.effectiveNumberSwitchSymbolPrefix == nil,
        "Disabled number switch modifier produces nil mask and prefix"
    )

    // Round-trip language, customNumberSwitchModifiers, and Dock parameters
    var roundTripSettings = StageSettings()
    roundTripSettings.language = .en
    roundTripSettings.numberSwitchModifier = .custom
    roundTripSettings.customNumberSwitchModifiers = CustomKeyCombo.modOption | CustomKeyCombo.modCommand
    roundTripSettings.magnificationScale = 1.0
    roundTripSettings.indicatorStyle = .hidden
    roundTripSettings.animateOpeningApps = false
    roundTripSettings.sortRunningAppsFirst = false
    roundTripSettings.islandPosition = .bottom
    roundTripSettings.scrollWheelBehavior = .switchApps
    let encodedSettings = try JSONEncoder().encode(roundTripSettings)
    let decodedSettings = try JSONDecoder().decode(StageSettings.self, from: encodedSettings)
    expect(
        decodedSettings.language == .en
            && decodedSettings.numberSwitchModifier == .custom
            && decodedSettings.customNumberSwitchModifiers == (CustomKeyCombo.modOption | CustomKeyCombo.modCommand)
            && decodedSettings.magnificationScale == 1.0
            && decodedSettings.indicatorStyle == .hidden
            && decodedSettings.animateOpeningApps == false
            && decodedSettings.sortRunningAppsFirst == false
            && decodedSettings.islandPosition == .bottom
            && decodedSettings.scrollWheelBehavior == .switchApps,
        "Beta 2 StageSettings (language, customNumberSwitchModifiers, Dock controls) round-trip cleanly"
    )

    // Collapsed Dynamic Island ordering matches slot 1..9 shortcut order (e.g. active is +1, 2nd icon is +2)
    let appAgy = StageAppItem(bundleIdentifier: "com.test.agy", displayName: "Antigravity", appPath: "/Applications/Antigravity.app")
    let appGpt = StageAppItem(bundleIdentifier: "com.test.gpt", displayName: "ChatGPT", appPath: "/Applications/ChatGPT.app")
    let appCode = StageAppItem(bundleIdentifier: "com.test.code", displayName: "VSCode", appPath: "/Applications/VSCode.app")
    let appClaude = StageAppItem(bundleIdentifier: "com.test.claude", displayName: "Claude", appPath: "/Applications/Claude.app")
    let stageOrder = [appGpt, appCode, appAgy, appClaude]

    let collapsed = StageSettings.orderedCollapsedIslandApps(
        apps: stageOrder,
        activeBundleID: "com.test.agy",
        runningBundleIDs: ["com.test.agy", "com.test.gpt", "com.test.code"],
        sortRunningFirst: true
    )
    expect(
        collapsed.active?.bundleIdentifier == "com.test.agy"
            && collapsed.runningOthers.map(\.bundleIdentifier) == ["com.test.gpt", "com.test.code"]
            && collapsed.allSlots.map(\.bundleIdentifier) == ["com.test.agy", "com.test.gpt", "com.test.code", "com.test.claude"],
        "Collapsed island order places active at +1, second collapsed icon (ChatGPT) at +2, remaining running apps next, and inactive apps last"
    )

    // Magnification Off (1.0) yields 1.0 wave factor and zero headroom
    let magOffFactor = StageSettings.magnificationFactor(distance: 0, iconSize: 44, maxScale: 1.0)
    let testScrMag = DisplayGeometry.ScreenInfo(
        id: "mag-test",
        frameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 950),
        primaryHeight: 982
    )
    var sMagOff = StageSettings()
    sMagOff.magnificationScale = 1.0
    var sMagOn = StageSettings()
    sMagOn.magnificationScale = 1.6
    let hMagOff = DisplayGeometry.dynamicIslandFramesQuartz(on: testScrMag, settings: sMagOff, expanded: true, desiredExpandedWidth: 420).island.height
    let hMagOn = DisplayGeometry.dynamicIslandFramesQuartz(on: testScrMag, settings: sMagOn, expanded: true, desiredExpandedWidth: 420).island.height
    var sMinSize = StageSettings()
    sMinSize.iconSize = 28
    sMinSize.magnificationScale = 1.0
    let minHorizDepth = DisplayGeometry.minExpandedIslandDepth(settings: sMinSize, topBand: DisplayGeometry.islandHeaderInset, isVerticalTray: false)
    let minVertDepth = DisplayGeometry.minExpandedIslandDepth(settings: sMinSize, topBand: 0, isVerticalTray: true)
    expect(
        magOffFactor == 1.0
            && hMagOn > hMagOff
            && DisplayGeometry.magnificationOverflow(settings: sMagOff) == 0
            && DisplayGeometry.magnificationOverflow(settings: sMagOn) > 0
            && minHorizDepth <= 48
            && minVertDepth <= 50,
        "Magnification Off keeps scale 1.0 and zero overflow while minimum iconSize=28 saturates tightly"
    )

    // Trackpad left-hand modifier keys & preserving explicit legacy user choices
    expect(
        RadialModifierKey.allCases.contains(.leftOption)
            && RadialModifierKey.allCases.contains(.leftControl),
        "RadialModifierKey exposes left-hand trackpad keys (leftOption, leftControl)"
    )
    let explicitUserJSON = """
    {"numberSwitchModifier": "command", "multiScreenAppPolicy": "smart_keep_other_screen", "radialKeyboardMode": "disabled", "radialModifierKey": "left_control"}
    """.data(using: .utf8)!
    let explicitUserDecoded = try JSONDecoder().decode(StageSettings.self, from: explicitUserJSON)
    expect(
        explicitUserDecoded.numberSwitchModifier == .command
            && explicitUserDecoded.multiScreenAppPolicy == .smartKeepOtherScreen
            && explicitUserDecoded.radialKeyboardMode == .disabled
            && explicitUserDecoded.radialModifierKey == .leftControl,
        "Explicit saved user choices for number hotkeys, window policy, and triggers decode faithfully"
    )

    // RingResizeModifier off option & matching behavior
    expect(
        RingResizeModifier.allCases.contains(.disabled)
            && !RingResizeModifier.disabled.matches([.command, .option, .control, .shift])
            && RingResizeModifier.command.matches(.command),
        "RingResizeModifier supports disabling resize modifier cleanly"
    )
    let resizeDisabledJSON = """
    {"ringResizeModifier": "disabled"}
    """.data(using: .utf8)!
    let resizeDisabledDecoded = try JSONDecoder().decode(StageSettings.self, from: resizeDisabledJSON)
    expect(
        resizeDisabledDecoded.ringResizeModifier == .disabled
            && !resizeDisabledDecoded.ringScrollResizeEnabled,
        "RingResizeModifier.disabled decodes and migrates ringScrollResizeEnabled to false cleanly"
    )

    // Plain radial ring switches must not pass an override frame (preserves cross-screen & focus-only apps)
    expect(
        !DisplayGeometry.shouldPassOverrideFrameOnAppCommit(
            layout: .stage,
            pinnedFillFrame: nil,
            customWindowScale: 1.0
        )
            && DisplayGeometry.shouldPassOverrideFrameOnAppCommit(
                layout: .stage,
                pinnedFillFrame: nil,
                customWindowScale: 0.8
            )
            && DisplayGeometry.shouldPassOverrideFrameOnAppCommit(
                layout: .leftHalf,
                pinnedFillFrame: nil,
                customWindowScale: 1.0
            )
            && DisplayGeometry.shouldPassOverrideFrameOnAppCommit(
                layout: .stage,
                pinnedFillFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
                customWindowScale: 1.0
            ),
        "shouldPassOverrideFrameOnAppCommit preserves plain switches while applying resizes and splits"
    )

    // Multi-display safe target screen resolution when hiding other apps
    expect(
        DisplayGeometry.effectiveHideTargetScreenID(
            explicitScreenID: "ext",
            targetAppLiveScreenID: "main",
            dockScreenID: "main",
            screenCount: 2
        ) == "ext"
            && DisplayGeometry.effectiveHideTargetScreenID(
                explicitScreenID: nil,
                targetAppLiveScreenID: "ext",
                dockScreenID: "main",
                screenCount: 2
            ) == "ext"
            && DisplayGeometry.effectiveHideTargetScreenID(
                explicitScreenID: nil,
                targetAppLiveScreenID: nil,
                dockScreenID: "main",
                screenCount: 2
            ) == nil
            && DisplayGeometry.effectiveHideTargetScreenID(
                explicitScreenID: nil,
                targetAppLiveScreenID: nil,
                dockScreenID: "main",
                screenCount: 1
            ) == "main",
        "effectiveHideTargetScreenID never guesses dock screen on multi-display when target screen is unknown"
    )

    // Liquid Glass clarity clamping & style derivation
    var glassTest = StageSettings()
    glassTest.glassOpacity = -0.35
    let clampedZero = glassTest.clampedGlassOpacity
    glassTest.glassOpacity = 1.4
    let clampedOne = glassTest.clampedGlassOpacity
    glassTest.glassOpacity = 0.0
    expect(
        abs(clampedZero - 0.0) < 0.001
            && abs(clampedOne - 1.0) < 0.001
            && abs(glassTest.clampedGlassOpacity - 0.0) < 0.001
            && StageSettings.derivedGlassStyle(forOpacity: 0.0) == .clear
            && StageSettings.derivedGlassStyle(forOpacity: 0.5) == .regular
            && StageSettings.derivedGlassStyle(forOpacity: 0.9) == .frosted,
        "clampedGlassOpacity clamps [0, 1] and derivedGlassStyle maps opacity cleanly"
    )

    // Symmetric top & bottom inner inset on non-notched expanded Dynamic Island
    var symDot = StageSettings()
    symDot.iconSize = 46
    symDot.indicatorStyle = .dot
    let insetDot = DisplayGeometry.horizontalIslandEdgeInset(for: symDot)
    let depthDot = DisplayGeometry.minExpandedIslandDepth(settings: symDot, topBand: DisplayGeometry.islandHeaderInset, isVerticalTray: false)
    var symHidden = symDot
    symHidden.indicatorStyle = .hidden
    let insetHidden = DisplayGeometry.horizontalIslandEdgeInset(for: symHidden)
    let depthHidden = DisplayGeometry.minExpandedIslandDepth(settings: symHidden, topBand: DisplayGeometry.islandHeaderInset, isVerticalTray: false)
    expect(
        depthDot == insetDot + (CGFloat(symDot.iconSize) + 4) + insetDot
            && depthHidden == insetHidden + (CGFloat(symHidden.iconSize) + 4) + insetHidden
            && insetDot == 9,
        "Horizontal Dynamic Island balances top and bottom insets symmetrically around icons"
    )

    // Progressive crystal-clear Liquid Glass opacity curve
    let g0 = StageSettings.glassLayerOpacities(forFrost: 0.0)
    let gLow = StageSettings.glassLayerOpacities(forFrost: 0.15)
    let gMid = StageSettings.glassLayerOpacities(forFrost: 0.55)
    let gFull = StageSettings.glassLayerOpacities(forFrost: 1.0)
    expect(
        g0.clearBlur == 0.0 && g0.regularBlur == 0.0 && g0.tintVeil == 0.0
            && gLow.clearBlur > 0.0 && gLow.clearBlur < 0.35 && gLow.regularBlur == 0.0
            && abs(gMid.clearBlur - 1.0) < 0.001
            && gFull.clearBlur == 1.0 && gFull.regularBlur == 1.0 && gFull.tintVeil == 1.0,
        "glassLayerOpacities delivers zero blur at maximum clarity and smooth ramp to full frost"
    )

    // Independent switch-window toggles: defaults, legacy migration, and 4-way WindowSwitchAction resolver
    let freshSwitchDefaults = StageSettings()
    let keepMigrated = try JSONDecoder().decode(
        StageSettings.self,
        from: #"{"multiScreenAppPolicy": "keep_original_screen"}"#.data(using: .utf8)!
    )
    let smartMigrated = try JSONDecoder().decode(
        StageSettings.self,
        from: #"{"multiScreenAppPolicy": "smart_keep_other_screen"}"#.data(using: .utf8)!
    )
    let followMigrated = try JSONDecoder().decode(
        StageSettings.self,
        from: #"{"multiScreenAppPolicy": "follow_dock_screen"}"#.data(using: .utf8)!
    )
    let explicitToggles = try JSONDecoder().decode(
        StageSettings.self,
        from: #"{"autoFitWindowOnSwitch": false, "pullCrossScreenAppsToIsland": true}"#.data(using: .utf8)!
    )
    expect(
        !freshSwitchDefaults.autoFitWindowOnSwitch
            && !freshSwitchDefaults.pullCrossScreenAppsToIsland
            && !keepMigrated.autoFitWindowOnSwitch && !keepMigrated.pullCrossScreenAppsToIsland
            && smartMigrated.autoFitWindowOnSwitch && !smartMigrated.pullCrossScreenAppsToIsland
            && followMigrated.autoFitWindowOnSwitch && followMigrated.pullCrossScreenAppsToIsland
            && !explicitToggles.autoFitWindowOnSwitch && explicitToggles.pullCrossScreenAppsToIsland,
        "Switch-window toggles default off, migrate legacy policies cleanly, and decode explicit values"
    )

    let switchMainScreen = DisplayGeometry.ScreenInfo(
        id: "main",
        frameAppKit: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrameAppKit: CGRect(x: 0, y: 38, width: 1512, height: 912),
        primaryHeight: 982,
        safeAreaTop: 32,
        notchWidth: 185
    )
    let otherWinRect = CGRect(x: -1600, y: 40, width: 700, height: 500)
    let sameWinRect = CGRect(x: 120, y: 80, width: 700, height: 500)
    let pullPreserveAction = DisplayGeometry.resolveWindowSwitchAction(
        autoFitWindowOnSwitch: false,
        pullCrossScreenAppsToIsland: true,
        existingFrameQuartz: otherWinRect,
        windowScreenID: "ext",
        dockScreen: switchMainScreen,
        hasExplicitOverrideFrame: false,
        forceAlignToDockScreen: false
    )
    var expectedPullPreserveWidth: CGFloat = 0
    if case .moveToScreenPreservingSize(let moved) = pullPreserveAction {
        expectedPullPreserveWidth = moved.width
    }
    expect(
        DisplayGeometry.resolveWindowSwitchAction(
            autoFitWindowOnSwitch: false,
            pullCrossScreenAppsToIsland: false,
            existingFrameQuartz: otherWinRect,
            windowScreenID: "ext",
            dockScreen: switchMainScreen,
            hasExplicitOverrideFrame: false,
            forceAlignToDockScreen: false
        ) == .preserveExisting
            && DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: true,
                pullCrossScreenAppsToIsland: false,
                existingFrameQuartz: otherWinRect,
                windowScreenID: "ext",
                dockScreen: switchMainScreen,
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == .preserveExisting
            && DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: true,
                pullCrossScreenAppsToIsland: false,
                existingFrameQuartz: sameWinRect,
                windowScreenID: "main",
                dockScreen: switchMainScreen,
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == .fitToStage
            && DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: true,
                pullCrossScreenAppsToIsland: true,
                existingFrameQuartz: otherWinRect,
                windowScreenID: "ext",
                dockScreen: switchMainScreen,
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: false
            ) == .fitToStage
            && expectedPullPreserveWidth == 700
            && DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: false,
                pullCrossScreenAppsToIsland: false,
                existingFrameQuartz: otherWinRect,
                windowScreenID: "ext",
                dockScreen: switchMainScreen,
                hasExplicitOverrideFrame: true,
                forceAlignToDockScreen: false
            ) == .fitToStage
            && DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: false,
                pullCrossScreenAppsToIsland: false,
                existingFrameQuartz: otherWinRect,
                windowScreenID: "ext",
                dockScreen: switchMainScreen,
                hasExplicitOverrideFrame: false,
                forceAlignToDockScreen: true
            ) == .fitToStage,
        "resolveWindowSwitchAction enforces all 4 combinations of autoFit and pullCrossScreen toggles"
    )

    // Adaptive 3-layer Liquid Glass edge lighting metrics
    let clearRim = StageSettings.glassRimMetrics(forFrost: 0.0, isDark: false)
    let frostedRim = StageSettings.glassRimMetrics(forFrost: 1.0, isDark: false)
    expect(
        clearRim.specularPeakAlpha > clearRim.specularMidAlpha * 4.0
            && clearRim.outerContactAlpha > frostedRim.outerContactAlpha
            && frostedRim.bevelWidth > clearRim.bevelWidth
            && frostedRim.bevelBlur > clearRim.bevelBlur
            && frostedRim.specularMidAlpha > clearRim.specularMidAlpha,
        "glassRimMetrics adapts bevel thickness, corner catch-lights, and outer refractive contour with clarity"
    )

    // LaunchServices lsappinfo badge parsing + DockSnapshot merge + centered indicator gap
    let sampleLSOutput = """
    { "CFBundleIdentifier"="com.openai.codex", "LSASN"=ASN:0x0-0xd21d21:, "StatusLabel"={ "label"="1" } }
    ---
    { "CFBundleIdentifier"="com.tencent.xinWeChat", "LSASN"=ASN:0x0-0x3e03e:, "StatusLabel"={ "label"="99+" } }
    ---
    { "CFBundleIdentifier"="com.google.Chrome", "LSASN"=ASN:0x0-0xb23b23:, "StatusLabel"={ "label"="" } }
    ---
    { "CFBundleIdentifier"="com.apple.Safari", "LSASN"=ASN:0x0-0x11111:, "StatusLabel"={ "label"="0" } }
    """
    let parsedLS = AXWindowController.parseLSAppInfoBadges(from: sampleLSOutput)
    let lsSnap = AXWindowController.DockBadgeSnapshot(byBundleID: parsedLS)
    let axSnap = AXWindowController.DockBadgeSnapshot(byBundleID: ["com.anthropic.claudefordesktop": "3"])
    let mergedSnap = lsSnap.merged(with: axSnap)
    expect(
        parsedLS["com.openai.codex"] == "1"
            && parsedLS["com.tencent.xinwechat"] == "99+"
            && parsedLS["com.google.chrome"] == nil
            && parsedLS["com.apple.safari"] == nil
            && mergedSnap.badge(forBundleID: "com.openai.codex", appURL: URL(fileURLWithPath: "/Applications/ChatGPT.app"), displayName: "ChatGPT") == "1"
            && mergedSnap.badge(forBundleID: "com.anthropic.claudefordesktop", appURL: URL(fileURLWithPath: "/Applications/Claude.app"), displayName: "Claude") == "3"
            && DisplayGeometry.islandIndicatorOuterPadding > DisplayGeometry.horizontalIndicatorGap,
        "LaunchServices badge parser & snapshot merge resolve unread counts reliably and center status dots"
    )

    // Motion Presets (Vivid vs Minimal & Snappy)
    var motionPresetSettings = StageSettings()
    expect(
        motionPresetSettings.isVividMotionPreset && !motionPresetSettings.isMinimalMotionPreset,
        "Default StageSettings starts in Vivid motion preset"
    )
    motionPresetSettings.applyMinimalMotionPreset()
    expect(
        motionPresetSettings.radialParticleStyle == .off
            && !motionPresetSettings.radialParticleEffects
            && motionPresetSettings.magnificationScale == 1.0
            && !motionPresetSettings.animateOpeningApps
            && motionPresetSettings.windowPopAnimationStyle == .off
            && motionPresetSettings.appearAnimationStyle == .flash
            && !motionPresetSettings.smoothWindowTransitions
            && motionPresetSettings.animationSpeed == .fast
            && motionPresetSettings.isMinimalMotionPreset
            && !motionPresetSettings.isVividMotionPreset,
        "applyMinimalMotionPreset disables distracting effects and keeps snappy fast speed"
    )
    motionPresetSettings.magnificationScale = 1.3
    expect(
        !motionPresetSettings.isMinimalMotionPreset && !motionPresetSettings.isVividMotionPreset,
        "Tweaking a single motion option after preset switches detection to custom state"
    )
    motionPresetSettings.applyVividMotionPreset()
    expect(
        motionPresetSettings.radialParticleStyle == .sparkBurst
            && motionPresetSettings.radialParticleEffects
            && motionPresetSettings.magnificationScale == 1.42
            && motionPresetSettings.animateOpeningApps
            && motionPresetSettings.windowPopAnimationStyle == .off
            && motionPresetSettings.appearAnimationStyle == .roll
            && motionPresetSettings.smoothWindowTransitions
            && motionPresetSettings.animationSpeed == .fast
            && motionPresetSettings.isVividMotionPreset
            && !motionPresetSettings.isMinimalMotionPreset,
        "applyVividMotionPreset restores standard expressive motion defaults"
    )

    // Trackpad 1-finger slide & 2-finger continuous scroll resize scaling
    let shrunkDrag = DisplayGeometry.adjustedWindowScale(current: 1.0, pointerDeltaY: -60)
    let grownDrag = DisplayGeometry.adjustedWindowScale(current: shrunkDrag, pointerDeltaY: 30)
    let shrunkScroll = DisplayGeometry.adjustedWindowScale(current: 1.0, scrollDelta: -45, precise: true)
    let notchedStep = DisplayGeometry.adjustedWindowScale(current: 0.70, scrollDelta: 1, precise: false)
    let clampedMin = DisplayGeometry.adjustedWindowScale(current: 0.45, pointerDeltaY: -100)
    let clampedMax = DisplayGeometry.adjustedWindowScale(current: 1.0, scrollDelta: 100, precise: true)
    expect(
        abs(shrunkDrag - 0.75) < 0.001
            && abs(grownDrag - 0.875) < 0.001
            && abs(shrunkScroll - 0.75) < 0.001
            && abs(notchedStep - 0.75) < 0.001
            && clampedMin == 0.45
            && clampedMax == 1.0,
        "DisplayGeometry.adjustedWindowScale handles 1-finger drag, 2-finger trackpad scroll, and notched wheel clamping cleanly"
    )

    // Independent Dynamic Island and Loop Ring animation speeds + legacy migration
    let legacySpeedJSON = """
    {"animationSpeed": "relaxed"}
    """.data(using: .utf8)!
    let legacySpeedDecoded = try JSONDecoder().decode(StageSettings.self, from: legacySpeedJSON)
    var splitSpeedSettings = StageSettings()
    splitSpeedSettings.islandAnimationSpeed = .instant
    splitSpeedSettings.ringAnimationSpeed = .smooth
    let splitSpeedData = try JSONEncoder().encode(splitSpeedSettings)
    let splitSpeedDecoded = try JSONDecoder().decode(StageSettings.self, from: splitSpeedData)
    var customMinimal = StageSettings()
    customMinimal.applyMinimalMotionPreset()
    customMinimal.ringAnimationSpeed = .relaxed
    expect(
        legacySpeedDecoded.islandAnimationSpeed == .relaxed
            && legacySpeedDecoded.ringAnimationSpeed == .relaxed
            && splitSpeedDecoded.islandAnimationSpeed == .instant
            && splitSpeedDecoded.ringAnimationSpeed == .smooth
            && AnimationSpeedPreset.instant.springScale == 0.0
            && AnimationSpeedPreset.fast.springScale < AnimationSpeedPreset.smooth.springScale
            && AnimationSpeedPreset.smooth.springScale < AnimationSpeedPreset.relaxed.springScale
            && !customMinimal.isMinimalMotionPreset,
        "Independent islandAnimationSpeed and ringAnimationSpeed encode/decode, migrate legacy speed, and gate minimal preset accurately"
    )

    // 1-key unified Trackpad flow (Left Option only) + optional split-hold conflict resolution
    var unifiedSettings = StageSettings()
    let defaultConflicts = unifiedSettings.modifierKeyConflicts()
    unifiedSettings.splitKeyboardMode = .modifierHold
    unifiedSettings.splitModifierKey = .leftOption
    let appSplitConflicts = unifiedSettings.modifierKeyConflicts()
    unifiedSettings.resolveModifierKeyConflicts()
    unifiedSettings.ringScrollResizeEnabled = false
    let retiredOptionScrollJSON = """
    {"splitMouseTrigger": "option_scroll"}
    """.data(using: .utf8)!
    let retiredOptionScrollDecoded = try JSONDecoder().decode(StageSettings.self, from: retiredOptionScrollJSON)
    let unifiedData = try JSONEncoder().encode(unifiedSettings)
    let unifiedDecoded = try JSONDecoder().decode(StageSettings.self, from: unifiedData)
    expect(
        StageSettings().radialKeyboardMode == .modifierHold
            && StageSettings().radialModifierKey == .leftOption
            && StageSettings().splitKeyboardMode == .disabled
            && StageSettings().ringScrollResizeEnabled
            && defaultConflicts.isEmpty
            && appSplitConflicts == [.appAndSplitSameKey]
            && unifiedSettings.modifierKeyConflicts().isEmpty
            && retiredOptionScrollDecoded.splitMouseTrigger == .disabled
            && !unifiedDecoded.ringScrollResizeEnabled
            && unifiedDecoded.splitKeyboardMode == .modifierHold,
        "1-key unified control defaults cleanly, retires option_scroll, and checks app-vs-split conflicts"
    )
}

// 6. Manual curation check: scanAllInstalledApps works cleanly for manual picker
do {
    let discovery = AppDiscoveryService()
    let all = discovery.scanAllInstalledApps()
    expect(all.count >= 5, "Installed apps scanner available for manual '+' picker (\(all.count) apps)")
}

print("\nResults: \(passed) passed, \(failed) failed.")
if failed > 0 {
    exit(1)
}
