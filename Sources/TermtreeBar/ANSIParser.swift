import SwiftUI

enum ANSIParser {
    /// Collapse \r progress updates: keep only what follows the last \r on each line.
    static func stripCarriageReturns(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line -> String in
            if let lastReturn = line.range(of: "\r", options: .backwards) {
                return String(line[lastReturn.upperBound...])
            }
            return line
        }.joined(separator: "\n")
    }

    /// Parse ANSI SGR sequences into an AttributedString. Supports reset, bold,
    /// dim, 8/16-color, 256-color, and 24-bit truecolor foregrounds. Background
    /// colors and other CSI codes are ignored.
    static func parse(_ text: String) -> AttributedString {
        var result = AttributedString()
        var current = ""

        var fg: Color? = nil
        var isBold = false
        var isDim = false

        func flush() {
            guard !current.isEmpty else { return }
            var piece = AttributedString(current)
            if isDim {
                piece.foregroundColor = .secondary
            } else if let c = fg {
                piece.foregroundColor = c
            }
            if isBold {
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            result += piece
            current = ""
        }

        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            let next = text.index(after: i)
            if c == "\u{001B}", next < text.endIndex, text[next] == "[" {
                flush()
                var j = text.index(i, offsetBy: 2)
                var paramStr = ""
                while j < text.endIndex, !"mABCDEFGHJKSTfnsuhl".contains(text[j]), paramStr.count < 64 {
                    paramStr.append(text[j])
                    j = text.index(after: j)
                }
                let terminator: Character = (j < text.endIndex) ? text[j] : "m"
                if terminator == "m" {
                    let params = paramStr.split(separator: ";").compactMap { Int($0) }
                    apply(params: params, fg: &fg, bold: &isBold, dim: &isDim)
                }
                i = (j < text.endIndex) ? text.index(after: j) : j
            } else {
                current.append(c)
                i = next
            }
        }
        flush()
        return result
    }

    private static func apply(params: [Int], fg: inout Color?, bold: inout Bool, dim: inout Bool) {
        if params.isEmpty {
            fg = nil; bold = false; dim = false
            return
        }
        var idx = 0
        while idx < params.count {
            let code = params[idx]
            switch code {
            case 0:
                fg = nil; bold = false; dim = false
            case 1:
                bold = true
            case 2:
                dim = true
            case 22:
                bold = false; dim = false
            case 39:
                fg = nil
            case 38:
                if idx + 1 < params.count {
                    if params[idx + 1] == 2, idx + 4 < params.count {
                        let r = Double(params[idx + 2]) / 255.0
                        let g = Double(params[idx + 3]) / 255.0
                        let b = Double(params[idx + 4]) / 255.0
                        fg = Color(red: r, green: g, blue: b)
                        idx += 4
                    } else if params[idx + 1] == 5, idx + 2 < params.count {
                        fg = ansi256(params[idx + 2])
                        idx += 2
                    }
                }
            case 30...37:
                fg = basic8(code - 30)
            case 90...97:
                fg = bright8(code - 90)
            default:
                break
            }
            idx += 1
        }
    }

    private static func basic8(_ n: Int) -> Color {
        switch n {
        case 0: return .black
        case 1: return Color(red: 0.8, green: 0.2, blue: 0.2)
        case 2: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case 3: return Color(red: 0.85, green: 0.7, blue: 0.2)
        case 4: return Color(red: 0.3, green: 0.5, blue: 0.85)
        case 5: return Color(red: 0.7, green: 0.3, blue: 0.7)
        case 6: return Color(red: 0.3, green: 0.7, blue: 0.7)
        case 7: return .white
        default: return .primary
        }
    }

    private static func bright8(_ n: Int) -> Color {
        switch n {
        case 0: return Color(white: 0.5)
        case 1: return Color(red: 1, green: 0.4, blue: 0.4)
        case 2: return Color(red: 0.5, green: 1, blue: 0.5)
        case 3: return Color(red: 1, green: 0.9, blue: 0.4)
        case 4: return Color(red: 0.5, green: 0.7, blue: 1)
        case 5: return Color(red: 1, green: 0.5, blue: 1)
        case 6: return Color(red: 0.4, green: 1, blue: 1)
        case 7: return .white
        default: return .primary
        }
    }

    private static func ansi256(_ n: Int) -> Color {
        if n < 8 { return basic8(n) }
        if n < 16 { return bright8(n - 8) }
        if n >= 232 {
            let v = (Double(n - 232) * 10.0 + 8.0) / 255.0
            return Color(red: v, green: v, blue: v)
        }
        let cube = n - 16
        let levels: [Double] = [0, 95.0/255.0, 135.0/255.0, 175.0/255.0, 215.0/255.0, 1.0]
        let r = levels[(cube / 36) % 6]
        let g = levels[(cube / 6) % 6]
        let b = levels[cube % 6]
        return Color(red: r, green: g, blue: b)
    }
}
