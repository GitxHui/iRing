import AppKit
import CoreGraphics
import Foundation

public struct CodableRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public struct CodablePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public enum DockShapeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case dynamicIsland = "dynamic_island"
    case radialOnly = "radial_only"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dynamicIsland: return "灵动岛"
        case .radialOnly: return "仅快捷圆环"
        }
    }

    public var nextShape: DockShapeMode {
        switch self {
        case .dynamicIsland: return .radialOnly
        case .radialOnly: return .dynamicIsland
        }
    }

    public var iconName: String {
        switch self {
        case .dynamicIsland: return "capsule.tophalf.filled"
        case .radialOnly: return "circle.dashed"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "radial_only":
            self = .radialOnly
        default:
            self = .dynamicIsland
        }
    }
}

public enum DynamicIslandTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case obsidian = "obsidian"
    case appleGlass = "apple_glass"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .obsidian: return "曜石黑"
        case .appleGlass: return "通透毛玻璃"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = (raw == "apple_glass") ? .appleGlass : .obsidian
    }
}

public enum RadialAppOrderMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case addedOrder = "added_order"
    case frequentFirst = "frequent_first"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .addedOrder: return "按添加顺序"
        case .frequentFirst: return "按使用频次"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = (raw == "frequent_first") ? .frequentFirst : .addedOrder
    }
}

public enum AppleGlassStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear = "clear"
    case regular = "regular"
    case frosted = "frosted"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .clear: return "清透"
        case .regular: return "标准"
        case .frosted: return "柔和磨砂"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "regular": self = .regular
        case "frosted": self = .frosted
        default: self = .clear
        }
    }
}

public enum RadialTriggerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case middleClickDrag = "middle_click_drag"
    case optionMiddleClick = "option_middle_click"
    case optionRightDrag = "option_right_drag"
    case customMouse = "custom_mouse"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .middleClickDrag: return "鼠标中键按住拖动"
        case .optionMiddleClick: return "⌥ + 鼠标中键拖动"
        case .optionRightDrag: return "⌥ + 鼠标右键拖动（触控板推荐）"
        case .customMouse: return "自定义鼠标按键（支持侧键）"
        case .disabled: return "关闭"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "option_middle_click": self = .optionMiddleClick
        case "option_right_drag": self = .optionRightDrag
        case "custom_mouse": self = .customMouse
        case "disabled": self = .disabled
        default: self = .middleClickDrag
        }
    }
}

public enum RadialKeyboardTriggerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case disabled = "disabled"
    case keyCombo = "key_combo"
    case modifierHold = "modifier_hold"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .disabled: return "关闭"
        case .keyCombo: return "自定义快捷键"
        case .modifierHold: return "长按单个修饰键（触控板推荐）"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "key_combo": self = .keyCombo
        case "modifier_hold": self = .modifierHold
        default: self = .disabled
        }
    }
}

public enum RadialModifierKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case rightOption = "right_option"
    case rightCommand = "right_command"
    case fnKey = "fn_key"
    case controlOption = "control_option"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .rightOption: return "右 ⌥ (Right Option)"
        case .rightCommand: return "右 ⌘ (Right Command)"
        case .fnKey: return "Fn / 🌐 键"
        case .controlOption: return "⌃ + ⌥ 组合修饰键"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "right_command": self = .rightCommand
        case "fn_key": self = .fnKey
        case "control_option": self = .controlOption
        default: self = .rightOption
        }
    }
}

public struct CustomKeyCombo: Codable, Equatable, Hashable, Sendable {
    public static let modControl: UInt32 = 1 << 0
    public static let modOption: UInt32 = 1 << 1
    public static let modShift: UInt32 = 1 << 2
    public static let modCommand: UInt32 = 1 << 3

    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let optionSpace = CustomKeyCombo(keyCode: 49, modifiers: modOption)
    public static let optionA = CustomKeyCombo(keyCode: 0, modifiers: modOption)
    public static let controlOptionSpace = CustomKeyCombo(keyCode: 49, modifiers: modControl | modOption)
    public static let controlOptionRight = CustomKeyCombo(keyCode: 124, modifiers: modControl | modOption)
    public static let optionQ = CustomKeyCombo(keyCode: 12, modifiers: modOption)
    public static let optionS = CustomKeyCombo(keyCode: 1, modifiers: modOption)

    public var isValidShortcut: Bool {
        modifiers != 0 || Self.isFunctionKey(keyCode)
    }

    public var displayString: String {
        Self.modifiersDisplayString(modifiers) + Self.keyDisplayName(for: keyCode)
    }

    public static func modifiersDisplayString(_ modifiers: UInt32) -> String {
        var s = ""
        if (modifiers & modControl) != 0 { s += "⌃" }
        if (modifiers & modOption) != 0 { s += "⌥" }
        if (modifiers & modShift) != 0 { s += "⇧" }
        if (modifiers & modCommand) != 0 { s += "⌘" }
        return s
    }

    public static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80].contains(keyCode)
    }

    public static func keyDisplayName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return " Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key(\(keyCode))"
        }
    }
}

