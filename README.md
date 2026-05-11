# termtree-bar

> macOS menu bar app for [termtree](https://github.com/daniellauding/termtree). Click the leaf, click a button, see the ASCII output. No terminal.

A native SwiftUI menu bar wrapper around the `termtree` CLI. One-click access to disk scans of common locations (Home, Downloads, Library, Applications, /) plus the system overview (CPU + memory + disk + network). Output renders inline with ANSI truecolor preserved, so the gradient bars and heat colors look the same as in the terminal.

```
┌────────────────────────────────────────────────────────────┐
│ 🍃 termtree · System                              📋  ✕    │
├────────────────────────────────────────────────────────────┤
│ [Home] [Downloads] [Library] [Documents]                   │
│ [Apps] [Root /]    [System]  [System +5s]                  │
├────────────────────────────────────────────────────────────┤
│  CPU     ██████▌            27.6%   8 cores · load 4.6...  │
│  Memory  ████████████████   93.8%   30 GB used / 32 GB...  │
│  Swap                       0 B     ● healthy              │
│  Disk    ██████████████▎    75.4%   347 GB used / 460 GB   │
│  Net     ↓ 6.8 KB/s         ↑ 13.7 KB/s                    │
│  ...                                                       │
└────────────────────────────────────────────────────────────┘
```

## Requirements

- macOS 14 (Sonoma) or later
- [`termtree`](https://github.com/daniellauding/termtree) installed and on `$PATH`. termtree-bar looks for it in (in order):
  - `~/.local/bin/termtree`
  - `/opt/homebrew/bin/termtree`
  - `/usr/local/bin/termtree`
  - `/usr/bin/termtree`

If termtree isn't found, the footer of the popover tells you so and the buttons are disabled.

## Install

### From source

```bash
git clone https://github.com/daniellauding/termtree-bar
cd termtree-bar
./Scripts/install.sh
```

This builds the app via SwiftPM, wraps the binary into a `.app` bundle with `LSUIElement = YES` (no Dock icon), copies it to `~/Applications/TermtreeBar.app`, and launches it.

To rebuild after editing: same `./Scripts/install.sh`.

### Launch at login

Right-click `~/Applications/TermtreeBar.app` → "Options" → "Open at Login" — or System Settings → General → Login Items.

## What's inside

- `Sources/TermtreeBar/TermtreeBarApp.swift` — `MenuBarExtra` entry + popover UI with button grid and inline output area
- `Sources/TermtreeBar/TermtreeRunner.swift` — Foundation `Process` invocation, wrapped in `script -q /dev/null` so termtree sees a PTY and keeps its colors (otherwise `isatty()` is false and it strips ANSI)
- `Sources/TermtreeBar/ANSIParser.swift` — translates ANSI SGR sequences (reset, bold, dim, 8/16-color, 256-color, 24-bit truecolor) into `AttributedString` for SwiftUI rendering
- `Scripts/package_app.sh` — `swift build -c release` + `.app` bundle assembly + ad-hoc codesign
- `Scripts/install.sh` — package, copy to `~/Applications`, launch

## How it talks to termtree

Each button maps to a fixed `termtree …` argv. Output is captured via a single `Process` call, ANSI-parsed on a background queue, then rendered. No persistent state, no background polling — each click is a fresh snapshot, same as running termtree manually.

The `script -q /dev/null` wrapper is the trick that keeps colors. termtree checks `sys.stdout.isatty()` and disables ANSI when piped; `script` gives the subprocess a PTY so it thinks it's still in a terminal.

## Customizing the buttons

Edit the `kCommands` array near the top of `TermtreeBarApp.swift`:

```swift
let kCommands: [Command] = [
    .init(label: "Home", icon: "house", args: ["~", "-d", "1"], tooltip: "..."),
    // add your own here — args is whatever you'd type after `termtree`
]
```

Icons are [SF Symbols](https://developer.apple.com/sf-symbols/) names. Rebuild with `./Scripts/install.sh`.

## License

MIT — see [LICENSE](LICENSE).
