<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="iRing Icon" />
</p>

<h1 align="center">iRing</h1>

<p align="center">
  极简设计感的 macOS 灵动岛与快捷圆环窗口工作台（内测版）
</p>

<p align="center">
  <a href="https://github.com/E-xhui/iRing/releases">下载最新内测版 (Releases)</a> ·
  <a href="CHANGELOG.md">更新日志</a> ·
  <a href="LICENSE">MIT 协议</a>
</p>

---

## 核心特性

- **极简灵动岛**：贴合 Mac 刘海屏与外接显示器边缘，收起时低调显示当前与应用状态，展开即快速切换与管理工作区应用；支持拖拽至屏幕上下左右边缘或跨屏停靠，也可在设置里自定义宽度、高度、留白边距与图标间距。
- **快捷圆环切换**：按住触发键拖动即可在光标位置呼出圆环切换应用，支持按**添加顺序**或**使用频次**智能排序，可选隐藏未启动应用、同步未读消息红点。
- **8 向分屏环 & `⌘` 滚轮缩放**：支持上下左右半屏、四角四分屏、三分屏等 8 向自适应预览落位；选定方向或应用后按住 `⌘` 即可锁定圆环并以滚轮无级调整窗口大小，松开 `⌘` 立刻生效。
- **双屏无感协作**：多屏场景下自动保护已在另一块屏幕打开的资料窗口，切换主屏应用时不打扰副屏内容。
- **高定制视觉与动效**：支持苹果毛玻璃 / 曜石黑灵动岛、自定义圆环调色盘与颜色深度、闪现 / 卷动出现动画及神奇缩放弹出。

---

## 内测下载与安装（macOS 15.0+ · Apple Silicon）

前往 [**Releases 页面**](https://github.com/E-xhui/iRing/releases) 下载最新的 `iRing-v*-macOS-arm64.dmg`（或 `.zip`）：

1. 打开 `.dmg`，将 **`iRing.app`** 拖入 **`Applications（应用程序）`** 文件夹。
2. 由于内测包暂未经过 Apple 商业公证，首次打开如提示「无法验证开发者 / 已损坏」，在「终端」执行一次清理隔离属性即可：
   ```bash
   xattr -cr /Applications/iRing.app
   ```
3. 随后正常打开 **iRing**，按引导在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选 `iRing` 即可使用全部切窗与分屏能力（如需更真实的窗口弹出动画，可额外开启屏幕录制权限）。

---

## 默认快捷手势

| 操作 | 默认触发方式（均可在设置内自定义） |
| --- | --- |
| 呼出 / 隐藏工作台 | `⌥ + Space` |
| 光标处呼出快捷圆环 | 按住鼠标中键拖动 |
| 触发 8 向分屏环 | `⌥ + 鼠标中键` 或 `⌥ + S`（在圆环内按 `Tab` 亦可切换） |
| 锁定圆环并滚轮缩放窗口 | 圆环内按住 `⌘` 滚动滚轮，松开 `⌘` 提交 |
| 工作台切换到下一块显示器 | `⌃ + ⌥ + →` |

---

## 从源码构建与发版

需要 **macOS 15.0+** 与 **Swift 6.2+** 命令行工具：

```bash
# 1. 运行核心几何与状态机自测
swift run AIStageSelfTest

# 2. 构建 Release 应用包并安装到 /Applications/iRing.app
./Scripts/build_app.sh

# 3. 打包本地分发包 (.dmg + .zip + SHA256SUMS.txt)
./Scripts/release.sh

# 4. 按 VERSION 文件发布 GitHub Release（含自动打 Tag）
./Scripts/release.sh --publish
```

版本维护说明见 [CHANGELOG.md](CHANGELOG.md)。
