import AppKit
import SwiftUI

@main
struct RenderPictures {
    static func main() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 9))
        let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/fq-pictures")
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for scheme in [ColorScheme.light, ColorScheme.dark] {
                let schemeName = scheme == .dark ? "dark" : "light"
                let background = scheme == .dark ? Color(white: 0.12) : Color(white: 0.97)
                for kind in PictureKind.allCases {
                    let view = YearPicture(snapshot: snapshot, kind: kind, select: { _ in })
                        .frame(width: 296)
                        .padding(16)
                        .background(background)
                        .environment(\.colorScheme, scheme)
                    try write(view, to: output.appendingPathComponent("\(kind.rawValue)-\(schemeName).png"))
                }
                UserDefaults.standard.set(PictureKind.line.rawValue, forKey: "yearPicture")
                let linePanel = QuarterPanel(clock: QuarterClock(), calendar: CalendarModel(), commandLine: CommandLineToolController(status: nil))
                    .background(background)
                    .environment(\.colorScheme, scheme)
                try write(linePanel, to: output.appendingPathComponent("panel-line-\(schemeName).png"))
                UserDefaults.standard.set(PictureKind.year.rawValue, forKey: "yearPicture")
                let yearPanel = QuarterPanel(clock: QuarterClock(), calendar: CalendarModel(), commandLine: CommandLineToolController(status: nil))
                    .background(background)
                    .environment(\.colorScheme, scheme)
                try write(yearPanel, to: output.appendingPathComponent("panel-year-\(schemeName).png"))
                let about = AboutView(commandLine: CommandLineToolController(status: .installed(onPath: true)), dismiss: {})
                    .padding(16)
                    .frame(width: 328)
                    .background(background)
                    .environment(\.colorScheme, scheme)
                try write(about, to: output.appendingPathComponent("about-\(schemeName).png"))
            }
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    static func write<V: View>(_ view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 328, height: nil)
        guard let image = renderer.nsImage else {
            fputs("no image for \(url.lastPathComponent)\n", stderr)
            return
        }
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            fputs("no png for \(url.lastPathComponent)\n", stderr)
            return
        }
        try png.write(to: url)
        print("\(url.lastPathComponent) \(Int(image.size.width))x\(Int(image.size.height))")
    }
}
