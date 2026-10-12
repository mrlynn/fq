import AppKit
import SwiftUI

struct AboutView: View {
    @ObservedObject var commandLine: CommandLineToolController
    let dismiss: () -> Void

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let short, !short.isEmpty else { return "" }
        return "Version \(short)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: dismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Quarter")
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Back to the quarter")

            HStack(alignment: .center, spacing: 12) {
                AboutMark()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fiscal Quarter")
                        .font(.system(size: 18, weight: .semibold))
                    if !version.isEmpty {
                        Text(version)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("Made with ❤️ by Michael Lynn.")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Made with love by Michael Lynn.")

            VStack(alignment: .leading, spacing: 2) {
                aboutLink("mlynn.org", "https://mlynn.org")
                aboutLink("github.com/mrlynn/fq", "https://github.com/mrlynn/fq")
                aboutLink("linkedin.com/in/mlynn", "https://www.linkedin.com/in/mlynn")
            }

            if let message = commandLine.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private func aboutLink(_ title: String, _ raw: String) -> some View {
        Button(action: { open(raw) }) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .accessibilityLabel("Open \(title)")
    }

    private func open(_ raw: String) {
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The same four-part ring as the app icon, small enough for the credit.
private struct AboutMark: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            for index in 0..<4 {
                var path = Path()
                let start = Double(index) * 90 + 10
                let end = Double(index + 1) * 90 - 10
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                let color: Color = index == 3 ? MarkColor.green : Color.primary.opacity(0.28)
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }
}
