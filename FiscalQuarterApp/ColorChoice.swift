import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A labeled color control for the appearance editor.
///
/// On iOS it is the system `ColorPicker`. On macOS the editor lives in a menu bar window, and
/// `ColorPicker` opens the shared color panel, which takes key focus and closes that window,
/// taking the picker's binding with it, so a choice never lands. The Mac instead shows a row
/// of swatches, plus Other… for the color panel, whose changes go through a long-lived target
/// rather than the closed window's views.
struct ColorChoice: View {
    let title: String
    @Binding var selection: Color

    init(_ title: String, selection: Binding<Color>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            HStack(spacing: 8) {
                ForEach(Self.swatches, id: \.self) { hex in
                    swatch(RGBAColor(hex: hex)!)
                }
                Button("Other…") {
                    ColorPanelTarget.shared.show(title: title, color: selection) { selection = $0 }
                }
                .controlSize(.small)
            }
        }
        #else
        ColorPicker(title, selection: $selection, supportsOpacity: false)
        #endif
    }

    #if os(macOS)
    /// Colors that read on light and dark backgrounds, with white and near-black for text-like accents.
    /// Eight, to fit beside Other… in the 328-point panel.
    static let swatches = [
        "#FFFFFF", "#1C1C1E", "#E5484D", "#F76B15", "#FFC53D", "#30A46C", "#0090FF", "#8E4EC6",
    ]

    private func swatch(_ color: RGBAColor) -> some View {
        let chosen = RGBAColor(selection).map { $0.isClose(to: color) } ?? false
        return Button {
            selection = Color(color)
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2)))
                .overlay(Circle().strokeBorder(Color.primary, lineWidth: 2).padding(-3).opacity(chosen ? 1 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.hex)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
    #endif
}

#if os(macOS)
private extension RGBAColor {
    /// Within rounding of a stored hex value, so a swatch shows as chosen after a save and load.
    func isClose(to other: RGBAColor) -> Bool {
        abs(red - other.red) < 0.01 && abs(green - other.green) < 0.01 && abs(blue - other.blue) < 0.01
    }
}

/// Receives the shared color panel's changes. It outlives the menu bar window, which closes as
/// soon as the panel comes forward, so each change still reaches the appearance.
private final class ColorPanelTarget: NSObject {
    static let shared = ColorPanelTarget()

    private var apply: ((Color) -> Void)?

    func show(title: String, color: Color, apply: @escaping (Color) -> Void) {
        let panel = NSColorPanel.shared
        // Clear the old target first so setting the starting color does not apply it to the last field.
        panel.setTarget(nil)
        panel.setAction(nil)
        self.apply = nil
        panel.showsAlpha = false
        panel.color = NSColor(color)
        panel.title = title
        self.apply = apply
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        apply?(Color(nsColor: sender.color))
    }
}
#endif
