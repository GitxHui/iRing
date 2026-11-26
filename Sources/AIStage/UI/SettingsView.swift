import AIStageCore
import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance = "appearance"
    case general = "general"
    case shortcuts = "shortcuts"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "外观"
        case .general: return "通用"
        case .shortcuts: return "快捷键"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .general: return "gearshape"
        case .shortcuts: return "command"
        }
    }
}

/// Focused macOS native Settings window keeping only essential, plain-language controls.
public struct SettingsView: View {
    @ObservedObject var coordinator: StageCoordinator
    @State private var selectedTab: SettingsTab = .appearance
    @State private var previewSelectedIndex: Int? = 0
    @State private var previewWedgeDegrees: Double = 0
    @State private var previewBurstUntil: Date = .distantPast
    @State private var screenCaptureAuthorized: Bool = WindowSnapshotCache.isScreenCaptureAuthorized

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 150, ideal: 164, max: 185)
        } detail: {
            detailContent
                .navigationTitle(selectedTab.title)
        }
        .toolbar(removing: .sidebarToggle)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            screenCaptureAuthorized = WindowSnapshotCache.isScreenCaptureAuthorized
        }
    }

    private var sidebar: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailContent: some View {
        Form {
            if !coordinator.isAccessibilityTrusted {
                accessibilityWarningSection
            }

            switch selectedTab {
            case .appearance:
                appearanceSections
            case .general:
                generalSections
            case .shortcuts:
                shortcutsSections
            }
        }
        .formStyle(.grouped)
    }

    private var accessibilityWarningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("需要辅助功能权限")
                        .font(.headline)
                    Text("用于切换窗口、分屏落点与同步未读红点。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("前往授权") {
                    coordinator.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("重启生效") {
                    coordinator.relaunchSelf()
                }
                .controlSize(.small)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Tab 1: Appearance

    @ViewBuilder
    private var appearanceSections: some View {
        Section("灵动岛") {
            Picker("显示模式", selection: Binding(
                get: { coordinator.settings.dockShape },
                set: { val in coordinator.setDockShape(val) }
            )) {
                ForEach(DockShapeMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if coordinator.settings.dockShape == .dynamicIsland {
                Picker("外观", selection: Binding(
                    get: { coordinator.settings.dynamicIslandTheme },
                    set: { val in coordinator.updateSettings { $0.dynamicIslandTheme = val } }
                )) {
                    ForEach(DynamicIslandTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }

                Picker("展开方向", selection: Binding(
                    get: { coordinator.settings.islandExpandAxis },
                    set: { val in coordinator.updateSettings { $0.islandExpandAxis = val } }
                )) {
                    ForEach(IslandExpandAxis.allCases) { axis in
                        Text(axis.label).tag(axis)
                    }
                }

                Toggle("固定展开", isOn: Binding(
                    get: { coordinator.settings.dynamicIslandPinned },
                    set: { val in coordinator.updateSettings { $0.dynamicIslandPinned = val } }
                ))

                HStack {
                    Text("图标大小")
                    Slider(
                        value: Binding(
                            get: { coordinator.settings.iconSize },
                            set: { val in coordinator.updateSettings { $0.iconSize = round(val) } }
                        ),
                        in: 28...64,
                        step: 1
                    )
                    .labelsHidden()
                    Text("\(Int(coordinator.settings.iconSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                let isVertIsland = coordinator.settings.isExpandedIslandVertical
                let topBand: CGFloat = (coordinator.settings.islandPosition == .top && coordinator.screenHasNotch)
                    ? max(32, coordinator.screenNotchHeight)
                    : DisplayGeometry.islandHeaderInset
                let minSafeDepth = Double(
                    DisplayGeometry.minExpandedIslandDepth(
                        settings: coordinator.settings,
                        topBand: topBand,
                        isVerticalTray: isVertIsland
                    )
                )
                let wRange: ClosedRange<Double> = isVertIsland ? min(260, minSafeDepth)...260 : 280...1000
                let wStep: Double = isVertIsland ? 4 : 10
                let liveW = min(wRange.upperBound, max(wRange.lowerBound, Double(coordinator.dockVisualLength.width)))
                HStack {
                    Text("灵动岛宽度")
                    Slider(
                        value: Binding(
                            get: {
                                coordinator.settings.islandCustomWidth > 1
                                    ? min(wRange.upperBound, max(wRange.lowerBound, coordinator.settings.islandCustomWidth))
                                    : liveW
                            },
                            set: { val in coordinator.updateSettings { $0.islandCustomWidth = round(val) } }
                        ),
                        in: wRange,
                        step: wStep
                    )
                    .labelsHidden()
                    HStack(spacing: 4) {
                        Text(coordinator.settings.islandCustomWidth > 1 ? "\(Int(coordinator.settings.islandCustomWidth)) pt" : "自动")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if coordinator.settings.islandCustomWidth > 1 {
                            Button("自动") {
                                coordinator.updateSettings { $0.islandCustomWidth = 0 }
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                        }
                    }
                    .frame(minWidth: 74, alignment: .trailing)
                }

                let hRange: ClosedRange<Double> = isVertIsland ? 240...860 : min(240, minSafeDepth)...240
                let hStep: Double = isVertIsland ? 10 : 2
                let liveH = min(hRange.upperBound, max(hRange.lowerBound, Double(coordinator.dockVisualLength.height)))
                HStack {
                    Text("灵动岛高度")
                    Slider(
                        value: Binding(
                            get: {
                                coordinator.settings.islandCustomHeight > 1
                                    ? min(hRange.upperBound, max(hRange.lowerBound, coordinator.settings.islandCustomHeight))
                                    : liveH
                            },
                            set: { val in coordinator.updateSettings { $0.islandCustomHeight = round(val) } }
                        ),
                        in: hRange,
                        step: hStep
                    )
                    .labelsHidden()
                    HStack(spacing: 4) {
                        Text(coordinator.settings.islandCustomHeight > 1 ? "\(Int(coordinator.settings.islandCustomHeight)) pt" : "自动")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if coordinator.settings.islandCustomHeight > 1 {
                            Button("自动") {
                                coordinator.updateSettings { $0.islandCustomHeight = 0 }
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                        }
                    }
                    .frame(minWidth: 74, alignment: .trailing)
                }

                HStack {
                    Text("留白边距")
                    Slider(
                        value: Binding(
                            get: { coordinator.settings.islandContentPadding },
                            set: { val in coordinator.updateSettings { $0.islandContentPadding = round(val) } }
                        ),
                        in: 8...64,
                        step: 2
                    )
                    .labelsHidden()
                    Text("\(Int(coordinator.settings.islandContentPadding)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                HStack {
                    Text("图标间距")
                    Slider(
                        value: Binding(
                            get: { coordinator.settings.iconSpacing },
                            set: { val in coordinator.updateSettings { $0.iconSpacing = round(val) } }
                        ),
                        in: 0...24,
                        step: 1
                    )
                    .labelsHidden()
                    Text("\(Int(coordinator.settings.iconSpacing)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }

                Text("拖动灵动岛留白处即可吸附到屏幕上下左右边缘，或直接拖到其他显示器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("灵动岛已隐藏，按住触发键拖动即可在光标处呼出快捷圆环。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("快捷圆环") {
            loopLivePreviewCard

            Picker("款式", selection: Binding(
                get: { coordinator.settings.radialStyle },
                set: { style in
                    previewBurstUntil = Date().addingTimeInterval(0.9)
                    coordinator.updateSettings {
                        $0.radialStyle = style
                        $0.radialThickness = style.defaultThickness
                        $0.radialCornerRatio = style.defaultCornerRatio
                    }
                }
            )) {
                ForEach(LoopRadialStyle.allCases) { style in
                    Label(style.label, systemImage: style.symbolName).tag(style)
                }
            }

            Picker("配色", selection: Binding(
                get: { coordinator.settings.radialTheme },
                set: { val in
                    previewBurstUntil = Date().addingTimeInterval(0.9)
                    coordinator.updateSettings { $0.radialTheme = val }
                }
            )) {
                ForEach(LoopAccentTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }

            HStack {
                Text("自定义调色盘")
                Spacer()
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { LoopThemeColors.color(fromHex: coordinator.settings.customRingColorHex) },
                        set: { newColor in
                            previewBurstUntil = Date().addingTimeInterval(0.9)
                            let hex = LoopThemeColors.hexString(from: newColor)
                            coordinator.updateSettings {
                                $0.customRingColorHex = hex
                                $0.radialTheme = .custom
                            }
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("颜色深度")
                    Spacer()
                    Text("\(Int(round(coordinator.settings.ringColorDepth * 100)))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { coordinator.settings.ringColorDepth },
                        set: { val in
                            previewBurstUntil = Date().addingTimeInterval(0.6)
                            coordinator.updateSettings { $0.ringColorDepth = (val * 20).rounded() / 20 }
                        }
                    ),
                    in: 0.25...1.0,
                    step: 0.05
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 2)

            Picker("粒子动效", selection: Binding(
                get: { coordinator.settings.radialParticleStyle },
                set: { val in
                    previewBurstUntil = Date().addingTimeInterval(1.6)
                    coordinator.updateSettings {
                        $0.radialParticleStyle = val
                        $0.radialParticleEffects = (val != .off)
                    }
                }
            )) {
                ForEach(LoopParticleStyle.allCases) { style in
                    Label(style.label, systemImage: style.symbolName).tag(style)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("出现方式")
                Picker("出现方式", selection: Binding(
                    get: { coordinator.settings.appearAnimationStyle },
                    set: { val in coordinator.updateSettings { $0.appearAnimationStyle = val } }
                )) {
                    ForEach(AppearAnimationStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.vertical, 2)

            HStack {
                Text("圆环大小")
                Slider(
                    value: Binding(
                        get: { coordinator.settings.radialRingDiameter },
                        set: { val in coordinator.updateSettings { $0.radialRingDiameter = round(val) } }
                    ),
                    in: 240...360,
                    step: 4
                )
                Text("\(Int(coordinator.settings.radialRingDiameter)) pt")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("应用排序")
                Picker("应用排序", selection: Binding(
                    get: { coordinator.settings.radialAppOrderMode },
                    set: { val in coordinator.updateSettings { $0.radialAppOrderMode = val } }
                )) {
                    ForEach(RadialAppOrderMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if coordinator.settings.radialAppOrderMode == .frequentFirst {
                    Text("常用应用会自动靠前排列，方便应用较多时快速定位。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("显示未启动应用", isOn: Binding(
                    get: { coordinator.settings.showInactiveAppsInRing },
                    set: { val in coordinator.updateSettings { $0.showInactiveAppsInRing = val } }
                ))
                if !coordinator.settings.showInactiveAppsInRing {
                    Text("仅在圆环显示运行中的应用；全部未启动时自动回退显示全部。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tab 2: General

    @ViewBuilder
    private var generalSections: some View {
        Section("基础") {
            Toggle("开机自启动", isOn: Binding(
                get: { coordinator.settings.launchAtLogin },
                set: { val in coordinator.updateSettings { $0.launchAtLogin = val } }
            ))

            VStack(alignment: .leading, spacing: 4) {
                Toggle("隐藏菜单栏图标", isOn: Binding(
                    get: { coordinator.settings.hideMenuBarIcon },
                    set: { val in coordinator.updateSettings { $0.hideMenuBarIcon = val } }
                ))
                if coordinator.settings.hideMenuBarIcon {
                    Text("隐藏后可在灵动岛右键，或重新打开 iRing.app 进入偏好设置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("同步未读消息红点", isOn: Binding(
                get: { coordinator.settings.showNotificationBadges },
                set: { val in
                    coordinator.updateSettings { $0.showNotificationBadges = val }
                    coordinator.refreshRuntimeInfo()
                }
            ))
        }

        Section("窗口与动效") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("动画速度")
                    Spacer()
                    Text(coordinator.settings.animationSpeed.shortLabel)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.16)))
                }
                Slider(
                    value: Binding(
                        get: { coordinator.settings.animationSpeed.sliderIndex },
                        set: { val in
                            let preset = AnimationSpeedPreset.from(sliderIndex: val)
                            coordinator.updateSettings { $0.animationSpeed = preset }
                        }
                    ),
                    in: 0...3,
                    step: 1
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                HStack {
                    ForEach(AnimationSpeedPreset.allCases) { preset in
                        Text(preset.shortLabel)
                            .font(.caption2)
                            .foregroundStyle(coordinator.settings.animationSpeed == preset ? .primary : .secondary)
                        if preset != .relaxed {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("窗口弹出效果")
                    Spacer()
                    if screenCaptureAuthorized {
                        Label("已授权屏幕录制", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Button("授权屏幕录制") {
                            _ = WindowSnapshotCache.requestScreenCaptureAccess()
                            screenCaptureAuthorized = WindowSnapshotCache.isScreenCaptureAuthorized
                        }
                        .controlSize(.small)
                    }
                }
                Picker("窗口弹出效果", selection: Binding(
                    get: { coordinator.settings.windowPopAnimationStyle },
                    set: { val in coordinator.updateSettings { $0.windowPopAnimationStyle = val } }
                )) {
                    ForEach(WindowPopAnimationStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("授权屏幕录制后，窗口弹出时将呈现真实窗口画面。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            Toggle("单窗专注模式（切换时隐藏同屏其他应用）", isOn: Binding(
                get: { coordinator.settings.hideInactiveStagedApps },
                set: { val in coordinator.updateSettings { $0.hideInactiveStagedApps = val } }
            ))

            VStack(alignment: .leading, spacing: 4) {
                Toggle("多屏保留副屏窗口", isOn: Binding(
                    get: { coordinator.settings.multiScreenAppPolicy != .followDockScreen },
                    set: { keepOther in
                        coordinator.updateSettings {
                            $0.multiScreenAppPolicy = keepOther ? .smartKeepOtherScreen : .followDockScreen
                        }
                    }
                ))
                Text("已在另一块屏幕打开的应用切换时留在原屏，不被误隐藏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tab 3: Shortcuts & Triggers

    @ViewBuilder
    private var radialTriggerControls: some View {
        Picker("鼠标呼出方式", selection: Binding(
            get: { coordinator.settings.radialTrigger },
            set: { val in coordinator.updateSettings { $0.radialTrigger = val } }
        )) {
            ForEach(RadialTriggerMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }

        if coordinator.settings.radialTrigger == .customMouse {
            MouseTriggerRecorderRow(coordinator: coordinator)
        }

        Picker("键盘呼出方式", selection: Binding(
            get: { coordinator.settings.radialKeyboardMode },
            set: { val in coordinator.updateSettings { $0.radialKeyboardMode = val } }
        )) {
            ForEach(RadialKeyboardTriggerMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }

        if coordinator.settings.radialKeyboardMode == .keyCombo {
            ShortcutRecorderRow(
                title: "切应用圆环快捷键",
                shortcut: coordinator.settings.radialKeyboardShortcut,
                defaultShortcut: .optionQ,
                isCustomized: coordinator.settings.radialKeyboardShortcut != .optionQ,
                coordinator: coordinator,
                onRecord: { combo in
                    coordinator.updateSettings { $0.radialKeyboardShortcut = combo }
                },
                onReset: {
                    coordinator.updateSettings { $0.radialKeyboardShortcut = .optionQ }
                }
            )
        } else if coordinator.settings.radialKeyboardMode == .modifierHold {
            Picker("长按修饰键", selection: Binding(
                get: { coordinator.settings.radialModifierKey },
                set: { val in coordinator.updateSettings { $0.radialModifierKey = val } }
            )) {
                ForEach(RadialModifierKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
        }
    }

    @ViewBuilder
    private var shortcutsSections: some View {
        Section("呼出快捷圆环") {
            radialTriggerControls

            Picker("圆环滚轮缩放按键", selection: Binding(
                get: { coordinator.settings.ringResizeModifier },
                set: { val in coordinator.updateSettings { $0.ringResizeModifier = val } }
            )) {
                ForEach(RingResizeModifier.allCases) { mod in
                    Text(mod.label).tag(mod)
                }
            }
        }

        Section("分屏圆环") {
            Picker("鼠标呼出分屏", selection: Binding(
                get: { coordinator.settings.splitMouseTrigger },
                set: { val in coordinator.updateSettings { $0.splitMouseTrigger = val } }
            )) {
                ForEach(SplitMouseTriggerMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if coordinator.settings.splitMouseTrigger == .customMouse {
                SplitMouseTriggerRecorderRow(coordinator: coordinator)
            }

            Toggle("分屏圆环快捷键", isOn: Binding(
                get: { coordinator.settings.splitRingHotkeyEnabled },
                set: { val in coordinator.updateSettings { $0.splitRingHotkeyEnabled = val } }
            ))

            if coordinator.settings.splitRingHotkeyEnabled {
                ShortcutRecorderRow(
                    title: "呼出分屏圆环",
                    shortcut: coordinator.settings.effectiveSplitRingShortcut,
                    defaultShortcut: .optionS,
                    isCustomized: coordinator.settings.effectiveSplitRingShortcut != .optionS,
                    coordinator: coordinator,
                    onRecord: { combo in
                        coordinator.updateSettings { $0.splitRingShortcut = combo }
                    },
                    onReset: {
                        coordinator.updateSettings { $0.splitRingShortcut = .optionS }
                    }
                )
            }

            Text("指向窗口呼出直接为该窗口分屏；指向空白桌面呼出先选区再挑应用填入；按住缩放键配滚轮可微调窗口大小。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("全局快捷键") {
            ShortcutRecorderRow(
                title: "显示 / 隐藏工作台",
                shortcut: coordinator.settings.effectiveToggleShortcut,
                defaultShortcut: .optionSpace,
                isCustomized: coordinator.settings.effectiveToggleShortcut != .optionSpace,
                coordinator: coordinator,
                onRecord: { combo in
                    coordinator.updateSettings { $0.customToggleShortcut = combo }
                },
                onReset: {
                    coordinator.updateSettings {
                        $0.customToggleShortcut = nil
                        $0.toggleHotkey = .optionSpace
                    }
                }
            )
        }

        if coordinator.isAccessibilityTrusted {
            Section("权限状态") {
                HStack {
                    Label("辅助功能权限已就绪", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("重新检测") {
                        coordinator.refreshRuntimeInfo()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Interactive Radial Preview Card

    private var loopLivePreviewCard: some View {
        let palette = LoopThemeColors.colors(for: coordinator.settings)
        let previewItems: [LoopRadialRenderItem] = {
            if !coordinator.radialDisplayedApps.isEmpty {
                return coordinator.radialDisplayedApps.prefix(6).map {
                    LoopRadialRenderItem(
                        id: $0.bundleIdentifier,
                        name: $0.displayName,
                        icon: coordinator.discovery.icon(for: $0),
                        isRunning: coordinator.runtimeInfo[$0.bundleIdentifier]?.isRunning == true
                    )
                }
            }
            let syms = [("ChatGPT", "bubble.left.and.bubble.right.fill"), ("Claude", "sparkles"), ("Gemini", "star.fill"), ("Cursor", "terminal.fill")]
            return syms.enumerated().map { idx, pair in
                let img = NSImage(systemSymbolName: pair.1, accessibilityDescription: pair.0) ?? NSImage()
                return LoopRadialRenderItem(id: "sample-\(idx)", name: pair.0, icon: img, isRunning: idx < 2)
            }
        }()

        let safeSel: Int? = previewSelectedIndex.flatMap { $0 < previewItems.count ? $0 : 0 }
        let panelSide = LoopRadialArtwork.panelSize(for: coordinator.settings)
        let fitScale = min(0.74, 196.0 / max(1, panelSide))

        return TimelineView(.periodic(from: .now, by: 0.45)) { ctx in
            let pStyle = coordinator.settings.effectiveParticleStyle
            let animatePreview = ctx.date < previewBurstUntil
                || coordinator.settings.radialStyle == .appleGlow
                || pStyle == .orbitalDust
                || pStyle == .auroraRibbon
                || pStyle.isVortexStyle

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.primary.opacity(0.14), palette.secondary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [palette.primary.opacity(0.70), palette.secondary.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: CGFloat(min(4.5, coordinator.settings.previewBorderThickness * 0.65))
                            )
                    )

                LoopRadialArtwork(
                    items: previewItems,
                    selectedIndex: safeSel,
                    wedgeRotationDegrees: previewWedgeDegrees,
                    isShown: true,
                    settings: coordinator.settings,
                    isAccessibilityTrusted: coordinator.isAccessibilityTrusted,
                    continuousAnimation: animatePreview,
                    useBehindWindowBlur: false
                )
                .frame(width: panelSide, height: panelSide)
                .scaleEffect(fitScale)
                .frame(height: 204)

                VStack {
                    Spacer()
                    HStack {
                        Text("实时效果预览（点击触发粒子与转向）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(palette.primary).frame(width: 8, height: 8)
                            Circle().fill(palette.secondary).frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: 222)
        .contentShape(Rectangle())
        .onTapGesture {
            previewBurstUntil = Date().addingTimeInterval(0.95)
            let count = max(1, previewItems.count)
            let next: Int? = if let cur = safeSel {
                (cur + 1 < count) ? (cur + 1) : nil
            } else {
                0
            }
            if let nextIdx = next {
                let targetDeg = LoopRadialController.shortestTargetDegrees(
                    from: previewWedgeDegrees,
                    toIndex: nextIdx,
                    count: count
                )
                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.8)) {
                    previewWedgeDegrees = targetDeg
                    previewSelectedIndex = nextIdx
                }
            } else {
                withAnimation(.easeOut(duration: 0.14)) {
                    previewSelectedIndex = nil
                }
            }
        }
    }
}

// MARK: - Interactive Shortcut & Mouse Recorders

private func recorderPortableModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var mask: UInt32 = 0
    if flags.contains(.control) { mask |= CustomKeyCombo.modControl }
    if flags.contains(.option) { mask |= CustomKeyCombo.modOption }
    if flags.contains(.shift) { mask |= CustomKeyCombo.modShift }
    if flags.contains(.command) { mask |= CustomKeyCombo.modCommand }
    return mask
}

private struct ShortcutRecorderRow: View {
    let title: String
    let shortcut: CustomKeyCombo
    let defaultShortcut: CustomKeyCombo
    let isCustomized: Bool
    @ObservedObject var coordinator: StageCoordinator
    let onRecord: (CustomKeyCombo) -> Void
    let onReset: () -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "请按下快捷键…" : shortcut.displayString)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isRecording ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isRecording ? 1.2 : 0.75
                            )
                    )
            }
            .buttonStyle(.plain)

            if isCustomized && !isRecording {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("恢复默认（\(defaultShortcut.displayString)）")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        coordinator.setHotkeysSuspended(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = recorderPortableModifiers(from: event.modifierFlags)
            if event.keyCode == 53 && mods == 0 {
                stopRecording()
                return nil
            }
            let combo = CustomKeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
            guard combo.isValidShortcut else {
                NSSound.beep()
                return nil
            }
            onRecord(combo)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        if isRecording {
            isRecording = false
            coordinator.setHotkeysSuspended(false)
        }
    }
}

private struct MouseTriggerRecorderRow: View {
    @ObservedObject var coordinator: StageCoordinator
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text("鼠标触发键")
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "请按下鼠标中键 / 侧键…" : coordinator.settings.customMouseTriggerDisplayString)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isRecording ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isRecording ? 1.2 : 0.75
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .rightMouseDown, .keyDown]) { event in
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    stopRecording()
                    return nil
                }
                return event
            }
            let btn = (event.type == .rightMouseDown) ? 1 : event.buttonNumber
            let mods = recorderPortableModifiers(from: event.modifierFlags)
            coordinator.updateSettings {
                $0.radialTrigger = .customMouse
                $0.radialCustomMouseButton = btn
                $0.radialCustomMouseModifiers = mods
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}

private struct SplitMouseTriggerRecorderRow: View {
    @ObservedObject var coordinator: StageCoordinator
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text("自定义分屏按键")
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "请按修饰键 + 鼠标键…" : coordinator.settings.splitCustomMouseDisplayString)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isRecording ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isRecording ? 1.2 : 0.75
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .rightMouseDown, .keyDown]) { event in
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    stopRecording()
                    return nil
                }
                return event
            }
            let btn = (event.type == .rightMouseDown) ? 1 : event.buttonNumber
            let mods = recorderPortableModifiers(from: event.modifierFlags)
            coordinator.updateSettings {
                $0.splitMouseTrigger = .customMouse
                $0.splitCustomMouseButton = btn
                $0.splitCustomMouseModifiers = mods
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}
