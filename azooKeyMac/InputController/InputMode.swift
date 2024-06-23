
import Cocoa

enum InputMode {
    static func getUserAction(event: NSEvent) -> UserAction {
        switch event.keyCode {
        case 36: // Enter
            return .enter
        case 48: // Tab
            return .unknown
        case 49: // Space
            return .space
        case 51: // Delete
            return .delete
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
