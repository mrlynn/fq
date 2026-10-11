import SwiftUI

extension Color {
    init(_ color: RGBAColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

extension RGBAColor {
    /// The sRGB components of a SwiftUI color, as the color picker hands them back.
    init?(_ color: Color) {
        #if os(macOS)
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(converted.redComponent), green: Double(converted.greenComponent),
                  blue: Double(converted.blueComponent), alpha: Double(converted.alphaComponent))
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        #endif
    }
}

/// The SwiftUI side of an `Appearance`: fonts, colors, and the background.
struct Theme {
    let appearance: Appearance

    static let standardAccent = Color(Appearance.standardAccent)
    static let warning = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)

    /// The chosen accent. Without one, the standard green, unless it would be hard to see on
    /// the background, and then the text color.
    var accent: Color {
        if let accent = appearance.accent { return Color(accent) }
        return appearance.standardAccentIsFaint ? .primary : Self.standardAccent
    }

    /// The color scheme to force so `.primary` and `.secondary` read well on this background.
    /// Nil leaves the system's own scheme alone.
    var colorScheme: ColorScheme? {
        appearance.prefersLightText.map { $0 ? .dark : .light }
    }

    /// Text at `size` points, scaled by the chosen text size, in the chosen typeface.
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let scaled = size * appearance.textSize.scale
        if let family = appearance.typeface.familyName {
            return .custom(family, size: scaled).weight(weight)
        }
        return .system(size: scaled, weight: weight, design: design)
    }

    /// The big countdown number, in the chosen weight.
    func numberFont(_ size: CGFloat) -> Font {
        font(size, appearance.numberWeight.fontWeight)
    }

    /// The design to apply to a whole screen's system text. Named typefaces keep the default
    /// there and apply only where `font(_:_:)` is used.
    var fontDesign: Font.Design {
        design
    }

    private var design: Font.Design {
        switch appearance.typeface {
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        default: return .default
        }
    }
}

extension Appearance.Weight {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

/// The background an appearance asks for. The system background draws nothing, so the caller's
/// own background shows through.
struct ThemeBackground: View {
    let appearance: Appearance
    /// The picture for an image background, loaded by the caller so a widget can load it once.
    var image: CGImage?

    var body: some View {
        switch appearance.background {
        case .system:
            Color.clear
        case .color(let color):
            Color(color)
        case .gradient(let gradient):
            LinearGradient(colors: gradient.colors.map(Color.init), startPoint: start(gradient.angle), endPoint: end(gradient.angle))
        case .image:
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    // The file is missing, for example after a restore. Stay readable.
                    Color(white: 0.2)
                }
                Color.black.opacity(appearance.scrim)
            }
        }
    }

    /// A gradient angle of 0 runs top to bottom, and 90 runs left to right.
    private func start(_ angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 - sin(radians) / 2, y: 0.5 - cos(radians) / 2)
    }

    private func end(_ angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 + sin(radians) / 2, y: 0.5 + cos(radians) / 2)
    }
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue = Theme.standardAccent
}

private struct RingFillKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// The accent the year pictures draw with.
    var fiscalAccent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }

    /// What fills today's hollow ring. Nil means the window background.
    var fiscalRingFill: Color? {
        get { self[RingFillKey.self] }
        set { self[RingFillKey.self] = newValue }
    }
}

extension View {
    /// A soft shadow under text and bars that sit straight on a photo, so they stand off the
    /// light and busy parts of the picture. Does nothing on other backgrounds. Apply it only to
    /// content drawn on the background itself, not to cards that bring their own fill.
    @ViewBuilder
    func photoLegibility(_ appearance: Appearance) -> some View {
        if appearance.wantsTextShadow {
            // A tight dark edge keeps thin strokes crisp, and a wide soft halo darkens the
            // picture just around the text.
            shadow(color: .black.opacity(0.65), radius: 1, x: 0, y: 1)
                .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 0)
        } else {
            self
        }
    }

    /// Applies an appearance's accent and text color to everything inside.
    @ViewBuilder
    func themed(_ appearance: Appearance) -> some View {
        let theme = Theme(appearance: appearance)
        let ringFill: Color? = {
            switch appearance.background {
            case .system: return nil
            case .color(let color): return Color(color)
            // A clear ring would show the month bar through it, so fill it with something close
            // to what is behind: the gradient's average, or the darkened picture.
            case .gradient(let gradient): return Color(gradient.averageColor)
            case .image: return Color(white: 0.18)
            }
        }()
        if let scheme = theme.colorScheme {
            environment(\.fiscalAccent, theme.accent)
                .environment(\.fiscalRingFill, ringFill)
                .environment(\.colorScheme, scheme)
        } else {
            environment(\.fiscalAccent, theme.accent)
                .environment(\.fiscalRingFill, ringFill)
        }
    }
}
