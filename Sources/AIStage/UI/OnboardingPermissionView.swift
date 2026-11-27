import AIStageCore
import AppKit
import Combine
import SwiftUI

/// Clean two-step onboarding: (1) Accessibility trust, (2) Initial apps & Trackpad/Mouse preset.
public struct OnboardingPermissionView: View {
    @ObservedObject var coordinator: StageCoordinator
    let onDismiss: () -> Void

    private enum OnboardingStep {
        case permission
        case setupApps
    }

    private enum InputPresetChoice: String, CaseIterable, Identifiable {
        case trackpad
        case mouse
        var id: String { rawValue }
        var label: String {
            switch self {
            case .trackpad: return L10n.t("触控板（左 ⌥ 滑选）", "Trackpad (Left ⌥ + Glide)")
            case .mouse: return L10n.t("鼠标（中键拖动）", "Mouse (Middle-Click Drag)")
            }
        }
    }

    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var step: OnboardingStep = .permission
    @State private var installedApps: [StageAppItem] = []
    @State private var selectedInputPreset: InputPresetChoice = .trackpad

    public var body: some View {
        let _ = coordinator.settings.language
        VStack(alignment: .leading, spacing: 16) {
            if step == .permission {
                permissionStepBody
            } else {
                setupAppsStepBody
            }
        }
        .padding(22)
        .frame(width: 480, height: 420)
        .onAppear {
            if coordinator.isAccessibilityTrusted {
                step = .setupApps
            }
            if installedApps.isEmpty {
                installedApps = coordinator.discovery.scanAllInstalledApps()
            }
            selectedInputPreset = (coordinator.settings.radialKeyboardMode == .modifierHold) ? .trackpad : .mouse
        }
        .onChange(of: coordinator.isAccessibilityTrusted) { _, trusted in
            if trusted && step == .permission {
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .setupApps
                }
            }
        }
        .onReceive(pollTimer) { _ in
            coordinator.refreshRuntimeInfo()
        }
    }

    @ViewBuilder
    private var permissionStepBody: some View {
        HStack(spacing: 14) {
            Image(systemName: coordinator.isAccessibilityTrusted ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(coordinator.isAccessibilityTrusted ? Color.green : Color.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("欢迎使用 iRing", "Welcome to iRing"))
                    .font(.title2.weight(.semibold))
                Text(L10n.t(
                    "第 1/2 步：开启辅助功能权限，以启用快捷圆环切换与窗口分屏。",
                    "Step 1 of 2: Grant Accessibility access for the radial switcher and window tiling."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            stepRow(number: "1", text: L10n.t(
                "点击下方「前往系统设置授权」，打开辅助功能权限页面。",
                "Click \"Open System Settings\" below to open Accessibility permissions."
            ))
            stepRow(number: "2", text: L10n.t(
                "在列表中打开 iRing 开关（若已勾选过，重装后先关再开一次）。",
                "Enable iRing in the list (after reinstalling, toggle it off and on again)."
            ))
            stepRow(number: "3", text: L10n.t(
                "若系统尚未立即识别授权，可点击「已开启？重启生效」。",
                "If macOS doesn't detect it immediately, click \"Granted? Relaunch\"."
            ))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )

        HStack(spacing: 8) {
            Circle()
                .fill(coordinator.isAccessibilityTrusted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(coordinator.isAccessibilityTrusted
                ? L10n.t("辅助功能权限已就绪", "Accessibility permission is ready")
                : L10n.t("当前状态：等待辅助功能权限授权…", "Status: Waiting for Accessibility permission…"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }

        Spacer(minLength: 0)

        HStack(spacing: 10) {
            if coordinator.isAccessibilityTrusted {
                Spacer()
                Button(L10n.t("下一步：选择应用", "Next: Choose Apps")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .setupApps
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button(L10n.t("稍后再说", "Later")) {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.t("已开启？重启生效", "Granted? Relaunch")) {
                    coordinator.relaunchSelf()
                }

                Button(L10n.t("前往系统设置授权", "Open System Settings")) {
                    coordinator.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    @ViewBuilder
    private var setupAppsStepBody: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("挑选常用应用与操控方式", "Pick Apps & Input Mode"))
                    .font(.title3.weight(.semibold))
                Text(L10n.t(
                    "第 2/2 步：导入你想通过灵动岛或快捷圆环切换的应用（之后可随时增删）。",
                    "Step 2 of 2: Pick apps for your Dynamic Island and Radial Ring (editable anytime)."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }

        HStack(spacing: 8) {
            Text(L10n.t("操控方式", "Input"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Picker("", selection: $selectedInputPreset) {
                ForEach(InputPresetChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedInputPreset) { _, choice in
                applyInputPreset(choice)
            }
        }

        HStack {
            Text(L10n.t("已选 \(coordinator.apps.count) 个应用", "\(coordinator.apps.count) apps selected"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.t("一键导入当前运行中的应用", "Import Running Apps")) {
                _ = coordinator.addCurrentlyRunningRegularApps(limit: 6)
            }
            .controlSize(.small)
        }

        List(installedApps.prefix(40)) { item in
            let isAdded = coordinator.apps.contains { $0.bundleIdentifier == item.bundleIdentifier }
            HStack(spacing: 10) {
                Image(nsImage: coordinator.discovery.icon(for: item))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(item.displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button {
                    if isAdded {
                        coordinator.removeApp(bundleID: item.bundleIdentifier)
                    } else {
                        coordinator.addApp(item)
                    }
                } label: {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isAdded ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 1)
        }
        .listStyle(.inset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
        )

        HStack {
            Text(L10n.t(
                "触控板：按住左 ⌥ 滑动切应用 · ⌥ + 双指滑分屏",
                "Trackpad: Hold Left ⌥ & glide to switch · ⌥ + Scroll to split"
            ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(L10n.t("完成并开始使用", "Finish")) {
                applyInputPreset(selectedInputPreset)
                coordinator.updateSettings { $0.hasCompletedOnboarding = true }
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func applyInputPreset(_ choice: InputPresetChoice) {
        coordinator.updateSettings { s in
            switch choice {
            case .trackpad:
                s.radialKeyboardMode = .modifierHold
                s.radialModifierKey = .leftOption
                s.splitKeyboardMode = .disabled
                s.splitMouseTrigger = .disabled
                s.ringScrollResizeEnabled = true
                s.radialTrigger = .middleClickDrag
            case .mouse:
                s.radialTrigger = .middleClickDrag
                s.splitMouseTrigger = .optionMiddle
                s.radialKeyboardMode = .disabled
                s.splitKeyboardMode = .disabled
                s.ringScrollResizeEnabled = true
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