/// Where the Loop-style radial switcher or Split Ring places the window (previewed live before release).
public enum RadialLayoutTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case stage = "stage"
    case leftHalf = "left_half"
    case rightHalf = "right_half"
    case topHalf = "top_half"
    case bottomHalf = "bottom_half"
    case topLeftQuarter = "top_left_quarter"
    case topRightQuarter = "top_right_quarter"
    case bottomLeftQuarter = "bottom_left_quarter"
    case bottomRightQuarter = "bottom_right_quarter"
    case leftThird = "left_third"
    case centerThird = "center_third"
    case rightThird = "right_third"
    case leftTwoThirds = "left_two_thirds"
    case rightTwoThirds = "right_two_thirds"
    case maximize = "maximize"
    case center = "center"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .stage: return "舞台位置"
        case .leftHalf: return "左半屏 1/2"
        case .rightHalf: return "右半屏 1/2"
        case .topHalf: return "上半屏"
        case .bottomHalf: return "下半屏"
        case .topLeftQuarter: return "左上角 1/4"
        case .topRightQuarter: return "右上角 1/4"
        case .bottomLeftQuarter: return "左下角 1/4"
        case .bottomRightQuarter: return "右下角 1/4"
        case .leftThird: return "左三分之一"
        case .centerThird: return "中三分之一"
        case .rightThird: return "右三分之一"
        case .leftTwoThirds: return "左三分之二"
        case .rightTwoThirds: return "右三分之二"
        case .maximize: return "全屏最大化"
        case .center: return "居中"
        }
    }

    public var shortLabel: String {
        switch self {
        case .stage: return "舞台"
        case .leftHalf: return "左 1/2"
        case .rightHalf: return "右 1/2"
        case .topHalf: return "上 1/2"
        case .bottomHalf: return "下 1/2"
        case .topLeftQuarter: return "↖ 1/4"
        case .topRightQuarter: return "↗ 1/4"
        case .bottomLeftQuarter: return "↙ 1/4"
        case .bottomRightQuarter: return "↘ 1/4"
        case .leftThird: return "左 1/3"
        case .centerThird: return "中 1/3"
        case .rightThird: return "右 1/3"
        case .leftTwoThirds: return "左 2/3"
        case .rightTwoThirds: return "右 2/3"
        case .maximize: return "最大"
        case .center: return "居中"
        }
    }

    public var isSplitLayout: Bool {
        switch self {
        case .stage, .maximize, .center:
            return false
        default:
            return true
        }
    }

    public var symbolName: String {
        switch self {
        case .stage: return "rectangle.inset.filled"
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.split.3x1"
        case .rightThird: return "rectangle.split.3x1"
        case .leftTwoThirds: return "rectangle.leftthird.inset.filled"
        case .rightTwoThirds: return "rectangle.rightthird.inset.filled"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .center: return "rectangle.center.inset.filled"
        }
    }

    public func advanced(by step: Int) -> RadialLayoutTarget {
        let all = RadialLayoutTarget.allCases
        guard let idx = all.firstIndex(of: self) else { return self }
        let next = ((idx + step) % all.count + all.count) % all.count
        return all[next]
    }

    /// Loop-style scroll cycling along the active direction's size family (1/2 <-> 1/3 <-> 2/3, etc.).
    public func cycledVariant(step: Int) -> RadialLayoutTarget {
        let cycleGroup: [RadialLayoutTarget]
        switch self {
        case .leftHalf, .leftThird, .leftTwoThirds:
            cycleGroup = [.leftHalf, .leftThird, .leftTwoThirds]
        case .rightHalf, .rightThird, .rightTwoThirds:
            cycleGroup = [.rightHalf, .rightThird, .rightTwoThirds]
        case .topHalf, .maximize:
            cycleGroup = [.topHalf, .maximize]
        case .bottomHalf, .center, .centerThird:
            cycleGroup = [.bottomHalf, .centerThird, .center]
        default:
            return self
        }
        guard let idx = cycleGroup.firstIndex(of: self) else { return self }
        let next = ((idx + step) % cycleGroup.count + cycleGroup.count) % cycleGroup.count
        return cycleGroup[next]
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RadialLayoutTarget(rawValue: raw) ?? .stage
    }
}

public enum DockEdgePosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case top = "top"
    case bottom = "bottom"
    case left = "left"
    case right = "right"

    public var id: String { rawValue }

    public var isVertical: Bool {
        self == .left || self == .right
    }

    public var label: String {
        switch self {
        case .top: return "屏幕顶部（刘海）"
        case .bottom: return "屏幕底端"
        case .left: return "屏幕左端"
        case .right: return "屏幕右端"
        }
    }
}

public enum IslandExpandAxis: String, Codable, CaseIterable, Identifiable, Sendable {
    case alongEdge = "along_edge"
    case perpendicular = "perpendicular"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .alongEdge: return "沿边缘展开"
        case .perpendicular: return "垂直弹出"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = (raw == "perpendicular") ? .perpendicular : .alongEdge
    }
}

public enum StageLayoutMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case monocleStack = "monocle_stack"
    case split2 = "split_2"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .monocleStack: return "同框叠放（零晃动）"
        case .split2: return "双屏对比"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "split_2":
            self = .split2
        default:
            self = .monocleStack
        }
    }
}

public enum ToggleHotkeyPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionSpace = "option_space"
    case optionA = "option_a"
    case controlOptionSpace = "control_option_space"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .optionSpace: return "⌥ Space"
        case .optionA: return "⌥ A"
        case .controlOptionSpace: return "⌃⌥ Space"
        }
    }

    public var keyCombo: CustomKeyCombo {
        switch self {
        case .optionSpace: return .optionSpace
        case .optionA: return .optionA
        case .controlOptionSpace: return .controlOptionSpace
        }
    }
}

