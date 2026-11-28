<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/media/hero-zh-dark.svg" />
    <img src="docs/media/hero-zh-light.svg" width="820" alt="iRing for macOS，在光标处切应用、分屏和缩放" />
  </picture>
</p>

<p align="center"><strong>简体中文</strong> · <a href="README.en.md">English</a></p>

<p align="center">
  <a href="https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.dmg"><img src="docs/media/btn-download-zh.svg" alt="下载 macOS Beta（DMG）" /></a><br />
  <a href="https://gitxhui.github.io/iRing/?lang=zh">官网</a> · <a href="#下载与安装">Homebrew</a> · <a href="https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.zip">ZIP</a><br />
  <sub>Beta 2 · macOS 15 或更新版本 · Apple 芯片（arm64）</sub>
</p>

## 下载与安装

- **手动安装**：从[官网](https://gitxhui.github.io/iRing/?lang=zh)下载，或直接下载 [DMG](https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.dmg) / [ZIP](https://github.com/GitxHui/iRing/releases/download/v0.1.0-beta.2/iRing-v0.1.0-beta.2-macOS-arm64.zip)，将 **iRing.app** 拖入「应用程序」。
- **Homebrew**：从项目的 [Tap](https://github.com/GitxHui/homebrew-tap) 安装同一个公测版。

```sh
brew install --cask gitxhui/tap/iring
```

打开 iRing 后，在「系统设置 → 隐私与安全性 → 辅助功能」中启用 iRing。当前 Beta 暂未经过 Apple 公证。如果首次打开受阻，请查看[发布页的安装说明和 SHA-256 校验值](https://github.com/GitxHui/iRing/releases/tag/v0.1.0-beta.2)。

## 怎么用

<p align="center">
  <img src="docs/media/hero-zh.webp" width="820" alt="iRing 圆环切换应用和分屏预览演示" />
</p>

| 功能 | 操作 |
| --- | --- |
| 切应用 | 按住左 **⌥** 或鼠标中键，指向目标应用，松手切换。 |
| 分屏 | 按住 **⌥** 时按 **Tab** 或轻点触控板，也可以用 **⌥ + 鼠标中键**。指向目标布局，预览后松手。 |
| 缩放 | 圆环打开时双指滑动或滚动鼠标滚轮，在 **45%～100%** 之间调整窗口。 |
| Liquid Glass 灵动岛 | 把常用应用停靠在 MacBook 刘海或屏幕边缘。用 **⌥ + Space** 显示或隐藏。 |

[观看 35 秒宣传片](https://gitxhui.github.io/iRing/?lang=zh#film) · [查看分功能演示](https://gitxhui.github.io/iRing/?lang=zh#features)

## 从源码构建

需要 macOS 15+ 和 Swift 6.2+。在仓库根目录运行以下命令。

```sh
swift run AIStageSelfTest
./Scripts/build_app.sh
```

只构建应用包可运行 `SKIP_INSTALL=1 ./Scripts/build_app.sh`。

[更新记录](CHANGELOG.md) · [MIT 协议](LICENSE) · [反馈问题](https://github.com/GitxHui/iRing/issues)
