import AIStageCore
import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case dynamicIsland = "dynamic_island"
    case radialRing = "radial_ring"
    case general = "general"
    case shortcuts = "shortcuts"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dynamicIsland: return L10n.t("灵动岛", "Dynamic Island")
        case .radialRing: return L10n.t("快捷圆环", "Loop Ring")
        case .general: return L10n.t("通用", "General")
        case .shortcuts: return L10n.t("快捷键", "Shortcuts")
        }
    }

    var icon: String {
        switch self {
        case .dynamicIsland: return "dock.rectangle"
        case .radialRing: return "circle.circle"
        case .general: return "gearshape"
        case .shortcuts: return "command"
        }
    }
}

/// Focused macOS native Settings window keeping only essential, plain-language controls.
public struct SettingsView: View {
    @ObservedObject var coordinator: StageCoordinator
    @State private var selectedTab: SettingsTab = .dynamicIsland
    @State private var previewSelectedIndex: Int? = 0
    @State private var previewWedgeDegrees: Double = 0
    @State private var previewBurstUntil: Date = .distantPast

    public var body: some View {
        let _ = coordinator.settings.language
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 150, ideal: 164, max: 185)
        } detail: {
            detailContent
                .navigationTitle(selectedTab.title)
        }
        .toolbar(removing: .sidebarToggle)
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
            case .dynamicIsland:
                dynamicIslandSections
            case .radialRing:
                radialRingSections
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
                    Text(L10n.t("需要辅助功能权限", "Accessibility Permission Required"))
                        .font(.headline)
                    Text(L10n.t(
                        "用于切换窗口、分屏落点与同步未读红点。",
                        "Required to switch windows, tile splits, and sync unread badges."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.t("前往授权", "Authorize")) {
                    coordinator.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(L10n.t("重启生效", "Relaunch")) {
                    coordinator.relaunchSelf()
                }
                .controlSize(.small)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func animationSpeedSlider(title: String, selection: Binding<AnimationSpeedPreset>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(selection.wrappedValue.shortLabel)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.16)))
            }
            Slider(
                value: Binding(
                    get: { selection.wrappedValue.sliderIndex },
                    set: { val in
                        selection.wrappedValue = AnimationSpeedPreset.from(sliderIndex: val)
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
                        .foregroundStyle(selection.wrappedValue == preset ? .primary : .secondary)
                    if preset != .relaxed {
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tab 1: Dynamic Island

    @ViewBuilder
    private var dynamicIslandSections: some View {
        Section(L10n.t("外观与布局", "Appearance & Layout")) {
            Picker(L10n.t("显示模式", "Display Mode"), selection: Binding(
                get: { coordinator.settings.dockShape },
                set: { val in coordinator.setDockShape(val) }
            )) {
                ForEach(DockShapeMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if coordinator.settings.dockShape == .dynamicIsland {
                IslandThemeCardRow(
                    selectedTheme: coordinator.settings.dynamicIslandTheme,
                    onSelect: { theme in
                        coordinator.updateSettings { $0.dynamicIslandTheme = theme }
                    }
                )

                if coordinator.settings.dynamicIslandTheme == .appleGlass {
                    LiquidGlassClarityRow(coordinator: coordinator)
                }

                Picker(L10n.t("屏幕位置", "Position on Screen"), selection: Binding(
                    get: { coordinator.settings.islandPosition },
                    set: { val in coordinator.updateSettings { $0.islandPosition = val } }
                )) {
                    ForEach(DockEdgePosition.allCases) { pos in
                        Text(pos.label).tag(pos)
                    }
                }

                Picker(L10n.t("展开方向", "Expand Direction"), selection: Binding(
                    get: { coordinator.settings.islandExpandAxis },
                    set: { val in coordinator.updateSettings { $0.islandExpandAxis = val } }
                )) {
                    ForEach(IslandExpandAxis.allCases) { axis in
                        Text(axis.label).tag(axis)
                    }
                }

                let isMagEnabled = coordinator.settings.magnificationScale > 1.01
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.t("大小", "Size"))
                            Spacer()
                            Text("\(Int(coordinator.settings.iconSize)) pt")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { coordinator.settings.iconSize },
                                set: { val in
                                    coordinator.updateSettings {
                                        $0.iconSize = round(val)
                                        $0.islandCustomWidth = 0
                                        $0.islandCustomHeight = 0
                                    }
                                }
                            ),
                            in: 28...64,
                            step: 1
                        )
                        .labelsHidden()
                        HStack {
                            Text(L10n.t("小", "Small"))
                            Spacer()
                            Text(L10n.t("大", "Large"))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.t("放大", "Magnification"))
                            Spacer()
                            Text(isMagEnabled ? String(format: "%.2f×", coordinator.settings.magnificationScale) : L10n.t("关闭", "Off"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { coordinator.settings.magnificationScale },
                                set: { val in
                                    let snapped = val <= 1.02 ? 1.0 : ((val * 50).rounded() / 50)
                                    coordinator.updateSettings { $0.magnificationScale = snapped }
                                }
                            ),
                            in: 1.0...1.80,
                            step: 0.02
                        )
                        .labelsHidden()
                        HStack {
                            Text(L10n.t("关闭", "Off"))
                            Spacer()
                            Text(L10n.t("小", "Small"))
                            Spacer()
                            Text(L10n.t("大", "Large"))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 2)

                let isVertIsland = coordinator.settings.isExpandedIslandVertical
                if isVertIsland {
                    let hRange: ClosedRange<Double> = 140...860
                    let liveH = min(hRange.upperBound, max(hRange.lowerBound, Double(coordinator.dockVisualLength.height)))
                    HStack {
                        Text(L10n.t("灵动岛长度", "Island Length"))
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
                            step: 10
                        )
                        .labelsHidden()
                        HStack(spacing: 4) {
                            Text(coordinator.settings.islandCustomHeight > 1 ? "\(Int(coordinator.settings.islandCustomHeight)) pt" : L10n.t("自动", "Auto"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if coordinator.settings.islandCustomHeight > 1 {
                                Button(L10n.t("自动", "Auto")) {
                                    coordinator.updateSettings { $0.islandCustomHeight = 0 }
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                            }
                        }
                        .frame(minWidth: 74, alignment: .trailing)
                    }
                } else {
                    let minW: Double = (coordinator.settings.islandPosition == .top && coordinator.screenHasNotch)
                        ? max(220, Double(round(coordinator.screenNotchWidth + 40)))
                        : 140
                    let wRange: ClosedRange<Double> = minW...1000
                    let liveW = min(wRange.upperBound, max(wRange.lowerBound, Double(coordinator.dockVisualLength.width)))
                    HStack {
                        Text(L10n.t("灵动岛宽度", "Island Width"))
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
                            step: 10
                        )
                        .labelsHidden()
                        HStack(spacing: 4) {
                            Text(coordinator.settings.islandCustomWidth > 1 ? "\(Int(coordinator.settings.islandCustomWidth)) pt" : L10n.t("自动", "Auto"))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if coordinator.settings.islandCustomWidth > 1 {
                                Button(L10n.t("自动", "Auto")) {
                                    coordinator.updateSettings { $0.islandCustomWidth = 0 }
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                            }
                        }
                        .frame(minWidth: 74, alignment: .trailing)
                    }
                }
            } else {
                Text(L10n.t(
                    "灵动岛已隐藏，按住触发键拖动即可在光标处呼出快捷圆环。",
                    "Dynamic Island is hidden. Hold and drag your trigger to open the Radial Ring at the cursor."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if coordinator.settings.dockShape == .dynamicIsland {
            Section(L10n.t("动效与交互", "Motion & Interaction")) {
                animationSpeedSlider(
                    title: L10n.t("灵动岛动画速度", "Island Animation Speed"),
                    selection: Binding(
                        get: { coordinator.settings.islandAnimationSpeed },
                        set: { val in coordinator.updateSettings { $0.islandAnimationSpeed = val } }
                    )
                )

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L10n.t("固定展开", "Keep Island Expanded"), isOn: Binding(
                        get: { coordinator.settings.dynamicIslandPinned },
                        set: { val in coordinator.updateSettings { $0.dynamicIslandPinned = val } }
                    ))
                    if !coordinator.settings.dynamicIslandPinned {
                        Text(L10n.t("未固定时自动收起，鼠标悬停或点击即可展开。", "Automatically collapses when idle; hover or click to expand."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(L10n.t("打开时图标弹跳", "Animate Opening Apps"), isOn: Binding(
                    get: { coordinator.settings.animateOpeningApps },
                    set: { val in coordinator.updateSettings { $0.animateOpeningApps = val } }
                ))

                Picker(L10n.t("运行指示灯", "Running App Indicator"), selection: Binding(
                    get: { coordinator.settings.indicatorStyle },
                    set: { val in coordinator.updateSettings { $0.indicatorStyle = val } }
                )) {
                    ForEach(IndicatorStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }

                if coordinator.settings.indicatorStyle != .hidden {
                    Picker(L10n.t("指示灯颜色", "Indicator Color"), selection: Binding(
                        get: { coordinator.settings.indicatorColor },
                        set: { val in coordinator.updateSettings { $0.indicatorColor = val } }
                    )) {
                        ForEach(IndicatorColorPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                }

                Toggle(L10n.t("运行中的应用排在前面", "Show Running Apps First"), isOn: Binding(
                    get: { coordinator.settings.sortRunningAppsFirst },
                    set: { val in coordinator.updateSettings { $0.sortRunningAppsFirst = val } }
                ))

                VStack(alignment: .leading, spacing: 4) {
                    Picker(L10n.t("滚轮操作", "Scroll Wheel"), selection: Binding(
                        get: { coordinator.settings.scrollWheelBehavior },
                        set: { val in coordinator.updateSettings { $0.scrollWheelBehavior = val } }
                    )) {
                        ForEach(ScrollWheelBehavior.allCases) { behavior in
                            Text(behavior.label).tag(behavior)
                        }
                    }
                    Text(coordinator.settings.scrollWheelBehavior.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(L10n.t(
                    "拖动灵动岛留白处即可吸附到屏幕上下左右边缘，或直接拖到其他显示器。",
                    "Drag empty space on the island to snap to any screen edge or move across displays."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Tab 2: Loop Radial Ring

    @ViewBuilder
    private var radialRingSections: some View {
        Section(L10n.t("外观与动效", "Appearance & Motion")) {
            loopLivePreviewCard

            Picker(L10n.t("款式", "Style"), selection: Binding(
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

            Picker(L10n.t("配色", "Color Theme"), selection: Binding(
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
                Text(L10n.t("自定义颜色", "Custom Color"))
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
                    Text(L10n.t("色彩浓度", "Color Intensity"))
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

            Picker(L10n.t("粒子动效", "Particles"), selection: Binding(
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
                Text(L10n.t("出现方式", "Appear Animation"))
                Picker(L10n.t("出现方式", "Appear Animation"), selection: Binding(
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
                Text(L10n.t("圆环大小", "Ring Diameter"))
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

            animationSpeedSlider(
                title: L10n.t("圆环动画速度", "Ring Animation Speed"),
                selection: Binding(
                    get: { coordinator.settings.ringAnimationSpeed },
                    set: { val in coordinator.updateSettings { $0.ringAnimationSpeed = val } }
                )
            )
        }

        Section(L10n.t("应用列表", "App List")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("应用排序", "App Order"))
                Picker(L10n.t("应用排序", "App Order"), selection: Binding(
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
                    Text(L10n.t(
                        "常用应用会自动靠前排列，方便应用较多时快速定位。",
                        "Frequently used apps appear first for faster selection."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("显示未启动应用", "Show Unlaunched Apps"), isOn: Binding(
                    get: { coordinator.settings.showInactiveAppsInRing },
                    set: { val in coordinator.updateSettings { $0.showInactiveAppsInRing = val } }
                ))
                if !coordinator.settings.showInactiveAppsInRing {
                    Text(L10n.t(
                        "仅在圆环显示运行中的应用；全部未启动时自动回退显示全部。",
                        "Shows only running apps in the ring; falls back to all apps if none are running."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tab 2: General

    @ViewBuilder
    private var generalSections: some View {
        Section(L10n.t("基础", "Basics")) {
            Picker(L10n.t("语言", "Language"), selection: Binding(
                get: { coordinator.settings.language },
                set: { val in coordinator.updateSettings { $0.language = val } }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.label).tag(lang)
                }
            }

            Toggle(L10n.t("开机自启动", "Launch at Login"), isOn: Binding(
                get: { coordinator.settings.launchAtLogin },
                set: { val in coordinator.updateSettings { $0.launchAtLogin = val } }
            ))

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("隐藏菜单栏图标", "Hide Menu Bar Icon"), isOn: Binding(
                    get: { coordinator.settings.hideMenuBarIcon },
                    set: { val in coordinator.updateSettings { $0.hideMenuBarIcon = val } }
                ))
                if coordinator.settings.hideMenuBarIcon {
                    Text(L10n.t(
                        "隐藏后可在灵动岛右键，或重新打开 iRing.app 进入偏好设置。",
                        "Right-click the Dynamic Island or reopen iRing.app to access Settings."
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(L10n.t("同步未读消息红点", "Sync Unread Badges"), isOn: Binding(
                get: { coordinator.settings.showNotificationBadges },
                set: { val in
                    coordinator.updateSettings { $0.showNotificationBadges = val }
                    coordinator.refreshRuntimeInfo()
                }
            ))
        }

        Section(L10n.t("窗口与动效", "Windows & Motion")) {
            let isMinimalMotion = coordinator.settings.isMinimalMotionPreset
            let isVividMotion = coordinator.settings.isVividMotionPreset
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.t("动效预设", "Motion Preset"))
                    Spacer()
                    Text(
                        isMinimalMotion
                            ? L10n.t("极简极速", "Minimal & Snappy")
                            : (isVividMotion ? L10n.t("灵动模式", "Vivid") : L10n.t("自定义", "Custom"))
                    )
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.16)))
                }

                HStack(spacing: 10) {
                    Button {
                        coordinator.updateSettings { $0.applyVividMotionPreset() }
                    } label: {
                        Label(L10n.t("灵动模式", "Vivid Mode"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isVividMotion ? .accentColor : .secondary.opacity(0.35))

                    Button {
                        coordinator.updateSettings { $0.applyMinimalMotionPreset() }
                    } label: {
                        Label(L10n.t("极简极速", "Minimal & Snappy"), systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isMinimalMotion ? .accentColor : .secondary.opacity(0.35))
                }

                Text(L10n.t(
                    "极简极速将一键关闭粒子特效、悬停放大波动、打开跳动、圆环卷动与窗口滑移过渡，并保持「灵敏」响应速度；切换后仍可单独微调各项设置。",
                    "Minimal & Snappy turns off particles, hover magnification wave, open bounce, 3D ring roll, and window glide while keeping Fast response; you can still fine-tune individual options afterward."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("单窗专注模式", "Single-Window Focus"), isOn: Binding(
                    get: { coordinator.settings.hideInactiveStagedApps },
                    set: { val in coordinator.updateSettings { $0.hideInactiveStagedApps = val } }
                ))
                Text(L10n.t(
                    "切换应用时自动隐藏同一块屏幕上的其他应用（不影响另一块屏幕）。",
                    "Hides other apps on the same display when switching (other displays stay visible)."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("切窗时自动铺满屏幕", "Auto-Fit Window on Switch"), isOn: Binding(
                    get: { coordinator.settings.autoFitWindowOnSwitch },
                    set: { val in
                        coordinator.updateSettings {
                            $0.autoFitWindowOnSwitch = val
                            $0.syncLegacyMultiScreenPolicy()
                        }
                    }
                ))
                Text(L10n.t(
                    "关闭时只切应用，不改变窗口大小和位置；开启时自动缩放到铺满屏幕。",
                    "Off: focuses without changing window size or position. On: resizes windows to fit the screen when switching."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("多屏时将应用拉回当前屏幕", "Pull Apps from Other Displays"), isOn: Binding(
                    get: { coordinator.settings.pullCrossScreenAppsToIsland },
                    set: { val in
                        coordinator.updateSettings {
                            $0.pullCrossScreenAppsToIsland = val
                            $0.syncLegacyMultiScreenPolicy()
                        }
                    }
                ))
                Text(L10n.t(
                    "关闭时副屏应用留在副屏激活，不跨屏乱跑；开启时统一拉回灵动岛所在屏幕。",
                    "Off: activates apps on their own display. On: pulls switched apps onto the Dynamic Island's display."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("切窗时鼠标自动跟随", "Move Cursor to Switched Window"), isOn: Binding(
                    get: { coordinator.settings.moveCursorWithWindow },
                    set: { val in coordinator.updateSettings { $0.moveCursorWithWindow = val } }
                ))
                Text(L10n.t(
                    "切换到另一块屏幕的应用时，光标自动移到目标窗口中央。",
                    "Moves the pointer to the center of the switched window, handy across displays."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Tab 3: Shortcuts & Triggers

    @ViewBuilder
    private var radialTriggerControls: some View {
        Picker(L10n.t("手势 / 鼠标呼出", "Mouse / Trackpad Trigger"), selection: Binding(
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

        Picker(L10n.t("键盘呼出方式", "Keyboard Trigger"), selection: Binding(
            get: { coordinator.settings.radialKeyboardMode },
            set: { val in coordinator.updateSettings { $0.radialKeyboardMode = val } }
        )) {
            ForEach(RadialKeyboardTriggerMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }

        if coordinator.settings.radialKeyboardMode == .keyCombo {
            ShortcutRecorderRow(
                title: L10n.t("切应用圆环快捷键", "App Ring Shortcut"),
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
            Picker(L10n.t("长按修饰键", "Hold Modifier Key"), selection: Binding(
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
        let conflicts = coordinator.settings.modifierKeyConflicts()
        if !conflicts.isEmpty {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("修饰键存在冲突", "Modifier Key Conflict"))
                            .font(.headline)
                        ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                            Text(conflict.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(L10n.t("自动修正", "Auto-Fix")) {
                        coordinator.updateSettings { $0.resolveModifierKeyConflicts() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }

        Section(L10n.t("操控预设", "Input Preset")) {
            let isTrackpadPreset = (coordinator.settings.radialKeyboardMode == .modifierHold)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        coordinator.updateSettings {
                            $0.radialKeyboardMode = .modifierHold
                            if $0.radialModifierKey == .rightOption || $0.radialModifierKey == .rightCommand {
                                $0.radialModifierKey = .leftOption
                            }
                            $0.splitKeyboardMode = .disabled
                            $0.splitMouseTrigger = .disabled
                            $0.ringScrollResizeEnabled = true
                            $0.radialTrigger = .middleClickDrag
                        }
                    } label: {
                        Label(L10n.t("触控板模式", "Trackpad Mode"), systemImage: "rectangle.and.hand.point.up.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isTrackpadPreset ? .accentColor : .secondary.opacity(0.35))

                    Button {
                        coordinator.updateSettings {
                            $0.radialTrigger = .middleClickDrag
                            $0.splitMouseTrigger = .optionMiddle
                            $0.radialKeyboardMode = .disabled
                            $0.splitKeyboardMode = .disabled
                            $0.ringScrollResizeEnabled = true
                        }
                    } label: {
                        Label(L10n.t("鼠标模式", "Mouse Mode"), systemImage: "computermouse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(!isTrackpadPreset ? .accentColor : .secondary.opacity(0.35))
                }

                Text(L10n.t(
                    "极简单键操控（仅占左 ⌥）：按住左 ⌥ 单指滑切应用；按住时点 Tab 或轻点触控板秒切分屏；指向后直接双指上下滑缩放窗口。",
                    "One-key Trackpad flow (Left ⌥ only): Hold Left ⌥ & glide to switch apps; press Tab or tap while holding for Split Ring; two-finger scroll to resize."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }

        Section(L10n.t("切应用圆环", "App Switcher Ring")) {
            radialTriggerControls

            VStack(alignment: .leading, spacing: 4) {
                Toggle(L10n.t("圆环内滚轮 / 双指缩放窗口", "Scroll / Two-Finger Resize in Ring"), isOn: Binding(
                    get: { coordinator.settings.ringScrollResizeEnabled },
                    set: { val in coordinator.updateSettings { $0.ringScrollResizeEnabled = val } }
                ))
                Text(L10n.t(
                    "指向应用或分屏区域时，直接双指上下滑或滚动滚轮即可实时缩放窗口大小（45% ~ 100%），无需额外按键。",
                    "While pointing at an app or split zone, two-finger scroll or use the wheel directly to resize (45%–100%) with no extra modifier key."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }

        Section(L10n.t("分屏圆环", "Window Split Ring")) {
            Text(L10n.t(
                "按住切应用键时轻点触控板或按 Tab 即可秒切分屏；如需额外独立分屏触发可在下方配置。",
                "Tap the trackpad or press Tab while holding the App Ring key for Split Ring; configure optional standalone triggers below."
            ))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(L10n.t("手势 / 鼠标呼出", "Mouse / Trackpad Trigger"), selection: Binding(
                get: { coordinator.settings.splitMouseTrigger },
                set: { val in coordinator.updateSettings { $0.splitMouseTrigger = val } }
            )) {
                ForEach(SplitMouseTriggerMode.selectableCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if coordinator.settings.splitMouseTrigger == .customMouse {
                SplitMouseTriggerRecorderRow(coordinator: coordinator)
            }

            Picker(L10n.t("键盘呼出方式", "Keyboard Trigger"), selection: Binding(
                get: { coordinator.settings.splitKeyboardMode },
                set: { val in
                    coordinator.updateSettings {
                        $0.splitKeyboardMode = val
                        $0.splitRingHotkeyEnabled = (val == .keyCombo)
                    }
                }
            )) {
                ForEach(RadialKeyboardTriggerMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if coordinator.settings.splitKeyboardMode == .modifierHold {
                Picker(L10n.t("长按修饰键", "Hold Modifier Key"), selection: Binding(
                    get: { coordinator.settings.splitModifierKey },
                    set: { val in coordinator.updateSettings { $0.splitModifierKey = val } }
                )) {
                    ForEach(RadialModifierKey.allCases) { key in
                        Text(key.label).tag(key)
                    }
                }

                Toggle(L10n.t("双击后按住触发（防误触）", "Double-Tap & Hold (Prevent Accidental Trigger)"), isOn: Binding(
                    get: { coordinator.settings.splitModifierDoubleTap },
                    set: { val in coordinator.updateSettings { $0.splitModifierDoubleTap = val } }
                ))

                Text(L10n.t(
                    "请勿与「切应用长按修饰键」重复。",
                    "Avoid reusing the App Ring hold key."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if coordinator.settings.splitKeyboardMode == .keyCombo {
                ShortcutRecorderRow(
                    title: L10n.t("分屏圆环快捷键", "Split Ring Shortcut"),
                    shortcut: coordinator.settings.effectiveSplitRingShortcut,
                    defaultShortcut: .optionS,
                    isCustomized: coordinator.settings.effectiveSplitRingShortcut != .optionS,
                    coordinator: coordinator,
                    onRecord: { combo in
                        coordinator.updateSettings {
                            $0.splitRingShortcut = combo
                            $0.splitRingHotkeyEnabled = true
                        }
                    },
                    onReset: {
                        coordinator.updateSettings {
                            $0.splitRingShortcut = .optionS
                            $0.splitRingHotkeyEnabled = true
                        }
                    }
                )
            }

            Text(L10n.t(
                "指向窗口呼出直接为该窗口分屏；指向空白桌面呼出先选区再挑应用填入；按住缩放键配滚轮可微调窗口大小。",
                "Trigger over a window to tile it immediately, or over the desktop to pick a region then an app. Hold the resize modifier and scroll to fine-tune size."
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section(L10n.t("全局快捷键", "Global Shortcuts")) {
            ShortcutRecorderRow(
                title: L10n.t("显示 / 隐藏灵动岛", "Toggle Dynamic Island"),
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

            VStack(alignment: .leading, spacing: 8) {
                Picker(L10n.t("数字切应用快捷键 (1~9)", "Quick-Switch Apps (1–9)"), selection: Binding(
                    get: { coordinator.settings.numberSwitchModifier },
                    set: { val in coordinator.updateSettings { $0.numberSwitchModifier = val } }
                )) {
                    ForEach(NumberSwitchModifier.allCases) { mod in
                        Text(mod.label).tag(mod)
                    }
                }

                if coordinator.settings.numberSwitchModifier == .custom {
                    HStack(spacing: 6) {
                        Text(L10n.t("组合修饰键", "Modifiers"))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                        ForEach(
                            [
                                (CustomKeyCombo.modControl, "⌃"),
                                (CustomKeyCombo.modOption, "⌥"),
                                (CustomKeyCombo.modShift, "⇧"),
                                (CustomKeyCombo.modCommand, "⌘")
                            ],
                            id: \.0
                        ) { bit, glyph in
                            let isSelected = (coordinator.settings.customNumberSwitchModifiers & bit) != 0
                            Button {
                                let current = coordinator.settings.customNumberSwitchModifiers
                                let updated = isSelected ? (current & ~bit) : (current | bit)
                                guard updated != 0 else {
                                    NSSound.beep()
                                    return
                                }
                                coordinator.updateSettings { $0.customNumberSwitchModifiers = updated }
                            } label: {
                                Text(glyph)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .frame(width: 30, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
                                    )
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        if let prefix = coordinator.settings.effectiveNumberSwitchSymbolPrefix {
                            Text("\(prefix) 1~9")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }

                Text(L10n.t(
                    "按收缩灵动岛的显示顺序分配数字（例如第 1 个为当前应用，第 2 个为 +2）。",
                    "Slots follow the collapsed Dynamic Island order (e.g. 1st icon is +1, 2nd icon is +2)."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }

        if coordinator.isAccessibilityTrusted {
            Section(L10n.t("权限状态", "Permissions")) {
                HStack {
                    Label(L10n.t("辅助功能权限已就绪", "Accessibility Permission Ready"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button(L10n.t("重新检测", "Recheck")) {
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
            let syms = [
                (L10n.t("访达", "Finder"), "folder.fill"),
                ("Safari", "safari.fill"),
                (L10n.t("备忘录", "Notes"), "note.text"),
                (L10n.t("终端", "Terminal"), "terminal.fill")
            ]
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
                        Text(L10n.t("实时效果预览（点击触发粒子与转向）", "Live Preview (Click to trigger particles & rotate)"))
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
                Text(isRecording ? L10n.t("请按下快捷键…", "Press Shortcut…") : shortcut.displayString)
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
                .help(L10n.t("恢复默认（\(defaultShortcut.displayString)）", "Reset to Default (\(defaultShortcut.displayString))"))
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
            Text(L10n.t("鼠标触发键", "Mouse Trigger Button"))
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? L10n.t("请按下鼠标中键 / 侧键…", "Press Middle or Side Mouse Button…") : coordinator.settings.customMouseTriggerDisplayString)
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
            Text(L10n.t("自定义分屏按键", "Custom Split Button"))
            Spacer()
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? L10n.t("请按修饰键 + 鼠标键…", "Press Modifier + Mouse Button…") : coordinator.settings.splitCustomMouseDisplayString)
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

// MARK: - macOS 26 Style Dynamic Island Appearance & Liquid Glass Controls

private struct IslandThemeCardRow: View {
    let selectedTheme: DynamicIslandTheme
    let onSelect: (DynamicIslandTheme) -> Void

    private let options: [DynamicIslandTheme] = [.appleGlass, .obsidian]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(L10n.t("外观", "Appearance"))
                .padding(.top, 4)

            Spacer()

            HStack(spacing: 14) {
                ForEach(options) { theme in
                    let isSelected = (theme == selectedTheme)
                    Button {
                        onSelect(theme)
                    } label: {
                        VStack(spacing: 5) {
                            themeThumbnail(for: theme)
                                .frame(width: 78, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? Color.accentColor : Color.primary.opacity(0.16),
                                            lineWidth: isSelected ? 2.4 : 0.9
                                        )
                                )
                                .shadow(
                                    color: isSelected ? Color.accentColor.opacity(0.24) : Color.black.opacity(0.08),
                                    radius: isSelected ? 4 : 2,
                                    y: 1
                                )

                            Text(theme.label)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func themeThumbnail(for theme: DynamicIslandTheme) -> some View {
        ZStack(alignment: .top) {
            // Vivid desktop wallpaper backdrop
            LinearGradient(
                colors: theme == .obsidian
                    ? [Color(red: 0.10, green: 0.18, blue: 0.42), Color(red: 0.06, green: 0.09, blue: 0.24)]
                    : [Color(red: 0.24, green: 0.62, blue: 0.96), Color(red: 0.16, green: 0.44, blue: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Sunlit cloud highlight
            Circle()
                .fill(Color.white.opacity(theme == .obsidian ? 0.14 : 0.36))
                .frame(width: 44, height: 44)
                .blur(radius: 10)
                .offset(x: 18, y: 12)

            // Miniature desktop window corner (like System Settings -> Appearance)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme == .obsidian ? Color(white: 0.13) : Color.white.opacity(0.92))
                        .frame(width: 48, height: 22)
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 3) {
                                Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.35)).frame(width: 4, height: 4)
                                Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 4, height: 4)
                                Circle().fill(Color(red: 0.16, green: 0.80, blue: 0.32)).frame(width: 4, height: 4)
                            }
                            .padding(.top, 5)
                            .padding(.leading, 5)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                        .offset(x: 6, y: 4)
                }
            }

            // Miniature top-anchored Dynamic Island pill
            if theme == .appleGlass {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 0
                )
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 0
                    )
                    .fill(Color.white.opacity(0.18))
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 0
                    )
                    .strokeBorder(Color.white.opacity(0.75), lineWidth: 0.7)
                )
                .frame(width: 44, height: 13)
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 0
                )
                .fill(Color.black.opacity(0.94))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 0
                    )
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
                )
                .frame(width: 44, height: 13)
            }
        }
    }
}

private struct LiquidGlassClarityRow: View {
    @ObservedObject var coordinator: StageCoordinator

    private var frostValue: Double {
        coordinator.settings.clampedGlassOpacity
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Liquid Glass")
                Text(L10n.t("透明度 \(Int(round((1.0 - frostValue) * 100)))%", "Clarity \(Int(round((1.0 - frostValue) * 100)))%"))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Spacer()

            VStack(spacing: 8) {
                liquidGlassPreviewCard

                HStack(spacing: 10) {
                    Button {
                        coordinator.updateSettings {
                            $0.glassOpacity = 0.0
                            $0.glassStyle = .clear
                        }
                    } label: {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(frostValue <= 0.15 ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("最清透（类似 Dock 栏）", "Crystal Clear (Like Dock)"))

                    Slider(
                        value: Binding(
                            get: { coordinator.settings.clampedGlassOpacity },
                            set: { val in
                                let clamped = min(1.0, max(0.0, (val * 100).rounded() / 100))
                                coordinator.updateSettings {
                                    $0.glassOpacity = clamped
                                    $0.glassStyle = StageSettings.derivedGlassStyle(forOpacity: clamped)
                                }
                            }
                        ),
                        in: 0.0...1.0,
                        step: 0.01
                    )
                    .labelsHidden()

                    Button {
                        coordinator.updateSettings {
                            $0.glassOpacity = 1.0
                            $0.glassStyle = .frosted
                        }
                    } label: {
                        Image(systemName: "square.2.layers.3d.top.filled")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(frostValue >= 0.85 ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.t("柔和磨砂", "Frosted / Tinted"))
                }

                HStack {
                    Text(L10n.t("清透", "Clear"))
                    Spacer()
                    Text(L10n.t("磨砂", "Tinted"))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
            }
            .frame(maxWidth: 320)
        }
        .padding(.vertical, 4)
    }

    private func previewRimAngularGradient(peak: Double, mid: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(mid), location: 0.00),
                .init(color: Color.white.opacity(peak * 0.92), location: 0.125),
                .init(color: Color.white.opacity(mid), location: 0.25),
                .init(color: Color.white.opacity(peak * 0.72), location: 0.375),
                .init(color: Color.white.opacity(mid * 1.1), location: 0.50),
                .init(color: Color.white.opacity(peak), location: 0.625),
                .init(color: Color.white.opacity(mid), location: 0.75),
                .init(color: Color.white.opacity(peak * 0.78), location: 0.875),
                .init(color: Color.white.opacity(mid), location: 1.00)
            ]),
            center: .center
        )
    }

    private var liquidGlassPreviewCard: some View {
        let layers = StageSettings.glassLayerOpacities(forFrost: frostValue)
        let rim = StageSettings.glassRimMetrics(forFrost: frostValue, isDark: false)
        let bodySheenColors: [Color] = [
            Color.white.opacity(0.14 + layers.tintVeil * 0.48),
            Color.white.opacity(0.05 + layers.tintVeil * 0.28),
            Color.white.opacity(0.11 + layers.tintVeil * 0.36)
        ]
        let demoIcons: [(Color, String)] = [
            (Color(red: 0.18, green: 0.54, blue: 0.96), "safari.fill"),
            (Color(red: 0.24, green: 0.76, blue: 0.42), "message.fill"),
            (Color(red: 0.94, green: 0.44, blue: 0.24), "sparkles"),
            (Color(red: 0.56, green: 0.38, blue: 0.92), "terminal.fill")
        ]

        return ZStack(alignment: .top) {
            // Vivid daytime sky + sharp architectural shapes directly behind the island so sharp vs blurred is obvious
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.48, blue: 0.86),
                    Color(red: 0.34, green: 0.68, blue: 0.94),
                    Color(red: 0.24, green: 0.58, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Crisp architectural ring & window edge behind the pill
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(Color(red: 0.98, green: 0.84, blue: 0.44).opacity(0.85), lineWidth: 5)
                    .frame(width: 44, height: 44)
                    .offset(x: -18, y: -6)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 72, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(red: 0.14, green: 0.46, blue: 0.88).opacity(0.32))
                            .padding(5)
                    )
                    .rotationEffect(.degrees(-10))
                    .offset(x: 16, y: -2)
            }

            // Bottom subtle banner reminiscent of Apple Park card
            VStack {
                Spacer()
                HStack {
                    Text("iRing Dynamic Island")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.82))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial)
            }

            // Live Liquid Glass Dynamic Island pill reacting to slider
            HStack(spacing: 8) {
                ForEach(0..<demoIcons.count, id: \.self) { idx in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(demoIcons[idx].0)
                            .frame(width: 22, height: 22)
                        Image(systemName: demoIcons[idx].1)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                let pillShape = UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 0
                )
                ZStack {
                    if #available(macOS 26.0, *) {
                        if layers.clearBlur > 0.005 {
                            Color.clear
                                .glassEffect(.clear, in: pillShape)
                                .opacity(layers.clearBlur)
                        }
                        if layers.regularBlur > 0.005 {
                            Color.clear
                                .glassEffect(.regular, in: pillShape)
                                .opacity(layers.regularBlur)
                        }
                    } else if layers.clearBlur > 0.005 {
                        pillShape.fill(.ultraThinMaterial)
                            .opacity(layers.clearBlur * 0.65 + layers.regularBlur * 0.35)
                    }
                    pillShape.fill(
                        LinearGradient(
                            colors: bodySheenColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    pillShape.inset(by: 1.2).stroke(
                        previewRimAngularGradient(peak: rim.bevelPeakAlpha, mid: rim.bevelMidAlpha),
                        lineWidth: rim.bevelWidth
                    )
                    .blur(radius: rim.bevelBlur)
                    .clipShape(pillShape)
                    pillShape.inset(by: 0.7).stroke(
                        previewRimAngularGradient(peak: rim.specularPeakAlpha, mid: rim.specularMidAlpha),
                        lineWidth: 1.0
                    )
                    .clipShape(pillShape)
                    pillShape.strokeBorder(Color.black.opacity(rim.outerContactAlpha), lineWidth: 0.55)
                }
            }
        }
        .frame(height: 82)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
    }
}