public enum NumberSwitchModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case option = "option"
    case command = "command"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .option: return "⌥ 1~9"
        case .command: return "⌘ 1~9（推荐，按排序切换）"
        case .disabled: return "关闭数字快捷键"
        }
    }

    public var symbolPrefix: String? {
        switch self {
        case .option: return "⌥"
        case .command: return "⌘"
        case .disabled: return nil
        }
    }
}

public enum IndicatorStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case dot = "dot"
    case pill = "pill"
    case hidden = "hidden"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dot: return "经典圆点（macOS 拓展坞）"
        case .pill: return "液态光条"
        case .hidden: return "隐藏状态点"
        }
    }
}

public enum IndicatorColorPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic = "classic"
    case emerald = "emerald"
    case accent = "accent"
    case skyBlue = "sky_blue"
    case amber = "amber"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .classic: return "原生拓展坞白/灰（自适应明暗）"
        case .emerald: return "翡翠绿"
        case .accent: return "跟随系统强调色"
        case .skyBlue: return "天青蓝"
        case .amber: return "琥珀暖橙"
        }
    }
}

public enum LoopRadialStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case classicTahoe = "classic_tahoe"
    case squircle = "squircle"
    case appleGlow = "apple_glow"
    case solidDial = "solid_dial"
    case minimalHalo = "minimal_halo"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .classicTahoe: return "经典圆环"
        case .squircle: return "圆角方环"
        case .appleGlow: return "流体极光"
        case .solidDial: return "饱满表盘"
        case .minimalHalo: return "极简光环"
        }
    }

    public var symbolName: String {
        switch self {
        case .classicTahoe: return "circle.circle"
        case .squircle: return "app"
        case .appleGlow: return "sparkles"
        case .solidDial: return "circle.fill"
        case .minimalHalo: return "circle"
        }
    }

    public var defaultThickness: Double {
        switch self {
        case .classicTahoe: return 32
        case .squircle: return 30
        case .appleGlow: return 30
        case .solidDial: return 48
        case .minimalHalo: return 12
        }
    }

    public var defaultCornerRatio: Double {
        switch self {
        case .squircle: return 0.52
        case .classicTahoe, .appleGlow, .solidDial, .minimalHalo: return 1.0
        }
    }

    public var usesRingGeometry: Bool {
        self != .solidDial
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "squircle": self = .squircle
        case "apple_glow", "aurora": self = .appleGlow
        case "solid_dial": self = .solidDial
        case "minimal_halo", "icon_orbit": self = .minimalHalo
        default: self = .classicTahoe
        }
    }
}

public enum LoopAccentTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case ocean = "ocean"
    case system = "system"
    case appleGlass = "apple_glass"
    case emerald = "emerald"
    case sunset = "sunset"
    case nebula = "nebula"
    case monochrome = "monochrome"
    case custom = "custom"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .ocean: return "海洋蓝"
        case .system: return "跟随系统"
        case .appleGlass: return "通透毛玻璃"
        case .emerald: return "翡翠青"
        case .sunset: return "日落霓虹"
        case .nebula: return "星云紫"
        case .monochrome: return "极简黑白"
        case .custom: return "自定义调色盘"
        }
    }
}

/// Configurable mouse/trackpad gesture for entering the 8-direction Split Ring.
public enum SplitMouseTriggerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionMiddle = "option_middle"
    case optionScroll = "option_scroll"
    case optionRight = "option_right"
    case customMouse = "custom_mouse"
    case disabled = "disabled"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .optionMiddle: return "⌥ + 鼠标中键"
        case .optionScroll: return "⌥ + 滚轮（触控板推荐）"
        case .optionRight: return "⌥ + 鼠标右键"
        case .customMouse: return "自定义鼠标按键"
        case .disabled: return "关闭"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SplitMouseTriggerMode(rawValue: raw) ?? .optionMiddle
    }
}

/// Modifier key held while scrolling on an open radial ring to resize the target window frame.
public enum RingResizeModifier: String, Codable, CaseIterable, Identifiable, Sendable {
    case command = "command"
    case option = "option"
    case control = "control"
    case shift = "shift"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .command: return "⌘ Command"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift: return "⇧ Shift"
        }
    }

    public func matches(_ flags: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .command: return flags.contains(.command)
        case .option: return flags.contains(.option)
        case .control: return flags.contains(.control)
        case .shift: return flags.contains(.shift)
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = RingResizeModifier(rawValue: raw) ?? .command
    }
}

public enum AnimationSpeedPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case instant = "instant"
    case fast = "fast"
    case smooth = "smooth"
    case relaxed = "relaxed"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .instant: return "即时"
        case .fast: return "灵敏"
        case .smooth: return "流畅"
        case .relaxed: return "优雅"
        }
    }

    public var label: String {
        switch self {
        case .instant: return "即时（无动画）"
        case .fast: return "灵敏（推荐）"
        case .smooth: return "流畅"
        case .relaxed: return "优雅舒缓"
        }
    }

    public var sliderIndex: Double {
        switch self {
        case .instant: return 0
        case .fast: return 1
        case .smooth: return 2
        case .relaxed: return 3
        }
    }

    public static func from(sliderIndex: Double) -> AnimationSpeedPreset {
        let clamped = min(3, max(0, Int(round(sliderIndex))))
        return allCases[clamped]
    }

    public var isInstant: Bool { self == .instant }

    public var dockFrameDuration: Double {
        switch self {
        case .instant: return 0.0
        case .fast: return 0.17
        case .smooth: return 0.24
        case .relaxed: return 0.34
        }
    }

    public var ringSpringResponse: Double {
        switch self {
        case .instant: return 0.0
        case .fast: return 0.20
        case .smooth: return 0.28
        case .relaxed: return 0.40
        }
    }

    public var previewFrameDuration: Double {
        switch self {
        case .instant: return 0.0
        case .fast: return 0.15
        case .smooth: return 0.22
        case .relaxed: return 0.32
        }
    }

    public var fadeOutDuration: Double {
        switch self {
        case .instant: return 0.0
        case .fast: return 0.10
        case .smooth: return 0.14
        case .relaxed: return 0.22
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "instant": self = .instant
        case "smooth": self = .smooth
        case "relaxed": self = .relaxed
        default: self = .fast
        }
    }
}

