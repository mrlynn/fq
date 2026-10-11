import Foundation

/// How the app and its widgets look: background, type, colors, and which parts are shown.
///
/// One appearance is shared through the App Group, so the panel, the iOS app, and every widget
/// change together. It holds plain values only. The SwiftUI side lives in `FiscalQuarterUI`.
public struct Appearance: Equatable, Codable {
    public var background: Background
    /// How much to darken a photo or image so text stays readable, from 0 to 0.7.
    public var scrim: Double
    public var foreground: Foreground
    /// Bars, today's ring, and the current quarter. Nil is the standard green.
    public var accent: RGBAColor?
    public var typeface: Typeface
    public var numberWeight: Weight
    public var textSize: TextSize
    public var display: Display

    public init(
        background: Background = .system,
        scrim: Double = 0.35,
        foreground: Foreground = .automatic,
        accent: RGBAColor? = nil,
        typeface: Typeface = .system,
        numberWeight: Weight = .bold,
        textSize: TextSize = .regular,
        display: Display = Display()
    ) {
        self.background = background
        self.scrim = scrim
        self.foreground = foreground
        self.accent = accent
        self.typeface = typeface
        self.numberWeight = numberWeight
        self.textSize = textSize
        self.display = display
    }

    public static let standard = Appearance()

    public enum Background: Equatable, Codable {
        /// The system's own widget and window background.
        case system
        case color(RGBAColor)
        case gradient(GradientSpec)
        /// A picture copied into the App Group container, named by its file there.
        case image(String)
    }

    public enum Foreground: String, CaseIterable, Codable, Identifiable {
        case automatic, light, dark
        public var id: String { rawValue }
        public var title: String { rawValue.capitalized }
    }

    /// Typefaces that exist on both macOS and iOS, so a widget looks the same on either.
    public enum Typeface: String, CaseIterable, Codable, Identifiable {
        case system, rounded, serif, monospaced
        case avenirNext, futura, georgia, gillSans, didot, americanTypewriter

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .system: return "System"
            case .rounded: return "Rounded"
            case .serif: return "Serif"
            case .monospaced: return "Monospaced"
            case .avenirNext: return "Avenir Next"
            case .futura: return "Futura"
            case .georgia: return "Georgia"
            case .gillSans: return "Gill Sans"
            case .didot: return "Didot"
            case .americanTypewriter: return "American Typewriter"
            }
        }

        /// The installed family name, or nil for the system font in one of its designs.
        public var familyName: String? {
            switch self {
            case .system, .rounded, .serif, .monospaced: return nil
            default: return title
            }
        }
    }

    public enum Weight: String, CaseIterable, Codable, Identifiable {
        case regular, medium, semibold, bold, heavy, black
        public var id: String { rawValue }
        public var title: String { rawValue.capitalized }
    }

    public enum TextSize: String, CaseIterable, Codable, Identifiable {
        case small, regular, large
        public var id: String { rawValue }
        public var title: String { rawValue.capitalized }

        public var scale: Double {
            switch self {
            case .small: return 0.88
            case .regular: return 1
            case .large: return 1.14
            }
        }
    }

    /// Which parts of a countdown are shown.
    public struct Display: Equatable, Codable {
        public var progressBars: Bool
        public var endDate: Bool
        /// The quarter id under a widget's label, such as `FY26-Q4` under `SpaceX`.
        public var subtitle: Bool
        /// The quarter, half, and year rows beside the number in the medium widget.
        public var otherPeriods: Bool
        public var centered: Bool

        public init(progressBars: Bool = true, endDate: Bool = true, subtitle: Bool = true, otherPeriods: Bool = true, centered: Bool = false) {
            self.progressBars = progressBars
            self.endDate = endDate
            self.subtitle = subtitle
            self.otherPeriods = otherPeriods
            self.centered = centered
        }
    }

    /// Whether text should be light or dark on this background. Nil means follow the system,
    /// which is right for the system background.
    public var prefersLightText: Bool? {
        switch foreground {
        case .light: return true
        case .dark: return false
        case .automatic:
            switch background {
            case .system:
                return nil
            case .color(let color):
                return color.luminance < 0.6
            case .gradient(let gradient):
                let colors = gradient.colors
                guard !colors.isEmpty else { return nil }
                return colors.map(\.luminance).reduce(0, +) / Double(colors.count) < 0.6
            case .image:
                // A photo is unpredictable. The scrim darkens it, so light text is the safe choice.
                return true
            }
        }
    }

    /// The standard green, which the accent falls back to.
    public static let standardAccent = RGBAColor(red: 16 / 255, green: 185 / 255, blue: 129 / 255)

    /// The background's average brightness, for a solid color or a gradient. Nil for the system
    /// background and for pictures, which this cannot see.
    public var backgroundLuminance: Double? {
        switch background {
        case .color(let color):
            return color.luminance
        case .gradient(let gradient) where !gradient.colors.isEmpty:
            return gradient.colors.map(\.luminance).reduce(0, +) / Double(gradient.colors.count)
        default:
            return nil
        }
    }

    /// Whether the standard green is too faint on this background, so bars should use the text
    /// color instead. Only applies when no accent is chosen.
    public var standardAccentIsFaint: Bool {
        guard accent == nil, let background = backgroundLuminance else { return false }
        return RGBAColor.contrast(Self.standardAccent.luminance, background) < 2.5
    }

    /// The image file this appearance uses, if any.
    public var imageFile: String? {
        if case .image(let name) = background { return name }
        return nil
    }
}

