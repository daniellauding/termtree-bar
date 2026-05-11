import SwiftUI
import AppKit

@main
struct TermtreeBarApp: App {
    var body: some Scene {
        MenuBarExtra("termtree", systemImage: "leaf.circle.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct Command: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let icon: String
    let args: [String]
    let tooltip: String
}

let kCommands: [Command] = [
    .init(label: "Home",        icon: "house",              args: ["~", "-d", "1"],                tooltip: "Top-level of ~"),
    .init(label: "Downloads",   icon: "arrow.down.circle",  args: ["~/Downloads", "-d", "2"],      tooltip: "Two levels into ~/Downloads"),
    .init(label: "Library",     icon: "books.vertical",     args: ["~/Library", "-d", "1"],        tooltip: "What's eating ~/Library"),
    .init(label: "Documents",   icon: "doc.text",           args: ["~/Documents", "-d", "2"],      tooltip: "Two levels into ~/Documents"),
    .init(label: "Apps",        icon: "app.badge",          args: ["/Applications", "-d", "1"],    tooltip: "Installed apps by size"),
    .init(label: "Root /",      icon: "externaldrive",      args: ["/", "-d", "1"],                tooltip: "Whole disk (needs perms for some)"),
    .init(label: "System",      icon: "cpu",                args: ["--sys"],                       tooltip: "CPU + memory + disk + network"),
    .init(label: "System +5s",  icon: "stopwatch",          args: ["--sys", "--sample", "5"],      tooltip: "System overview with 5s sample"),
]

struct ContentView: View {
    @State private var output: AttributedString = ANSIParser.parse(
        "\u{001B}[1mtermtree-bar\u{001B}[0m\n" +
        "Pick a target above. Output appears here.\n\n" +
        "Tip: \u{001B}[38;2;120;220;130mHome\u{001B}[0m and \u{001B}[38;2;120;220;130mSystem\u{001B}[0m " +
        "are the quickest. Apps / Root run for a while."
    )
    @State private var isRunning = false
    @State private var currentLabel = ""
    @State private var lastDuration: Double = 0
    @State private var termtreeFound: String? = TermtreeRunner.locate()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            buttonGrid
            outputArea
            footer
        }
        .padding(12)
        .frame(width: 760, height: 580)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
            Text("termtree")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            if !currentLabel.isEmpty {
                Text("· \(currentLabel)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isRunning {
                ProgressView().controlSize(.small)
            }
            Button(action: copyOutput) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy output to clipboard")
            .disabled(isRunning)
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Quit termtree-bar")
            .keyboardShortcut("q")
        }
    }

    private var buttonGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(kCommands) { cmd in
                Button(action: { run(cmd) }) {
                    Label(cmd.label, systemImage: cmd.icon)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRunning || termtreeFound == nil)
                .help(cmd.tooltip)
            }
        }
    }

    @State private var outputVersion = 0

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                Text(output)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .id("top")
            }
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .onChange(of: outputVersion) { _, _ in
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let path = termtreeFound {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 9))
                Text(path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 9))
                Text("termtree not found in PATH. Install: github.com/daniellauding/termtree")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if lastDuration > 0 {
                Text(String(format: "%.1fs", lastDuration))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func run(_ cmd: Command) {
        currentLabel = cmd.label
        isRunning = true
        let start = Date()
        output = AttributedString("Running termtree \(cmd.args.joined(separator: " "))…\n")

        Task.detached(priority: .userInitiated) {
            let raw = await TermtreeRunner.run(args: cmd.args)
            let cleaned = ANSIParser.stripCarriageReturns(raw)
            let parsed = ANSIParser.parse(cleaned)
            let elapsed = Date().timeIntervalSince(start)
            await MainActor.run {
                output = parsed
                lastDuration = elapsed
                isRunning = false
                outputVersion &+= 1
            }
        }
    }

    private func copyOutput() {
        let plain = String(output.characters)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plain, forType: .string)
    }
}