/// What the scroll wheel / trackpad scroll does over the island.
public enum ScrollWheelBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Scroll browses the icon tray; hold ⌥ while scrolling to switch apps.
    case browse = "browse"
    /// Scroll switches apps; hold ⌥ while scrolling to browse the tray.
    case switchApps = "switch_apps"
    /// Scroll only ever browses the tray.
    case browseOnly = "browse_only"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .browse: return "浏览图标"
        case .switchApps: return "切换应用"
        case .browseOnly: return "仅浏览"
        }
    }

    public var detail: String {
        switch self {
        case .browse: return "滚动浏览灵动岛里的 App，按住 ⌥ 再滚动才切换应用。"
        case .switchApps: return "滚动直接切换应用，按住 ⌥ 再滚动浏览图标。"
        case .browseOnly: return "滚动只浏览图标，永远不会切换应用。"
        }
    }

    /// Whether this scroll event should switch apps rather than browse.
    public func switchesApp(optionHeld: Bool) -> Bool {
        switch self {
        case .browse: return optionHeld
        case .switchApps: return !optionHeld
        case .browseOnly: return false
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ScrollWheelBehavior(rawValue: raw) ?? .browse
    }
}

/// How the Loop radial ring appears, modeled on macOS window effects.
public enum AppearAnimationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Rolls in with 3D perspective, like a window curling into place (default).
    case roll = "roll"
    /// Quick fade with minimal geometric motion.
    case flash = "flash"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .roll: return "卷动"
        case .flash: return "闪现"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AppearAnimationStyle(rawValue: raw) ?? .roll
    }
}

/// How switching to an app that is already open on another screen behaves.
public enum MultiScreenAppPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case smartKeepOtherScreen = "smart_keep_other_screen"
    case followDockScreen = "follow_dock_screen"
    case keepOriginalScreen = "keep_original_screen"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .smartKeepOtherScreen: return "智能保留副屏位置（推荐）"
        case .followDockScreen: return "始终拉回灵动岛所在屏"
        case .keepOriginalScreen: return "保留各应用原位（仅聚焦）"
        }
    }

    public var detail: String {
        switch self {
        case .smartKeepOtherScreen:
            return "已在其他显示器上的应用切换时保留其位置和分屏，仅聚焦不强拽；⌥+点击或一键归位可拉回当前屏。"
        case .followDockScreen:
            return "切换任意应用时都统一对齐到灵动岛所在的舞台屏幕。"
        case .keepOriginalScreen:
            return "普通切换只激活窗口不改动尺寸位置；仅在分屏、圆环落点或一键归位时调整窗口。"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MultiScreenAppPolicy(rawValue: raw) ?? .smartKeepOtherScreen
    }
}

/// Visual particle effect style rendered around the Loop radial switcher.
public enum LoopParticleStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case off = "off"
    case sparkBurst = "spark_burst"
    case orbitalDust = "orbital_dust"
    case auroraRibbon = "aurora_ribbon"
    case liquidRipple = "liquid_ripple"
    case starlightConfetti = "starlight_confetti"
    case vortexMagic = "vortex_magic"
    case vortexFireworks = "vortex_fireworks"
    case vortexSpark = "vortex_spark"

    public var id: String { rawValue }

    public var isVortexStyle: Bool {
        switch self {
        case .vortexMagic, .vortexFireworks, .vortexSpark:
            return true
        default:
            return false
        }
    }

    public var label: String {
        switch self {
        case .off: return "关闭"
        case .sparkBurst: return "霓虹星爆"
        case .orbitalDust: return "液态星尘"
        case .auroraRibbon: return "极光光带"
        case .liquidRipple: return "液态水波"
        case .starlightConfetti: return "璀璨星芒"
        case .vortexMagic: return "魔法星环"
        case .vortexFireworks: return "璀璨烟花"
        case .vortexSpark: return "流星火花"
        }
    }

    public var symbolName: String {
        switch self {
        case .off: return "circle.slash"
        case .sparkBurst: return "sparkles"
        case .orbitalDust: return "atom"
        case .auroraRibbon: return "wind"
        case .liquidRipple: return "drop.circle"
        case .starlightConfetti: return "star.fill"
        case .vortexMagic: return "wand.and.sparkles"
        case .vortexFireworks: return "fireworks"
        case .vortexSpark: return "flame.fill"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LoopParticleStyle(rawValue: raw) ?? .sparkBurst
    }
}

/// GPU-accelerated window pop-out animation style rendered via cached ScreenCaptureKit snapshots.
public enum WindowPopAnimationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case off = "off"
    case genie = "genie"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .off: return "关闭"
        case .genie: return "神奇缩放"
        }
    }

    public var duration: Double {
        switch self {
        case .off: return 0.0
        case .genie: return 0.42
        }
    }

    public func effectiveDuration(speed: AnimationSpeedPreset) -> Double {
        guard self != .off else { return 0.0 }
        switch speed {
        case .instant: return 0.0
        case .fast: return duration * 0.92
        case .smooth: return duration * 1.12
        case .relaxed: return duration * 1.38
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = (raw == "off") ? .off : .genie
    }
}

