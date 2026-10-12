import Foundation

/// Puts `fq` on the command line by linking `~/.local/bin/fq` to the copy inside the app.
///
/// The app does this on every launch, so the link follows the app after an update or a move.
/// It only links from Applications, because a link into a disk image or a Downloads copy breaks
/// as soon as that copy goes away. It never replaces an `fq` that is not one of ours.
enum CommandLineTool {
    enum Status: Equatable {
        /// Linked, and whether the login shell's PATH has the folder.
        case installed(onPath: Bool)
        /// The app is running from somewhere other than Applications.
        case notInApplications
        /// This copy carries no `fq`. Only `scripts/package.sh` puts it in the app.
        case notBundled
        /// Something else already lives at `~/.local/bin/fq`.
        case occupied
        case failed(String)
    }

    static let folder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin", isDirectory: true)
    static let link = folder.appendingPathComponent("fq")

    /// Shown in place of the full path in messages.
    static let displayPath = "~/.local/bin/fq"

    private static var bundled: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/fq")
    }

    @discardableResult
    static func install() -> Status {
        let manager = FileManager.default
        let app = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let applications = ["/Applications/", manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/"]
        guard manager.isExecutableFile(atPath: bundled.path) else { return .notBundled }
        guard applications.contains(where: app.hasPrefix) else { return .notInApplications }

        if let existing = try? manager.destinationOfSymbolicLink(atPath: link.path) {
            if existing == bundled.path { return .installed(onPath: folderIsOnPath) }
            // Ours from an earlier copy of the app, now moved or renamed: point it here instead.
            guard existing.hasSuffix(".app/Contents/MacOS/fq"), existing.contains("FiscalQuarter") else { return .occupied }
            try? manager.removeItem(at: link)
        } else if manager.fileExists(atPath: link.path) {
            return .occupied
        }

        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            try manager.createSymbolicLink(atPath: link.path, withDestinationPath: bundled.path)
            return .installed(onPath: folderIsOnPath)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// A menu bar app gets launchd's short PATH, so this asks the login shell for the PATH a
    /// terminal would have. It gives up after two seconds and assumes the folder is there.
    private static var folderIsOnPath: Bool {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-i", "-c", "echo \"$PATH\""]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return true }

        let deadline = Date().addingTimeInterval(2)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning {
            process.terminate()
            return true
        }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let path = text.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
        let entries = path.split(separator: ":").map { NSString(string: String($0)).expandingTildeInPath }
        return entries.contains(folder.path) || entries.contains(folder.path + "/")
    }
}

/// Runs the install off the main thread at launch and holds the result for the About page.
@MainActor
final class CommandLineToolController: ObservableObject {
    @Published private(set) var status: CommandLineTool.Status?

    /// Fixed status, for pictures and previews. It installs nothing.
    init(status: CommandLineTool.Status?) {
        self.status = status
    }

    init() {
        Task.detached(priority: .utility) {
            let status = CommandLineTool.install()
            await MainActor.run { self.status = status }
        }
    }

    var message: String? {
        switch status {
        case nil, .notBundled: return nil
        case .installed(onPath: true):
            return "fq is installed at \(CommandLineTool.displayPath)."
        case .installed(onPath: false):
            return "fq is installed at \(CommandLineTool.displayPath). Add ~/.local/bin to PATH in your shell profile to use it."
        case .notInApplications:
            return "Move Fiscal Quarter to Applications to install the fq command."
        case .occupied:
            return "\(CommandLineTool.displayPath) is another program, so fq was not installed there."
        case .failed(let reason):
            return "fq could not be installed: \(reason)"
        }
    }
}
