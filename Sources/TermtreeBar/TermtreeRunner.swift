import Foundation

enum TermtreeRunner {
    /// Run `termtree` with the given args and return combined stdout+stderr.
    /// Wraps in `script -q /dev/null …` so termtree thinks stdout is a TTY and
    /// keeps the ANSI color output (otherwise it disables colors when piped).
    static func run(args: [String]) async -> String {
        guard let termtreePath = locate() else {
            return "termtree binary not found in PATH. Install from https://github.com/daniellauding/termtree"
        }
        let expanded = args.map { arg -> String in
            arg.hasPrefix("~") ? NSString(string: arg).expandingTildeInPath : arg
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
                process.arguments = ["-q", "/dev/null", termtreePath] + expanded

                var env = ProcessInfo.processInfo.environment
                env["COLORTERM"] = "truecolor"
                env["TERM"] = "xterm-256color"
                env["LANG"] = "en_US.UTF-8"
                env["LC_ALL"] = "en_US.UTF-8"
                process.environment = env

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? "(non-UTF-8 output)"
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "Failed to launch termtree: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Locate the `termtree` executable. Checks common install paths.
    static func locate() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/termtree",
            "/opt/homebrew/bin/termtree",
            "/usr/local/bin/termtree",
            "/usr/bin/termtree",
        ]
        let fm = FileManager.default
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}