public struct StageSettings: Codable, Equatable, Sendable {
    public var dockShape: DockShapeMode = .dynamicIsland
    public var dockPosition: DockEdgePosition = .bottom
    public var dockWidth: Double = 64
    public var customDockHeight: Double? = nil
    public var horizontalDockHeight: Double = 64
    public var customHorizontalDockWidth: Double? = nil
    public var circularDockDiameter: Double = 196
    public var iconSize: Double = 44
    public var magnificationScale: Double = 1.42
    public var iconSpacing: Double = 6
    public var dockGap: Double = 10
    public var outerMargin: Double = 8
    public var splitGap: Double = 8
    public var matchWindowHeight: Bool = false
    public var autoHideDock: Bool = false
    public var animateOpeningApps: Bool = true
    public var autoScaleIndicator: Bool = true
    public var dynamicIslandPinned: Bool = false
    public var dynamicIslandTheme: DynamicIslandTheme = .obsidian
    public var islandPosition: DockEdgePosition = .top
    public var islandExpandAxis: IslandExpandAxis = .alongEdge
    public var islandCustomWidth: Double = 0
    public var islandCustomHeight: Double = 0
    public var islandContentPadding: Double = 18
    public var glassStyle: AppleGlassStyle = .clear
    public var glassOpacity: Double = 0.18
    public var glassSpecularIntensity: Double = 0.65
    public var hasCompletedOnboarding: Bool = false
    public var followActiveScreen: Bool = false
    public var radialTrigger: RadialTriggerMode = .middleClickDrag
    public var radialRingDiameter: Double = 300
    public var radialIconSize: Double = 46
    public var radialStyle: LoopRadialStyle = .classicTahoe
    public var radialTheme: LoopAccentTheme = .ocean
    public var customRingColorHex: String = "#0071EC"
    public var ringColorDepth: Double = 0.85
    public var radialThickness: Double = 32
    public var radialCornerRatio: Double = 1.0
    public var radialParticleEffects: Bool = true
    public var radialParticleStyle: LoopParticleStyle = .sparkBurst
    public var previewBorderThickness: Double = 5.5
    public var previewCornerRadius: Double = 16

    public var hideInactiveStagedApps: Bool = false
    public var smartZOrder: Bool = true
    public var launchAtLogin: Bool = false
    public var hideMenuBarIcon: Bool = false
    public var animationSpeed: AnimationSpeedPreset = .fast
    public var appearAnimationStyle: AppearAnimationStyle = .roll
    public var windowPopAnimationStyle: WindowPopAnimationStyle = .genie
    public var smoothWindowTransitions: Bool = true
    public var includePadding: Bool = true
    public var showRadialPreview: Bool = true
    public var radialHapticsEnabled: Bool = true
    public var useScreenWithCursor: Bool = true
    public var moveCursorWithWindow: Bool = false
    public var multiScreenAppPolicy: MultiScreenAppPolicy = .smartKeepOtherScreen

    public var toggleHotkey: ToggleHotkeyPreset = .optionSpace
    public var customToggleShortcut: CustomKeyCombo? = nil
    public var customMoveScreenShortcut: CustomKeyCombo? = nil
    public var radialKeyboardMode: RadialKeyboardTriggerMode = .disabled
    public var radialKeyboardShortcut: CustomKeyCombo = .optionQ
    public var splitRingHotkeyEnabled: Bool = true
    public var splitRingShortcut: CustomKeyCombo? = .optionS
    public var radialModifierKey: RadialModifierKey = .rightOption
    public var radialCustomMouseButton: Int = 3
    public var radialCustomMouseModifiers: UInt32 = 0
    public var splitMouseTrigger: SplitMouseTriggerMode = .optionMiddle
    public var splitCustomMouseButton: Int = 2
    public var splitCustomMouseModifiers: UInt32 = CustomKeyCombo.modOption
    public var ringResizeModifier: RingResizeModifier = .command
    public var numberSwitchModifier: NumberSwitchModifier = .command
    /// Legacy flag, kept so older configs still decode. Superseded by `scrollWheelBehavior`.
    public var scrollWheelSwitchesApp: Bool = false
    public var scrollWheelBehavior: ScrollWheelBehavior = .browse

    public var sortRunningAppsFirst: Bool = true
    public var radialAppOrderMode: RadialAppOrderMode = .addedOrder
    public var showInactiveAppsInRing: Bool = true
    public var indicatorStyle: IndicatorStyle = .dot
    public var indicatorColor: IndicatorColorPreset = .classic
    public var indicatorSize: Double = 4.5
    public var showInactiveIndicator: Bool = false
    public var showNotificationBadges: Bool = true

    public var effectiveDockThickness: Double {
        min(104, max(46, round(iconSize + max(18, iconSize * 0.42))))
    }

    public var effectiveOuterMargin: Double {
        includePadding ? max(0, outerMargin) : 0
    }

    public var effectiveParticleStyle: LoopParticleStyle {
        radialParticleStyle
    }

    public var effectiveToggleShortcut: CustomKeyCombo {
        customToggleShortcut ?? toggleHotkey.keyCombo
    }

    public var effectiveMoveScreenShortcut: CustomKeyCombo {
        customMoveScreenShortcut ?? .controlOptionRight
    }

