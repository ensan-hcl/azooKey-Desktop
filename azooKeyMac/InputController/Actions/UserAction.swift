
enum UserAction {
    case input(String)
    case backspace
    case enter
    case space
    case escape
    case unknown
    case predictNextCharacter
    case 英数
    case かな
    case navigation(NavigationDirection)

    enum NavigationDirection {
        case up, down, right, left
    }
}
