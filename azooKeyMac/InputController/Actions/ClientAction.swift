
import InputMethodKit

indirect enum ClientAction {
    case `consume`
    case `fallthrough`
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)
    case removeLastMarkedText
    case moveCursorToStart
    case moveCursor(Int)
    case inputNextCharacter

    case commitMarkedText
    case submitSelectedCandidate
    case forwardToCandidateWindow(NSEvent)
    case selectInputMode(InputMode)

    case stopComposition

    enum InputMode {
        case roman
        case japanese
    }

    case sequence([ClientAction])
}