    public var activeRadialKeyboardShortcut: CustomKeyCombo? {
        radialKeyboardMode == .keyCombo ? radialKeyboardShortcut : nil
    }

    public var effectiveSplitRingShortcut: CustomKeyCombo {
        splitRingShortcut ?? .optionS
    }

    public var activeSplitRingShortcut: CustomKeyCombo? {
        splitRingHotkeyEnabled ? effectiveSplitRingShortcut : nil
    }

    public var customMouseTriggerDisplayString: String {
        let modPrefix = CustomKeyCombo.modifiersDisplayString(radialCustomMouseModifiers)
        let btnName: String
        switch radialCustomMouseButton {
        case 1: btnName = "鼠标右键"
        case 2: btnName = "鼠标中键"
        default: btnName = "鼠标侧键 \(radialCustomMouseButton + 1)"
        }
        return modPrefix.isEmpty ? btnName : "\(modPrefix) + \(btnName)"
    }

    public var splitCustomMouseDisplayString: String {
        let modPrefix = CustomKeyCombo.modifiersDisplayString(splitCustomMouseModifiers)
        let btnName: String
        switch splitCustomMouseButton {
        case 1: btnName = "鼠标右键"
        case 2: btnName = "鼠标中键"
        default: btnName = "鼠标侧键 \(splitCustomMouseButton + 1)"
        }
        return modPrefix.isEmpty ? btnName : "\(modPrefix) + \(btnName)"
    }

    public var isExpandedIslandVertical: Bool {
        switch islandExpandAxis {
        case .alongEdge: return islandPosition.isVertical
        case .perpendicular: return !islandPosition.isVertical
        }
    }

    public var effectiveIndicatorSize: Double {
        if autoScaleIndicator {
            return min(5.8, max(3.2, (iconSize * 0.105 * 2.0).rounded() / 2.0))
        }
        return indicatorSize
    }

    public static func magnificationFactor(distance: CGFloat, iconSize: CGFloat, maxScale: CGFloat) -> CGFloat {
        guard maxScale > 1.01 else { return 1.0 }
        let radius = max(iconSize * 2.35, 96)
        guard distance < radius else { return 1.0 }
        let wave = 0.5 * (1.0 + cos((distance / radius) * .pi))
        return 1.0 + (maxScale - 1.0) * wave
    }

