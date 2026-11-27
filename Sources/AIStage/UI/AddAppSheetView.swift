import AIStageCore
import AppKit
import SwiftUI

public struct AddAppSheetView: View {
    @ObservedObject var coordinator: StageCoordinator
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var allInstalledApps: [StageAppItem] = []

    private var filteredApps: [StageAppItem] {
        let base = allInstalledApps
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return base
        }
        let query = searchText.lowercased()
        return base.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.bundleIdentifier.lowercased().contains(query)
        }
    }

    public var body: some View {
        let _ = coordinator.settings.language
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.t("搜索本机已安装应用…", "Search installed apps…"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

                Button {
                    pickAppManually()
                } label: {
                    Label(L10n.t("浏览…", "Browse…"), systemImage: "folder")
                }
                .controlSize(.regular)
            }
            .padding(14)

            Divider()

            List(filteredApps) { item in
                let isAdded = coordinator.apps.contains { $0.bundleIdentifier == item.bundleIdentifier }
                HStack(spacing: 12) {
                    Image(nsImage: coordinator.discovery.icon(for: item))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Text(item.bundleIdentifier)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isAdded {
                        Button(L10n.t("移除", "Remove")) {
                            coordinator.removeApp(bundleID: item.bundleIdentifier)
                        }
                        .controlSize(.small)
                    } else {
                        Button(L10n.t("添加", "Add")) {
                            coordinator.addApp(item)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Text(L10n.t(
                    "已添加 \(coordinator.apps.count) 个应用 · 挑选你要加入灵动岛与圆环的常用应用",
                    "\(coordinator.apps.count) apps added · Pick apps for your Dynamic Island and Radial Ring"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.t("完成", "Done")) {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onAppear {
            allInstalledApps = coordinator.discovery.scanAllInstalledApps()
        }
    }

    private func pickAppManually() {
        let panel = NSOpenPanel()
        panel.title = L10n.t("选择要添加到 iRing 的应用", "Choose Apps to Add to iRing")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let item = coordinator.discovery.appItem(from: url) {
                    coordinator.addApp(item)
                }
            }
        }
    }
}