/// A gradient between two or more colors, at an angle in degrees: 0 runs top to bottom,
/// 45 from the top left corner to the bottom right, and 90 left to right.
public struct GradientSpec: Equatable, Codable {
    public var colors: [RGBAColor]
    public var angle: Double

    public init(colors: [RGBAColor], angle: Double = 45) {
        self.colors = colors
        self.angle = angle
    }

    /// The colors averaged, for something that should sit quietly on the gradient.
    public var averageColor: RGBAColor {
        guard !colors.isEmpty else { return RGBAColor(red: 0.5, green: 0.5, blue: 0.5) }
        let count = Double(colors.count)
        return RGBAColor(
            red: colors.map(\.red).reduce(0, +) / count,
            green: colors.map(\.green).reduce(0, +) / count,
            blue: colors.map(\.blue).reduce(0, +) / count
        )
    }

    /// Ready-made gradients for the editor.
    public static let presets: [(name: String, gradient: GradientSpec)] = [
        ("Sunrise", GradientSpec(colors: [RGBAColor(hex: "#FF9A5A")!, RGBAColor(hex: "#FF4E88")!])),
        ("Ocean", GradientSpec(colors: [RGBAColor(hex: "#1FA2FF")!, RGBAColor(hex: "#12D8A8")!])),
        ("Forest", GradientSpec(colors: [RGBAColor(hex: "#134E3A")!, RGBAColor(hex: "#3E9B5F")!])),
        ("Dusk", GradientSpec(colors: [RGBAColor(hex: "#2B1055")!, RGBAColor(hex: "#D53A9D")!])),
        ("Graphite", GradientSpec(colors: [RGBAColor(hex: "#232526")!, RGBAColor(hex: "#5A6068")!])),
        ("Mint", GradientSpec(colors: [RGBAColor(hex: "#D4FC79")!, RGBAColor(hex: "#96E6A1")!])),
    ]
}

/// An sRGB color with alpha, stored as `#RRGGBB` or `#RRGGBBAA`.
public struct RGBAColor: Equatable, Hashable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    /// Parses `#RRGGBB` or `#RRGGBBAA`, with or without the `#`.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let hasAlpha = text.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        self.init(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    public var hex: String {
        let parts = [red, green, blue] + (alpha < 1 ? [alpha] : [])
        return "#" + parts.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    /// Relative luminance, from 0 for black to 1 for white.
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let color = RGBAColor(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected #RRGGBB, got \"\(text)\".")
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    /// The WCAG contrast ratio between two luminances, from 1 to 21.
    public static func contrast(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

extension Appearance {
    static let storedKey = "appearance"

    /// The saved appearance, or the standard one when nothing is saved or it no longer decodes.
    public static func load(from settings: SettingsSource) -> Appearance {
        guard let data = settings.object(forKey: storedKey) as? Data,
              let appearance = try? JSONDecoder().decode(Appearance.self, from: data)
        else {
            return .standard
        }
        return appearance
    }

    public func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storedKey)
        }
    }
}