    public static func orderedRadialApps(
        apps: [StageAppItem],
        runningBundleIDs: Set<String>,
        usageCounts: [String: Int],
        lastUsedTimestamps: [String: Double],
        orderMode: RadialAppOrderMode,
        sortRunningFirst: Bool,
        showInactiveApps: Bool
    ) -> [StageAppItem] {
        let indexed = Array(apps.enumerated())
        let pool: [(offset: Int, element: StageAppItem)]
        if showInactiveApps {
            pool = indexed
        } else {
            let runningPool = indexed.filter { runningBundleIDs.contains($0.element.bundleIdentifier) }
            pool = runningPool.isEmpty ? indexed : runningPool
        }

        switch orderMode {
        case .addedOrder:
            guard sortRunningFirst else { return pool.map(\.element) }
            let running = pool.filter { runningBundleIDs.contains($0.element.bundleIdentifier) }
            let inactive = pool.filter { !runningBundleIDs.contains($0.element.bundleIdentifier) }
            return (running + inactive).map(\.element)

        case .frequentFirst:
            return pool.sorted { lhs, rhs in
                let lid = lhs.element.bundleIdentifier
                let rid = rhs.element.bundleIdentifier
                let lCount = usageCounts[lid] ?? 0
                let rCount = usageCounts[rid] ?? 0
                if lCount != rCount { return lCount > rCount }

                let lTime = lastUsedTimestamps[lid] ?? 0
                let rTime = lastUsedTimestamps[rid] ?? 0
                if lTime != rTime { return lTime > rTime }

                let lRun = runningBundleIDs.contains(lid)
                let rRun = runningBundleIDs.contains(rid)
                if lRun != rRun { return lRun }

                return lhs.offset < rhs.offset
            }.map(\.element)
        }
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dockShape = try c.decodeIfPresent(DockShapeMode.self, forKey: .dockShape) ?? .dynamicIsland
        self.dockPosition = try c.decodeIfPresent(DockEdgePosition.self, forKey: .dockPosition) ?? .bottom
        self.iconSize = try c.decodeIfPresent(Double.self, forKey: .iconSize) ?? 44
        self.dockWidth = try c.decodeIfPresent(Double.self, forKey: .dockWidth) ?? 64
        self.customDockHeight = try c.decodeIfPresent(Double.self, forKey: .customDockHeight)
        self.horizontalDockHeight = try c.decodeIfPresent(Double.self, forKey: .horizontalDockHeight) ?? 64
        self.customHorizontalDockWidth = try c.decodeIfPresent(Double.self, forKey: .customHorizontalDockWidth)
        self.circularDockDiameter = try c.decodeIfPresent(Double.self, forKey: .circularDockDiameter) ?? 196
        self.magnificationScale = try c.decodeIfPresent(Double.self, forKey: .magnificationScale) ?? 1.42
        self.iconSpacing = try c.decodeIfPresent(Double.self, forKey: .iconSpacing) ?? 6
        self.dockGap = try c.decodeIfPresent(Double.self, forKey: .dockGap) ?? 10
        self.outerMargin = try c.decodeIfPresent(Double.self, forKey: .outerMargin) ?? 8
        self.splitGap = try c.decodeIfPresent(Double.self, forKey: .splitGap) ?? 8
        self.matchWindowHeight = try c.decodeIfPresent(Bool.self, forKey: .matchWindowHeight) ?? false
        self.autoHideDock = try c.decodeIfPresent(Bool.self, forKey: .autoHideDock) ?? false
        self.animateOpeningApps = try c.decodeIfPresent(Bool.self, forKey: .animateOpeningApps) ?? true
        self.autoScaleIndicator = try c.decodeIfPresent(Bool.self, forKey: .autoScaleIndicator) ?? true
        self.dynamicIslandPinned = try c.decodeIfPresent(Bool.self, forKey: .dynamicIslandPinned) ?? false
        self.dynamicIslandTheme = try c.decodeIfPresent(DynamicIslandTheme.self, forKey: .dynamicIslandTheme) ?? .obsidian
        self.islandPosition = try c.decodeIfPresent(DockEdgePosition.self, forKey: .islandPosition) ?? .top
        self.islandExpandAxis = try c.decodeIfPresent(IslandExpandAxis.self, forKey: .islandExpandAxis) ?? .alongEdge
        self.islandCustomWidth = try c.decodeIfPresent(Double.self, forKey: .islandCustomWidth) ?? 0
        self.islandCustomHeight = try c.decodeIfPresent(Double.self, forKey: .islandCustomHeight) ?? 0
        self.islandContentPadding = try c.decodeIfPresent(Double.self, forKey: .islandContentPadding) ?? 18
        self.glassStyle = try c.decodeIfPresent(AppleGlassStyle.self, forKey: .glassStyle) ?? .clear
        self.glassOpacity = try c.decodeIfPresent(Double.self, forKey: .glassOpacity) ?? 0.18
        self.glassSpecularIntensity = try c.decodeIfPresent(Double.self, forKey: .glassSpecularIntensity) ?? 0.65
        self.hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        self.followActiveScreen = try c.decodeIfPresent(Bool.self, forKey: .followActiveScreen) ?? false
        self.radialTrigger = try c.decodeIfPresent(RadialTriggerMode.self, forKey: .radialTrigger) ?? .middleClickDrag
        self.radialRingDiameter = try c.decodeIfPresent(Double.self, forKey: .radialRingDiameter) ?? 300
        self.radialIconSize = try c.decodeIfPresent(Double.self, forKey: .radialIconSize) ?? 46
        self.radialStyle = try c.decodeIfPresent(LoopRadialStyle.self, forKey: .radialStyle) ?? .classicTahoe
        self.radialTheme = try c.decodeIfPresent(LoopAccentTheme.self, forKey: .radialTheme) ?? .ocean
        self.customRingColorHex = try c.decodeIfPresent(String.self, forKey: .customRingColorHex) ?? "#0071EC"
        self.ringColorDepth = try c.decodeIfPresent(Double.self, forKey: .ringColorDepth) ?? 0.85
        self.radialThickness = try c.decodeIfPresent(Double.self, forKey: .radialThickness) ?? 32
        self.radialCornerRatio = try c.decodeIfPresent(Double.self, forKey: .radialCornerRatio) ?? 1.0
        let legacyParticleEffects = try c.decodeIfPresent(Bool.self, forKey: .radialParticleEffects) ?? true
        self.radialParticleEffects = legacyParticleEffects
        self.radialParticleStyle = try c.decodeIfPresent(LoopParticleStyle.self, forKey: .radialParticleStyle)
            ?? (legacyParticleEffects ? .sparkBurst : .off)
        self.previewBorderThickness = try c.decodeIfPresent(Double.self, forKey: .previewBorderThickness) ?? 5.5
        self.previewCornerRadius = try c.decodeIfPresent(Double.self, forKey: .previewCornerRadius) ?? 16
        self.hideInactiveStagedApps = try c.decodeIfPresent(Bool.self, forKey: .hideInactiveStagedApps) ?? false
        self.smartZOrder = try c.decodeIfPresent(Bool.self, forKey: .smartZOrder) ?? true
        self.launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.hideMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .hideMenuBarIcon) ?? false
        self.animationSpeed = try c.decodeIfPresent(AnimationSpeedPreset.self, forKey: .animationSpeed) ?? .fast
        self.appearAnimationStyle = try c.decodeIfPresent(AppearAnimationStyle.self, forKey: .appearAnimationStyle) ?? .roll
        self.windowPopAnimationStyle = try c.decodeIfPresent(WindowPopAnimationStyle.self, forKey: .windowPopAnimationStyle) ?? .genie
        self.smoothWindowTransitions = try c.decodeIfPresent(Bool.self, forKey: .smoothWindowTransitions) ?? true
        self.includePadding = try c.decodeIfPresent(Bool.self, forKey: .includePadding) ?? true
        self.showRadialPreview = try c.decodeIfPresent(Bool.self, forKey: .showRadialPreview) ?? true
        self.radialHapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .radialHapticsEnabled) ?? true
        self.useScreenWithCursor = try c.decodeIfPresent(Bool.self, forKey: .useScreenWithCursor) ?? true
        self.moveCursorWithWindow = try c.decodeIfPresent(Bool.self, forKey: .moveCursorWithWindow) ?? false
        self.multiScreenAppPolicy = try c.decodeIfPresent(MultiScreenAppPolicy.self, forKey: .multiScreenAppPolicy) ?? .smartKeepOtherScreen
        self.toggleHotkey = try c.decodeIfPresent(ToggleHotkeyPreset.self, forKey: .toggleHotkey) ?? .optionSpace
        self.customToggleShortcut = try c.decodeIfPresent(CustomKeyCombo.self, forKey: .customToggleShortcut)
        self.customMoveScreenShortcut = try c.decodeIfPresent(CustomKeyCombo.self, forKey: .customMoveScreenShortcut)
        self.radialKeyboardMode = try c.decodeIfPresent(RadialKeyboardTriggerMode.self, forKey: .radialKeyboardMode) ?? .disabled
        self.radialKeyboardShortcut = try c.decodeIfPresent(CustomKeyCombo.self, forKey: .radialKeyboardShortcut) ?? .optionQ
        self.splitRingHotkeyEnabled = try c.decodeIfPresent(Bool.self, forKey: .splitRingHotkeyEnabled) ?? true
        self.splitRingShortcut = try c.decodeIfPresent(CustomKeyCombo.self, forKey: .splitRingShortcut) ?? .optionS
        self.radialModifierKey = try c.decodeIfPresent(RadialModifierKey.self, forKey: .radialModifierKey) ?? .rightOption
        self.radialCustomMouseButton = try c.decodeIfPresent(Int.self, forKey: .radialCustomMouseButton) ?? 3
        self.radialCustomMouseModifiers = try c.decodeIfPresent(UInt32.self, forKey: .radialCustomMouseModifiers) ?? 0
        self.splitMouseTrigger = try c.decodeIfPresent(SplitMouseTriggerMode.self, forKey: .splitMouseTrigger) ?? .optionMiddle
        self.splitCustomMouseButton = try c.decodeIfPresent(Int.self, forKey: .splitCustomMouseButton) ?? 2
        self.splitCustomMouseModifiers = try c.decodeIfPresent(UInt32.self, forKey: .splitCustomMouseModifiers) ?? CustomKeyCombo.modOption
        self.ringResizeModifier = try c.decodeIfPresent(RingResizeModifier.self, forKey: .ringResizeModifier) ?? .command
        self.numberSwitchModifier = try c.decodeIfPresent(NumberSwitchModifier.self, forKey: .numberSwitchModifier) ?? .command
        self.scrollWheelSwitchesApp = try c.decodeIfPresent(Bool.self, forKey: .scrollWheelSwitchesApp) ?? false
        // New key; older configs start on .browse (the old always-switch flag caused accidental
        // switches while scrolling to the end of the tray).
        self.scrollWheelBehavior = try c.decodeIfPresent(ScrollWheelBehavior.self, forKey: .scrollWheelBehavior) ?? .browse
        self.sortRunningAppsFirst = try c.decodeIfPresent(Bool.self, forKey: .sortRunningAppsFirst) ?? true
        self.radialAppOrderMode = try c.decodeIfPresent(RadialAppOrderMode.self, forKey: .radialAppOrderMode) ?? .addedOrder
        self.showInactiveAppsInRing = try c.decodeIfPresent(Bool.self, forKey: .showInactiveAppsInRing) ?? true
        self.indicatorStyle = try c.decodeIfPresent(IndicatorStyle.self, forKey: .indicatorStyle) ?? .dot
        self.indicatorColor = try c.decodeIfPresent(IndicatorColorPreset.self, forKey: .indicatorColor) ?? .classic
        self.indicatorSize = try c.decodeIfPresent(Double.self, forKey: .indicatorSize) ?? 4.5
        self.showInactiveIndicator = try c.decodeIfPresent(Bool.self, forKey: .showInactiveIndicator) ?? false
        self.showNotificationBadges = try c.decodeIfPresent(Bool.self, forKey: .showNotificationBadges) ?? true
    }
}

