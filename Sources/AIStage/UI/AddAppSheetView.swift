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
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索本机已安装应用…", text: $searchText)
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
                    Label("浏览…", systemImage: "folder")
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
                        Button("移除") {
                            coordinator.removeApp(bundleID: item.bundleIdentifier)
                        }
                        .controlSize(.small)
                    } else {
                        Button("添加") {
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
                Text("已添加 \(coordinator.apps.count) 个应用 · 手动挑选你要叠放或平铺的桌面应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("完成") {
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
        panel.title = "选择要添加到 iRing 的应用"
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
