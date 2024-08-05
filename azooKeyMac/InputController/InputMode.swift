import Cocoa

enum InputMode {
    static func getUserAction(event: NSEvent) -> UserAction {
        // see: https://developer.mozilla.org/ja/docs/Web/API/UI_Events/Keyboard_event_code_values#mac_%E3%81%A7%E3%81%AE%E3%82%B3%E3%83%BC%E3%83%89%E5%80%A4
        switch event.keyCode {
        case 0x04: // 'H'
            // Ctrl + H is binding for backspace
            if event.modifierFlags.contains(.control) {
                return .backspace
            } else if let text = event.characters, isPrintable(text) {
                return .input(KeyMap.h2zMap(text))
            } else {
                return .unknown
            }
        case 36: // Enter
            return .enter
        case 48: // Tab
            return .unknown
        case 49: // Space
            return .space
        case 51: // Delete
            return .backspace
        case 53: // Escape
            return .escape
        case 93: // Yen
            switch (Config.TypeBackSlash().value, event.modifierFlags.contains(.shift), event.modifierFlags.contains(.option)) {
            case (_, true, _):
                return .input(KeyMap.h2zMap("|"))
            case (true, false, false), (false, false, true):
                return .input(KeyMap.h2zMap("\\"))
            case (true, false, true), (false, false, false):
                return .input(KeyMap.h2zMap("¥"))
            }
        case 102: // Lang2/kVK_JIS_Eisu
            return .英数
        case 104: // Lang1/kVK_JIS_Kana
            return .かな
        case 123: // Left
            return .navigation(.left)
        case 124: // Right
            return .navigation(.right)
        case 125: // Down
            return .navigation(.down)
        case 126: // Up
            return .navigation(.up)
        case 18:
            return .number(.one)
        case 19:
            return .number(.two)
        case 20:
            return .number(.three)
        case 21:
            return .number(.four)
        case 23:
            return .number(.five)
        case 22:
            return .number(.six)
        case 26:
            return .number(.seven)
        case 28:
            return .number(.eight)
        case 25:
            return .number(.nine)
        case 29:
            return .number(.zero)
        default:
            if let text = event.characters, isPrintable(text) {
                return .input(KeyMap.h2zMap(text))
            } else {
                return .unknown
            }
        }
    }

    private static func isPrintable(_ text: String) -> Bool {
        let printable: CharacterSet = [.alphanumerics, .symbols, .punctuationCharacters]
            .reduce(into: CharacterSet()) {
                $0.formUnion($1)
            }
        return CharacterSet(text.unicodeScalars).isSubset(of: printable)
    }
}