public struct PersistedStageConfig: Codable, Equatable, Sendable {
    public var apps: [StageAppItem]
    public var pinnedScreenID: String?
    public var customDockOriginQuartz: CodablePoint?
    public var lastActiveBundleID: String?
    public var settings: StageSettings
    public var appUsageCounts: [String: Int]
    public var appLastUsedTimestamps: [String: Double]

    public init(
        apps: [StageAppItem] = [],
        pinnedScreenID: String? = nil,
        customDockOriginQuartz: CodablePoint? = nil,
        lastActiveBundleID: String? = nil,
        settings: StageSettings = StageSettings(),
        appUsageCounts: [String: Int] = [:],
        appLastUsedTimestamps: [String: Double] = [:]
    ) {
        self.apps = apps
        self.pinnedScreenID = pinnedScreenID
        self.customDockOriginQuartz = customDockOriginQuartz
        self.lastActiveBundleID = lastActiveBundleID
        self.settings = settings
        self.appUsageCounts = appUsageCounts
        self.appLastUsedTimestamps = appLastUsedTimestamps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.apps = try c.decodeIfPresent([StageAppItem].self, forKey: .apps) ?? []
        self.pinnedScreenID = try c.decodeIfPresent(String.self, forKey: .pinnedScreenID)
        self.customDockOriginQuartz = try c.decodeIfPresent(CodablePoint.self, forKey: .customDockOriginQuartz)
        self.lastActiveBundleID = try c.decodeIfPresent(String.self, forKey: .lastActiveBundleID)
        self.settings = try c.decodeIfPresent(StageSettings.self, forKey: .settings) ?? StageSettings()
        self.appUsageCounts = try c.decodeIfPresent([String: Int].self, forKey: .appUsageCounts) ?? [:]
        self.appLastUsedTimestamps = try c.decodeIfPresent([String: Double].self, forKey: .appLastUsedTimestamps) ?? [:]
    }
}
