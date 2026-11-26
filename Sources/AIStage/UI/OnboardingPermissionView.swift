import AIStageCore
import AppKit
import Combine
import SwiftUI

/// Clean first-launch Accessibility permission onboarding window shown when trust is not yet granted.
public struct OnboardingPermissionView: View {
    @ObservedObject var coordinator: StageCoordinator
    let onDismiss: () -> Void

    private let pollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: coordinator.isAccessibilityTrusted ? "checkmark.shield.fill" : "hand.raised.circle.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(coordinator.isAccessibilityTrusted ? Color.green : Color.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text("欢迎使用 iRing")
                        .font(.title2.weight(.semibold))
                    Text("开启辅助功能权限后，即可启用快捷圆环切换、窗口分屏与窗口对齐。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                stepRow(number: "1", text: "点击下方「前往系统设置授权」，打开辅助功能权限页面。")
                stepRow(number: "2", text: "在列表中打开 iRing 开关（若已勾选过，重装后先关再开一次）。")
                stepRow(number: "3", text: "若系统尚未立即识别授权，可点击「已开启？重启生效」。")
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
                Text(coordinator.isAccessibilityTrusted ? "辅助功能权限已就绪，可以开始使用了" : "当前状态：等待辅助功能权限授权…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                if coordinator.isAccessibilityTrusted {
                    Spacer()
                    Button("开始使用") {
                        coordinator.updateSettings { $0.hasCompletedOnboarding = true }
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("稍后再说") {
                        coordinator.updateSettings { $0.hasCompletedOnboarding = true }
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("已开启？重启生效") {
                        coordinator.relaunchSelf()
                    }

                    Button("前往系统设置授权") {
                        coordinator.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(22)
        .frame(width: 440, height: 350)
        .onReceive(pollTimer) { _ in
            coordinator.refreshRuntimeInfo()
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
