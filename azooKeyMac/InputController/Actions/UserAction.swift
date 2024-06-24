
enum UserAction {
    case input(String)
    case backspace
    case enter
    case space
    case unknown
    case 英数
    case かな
    case navigation(NavigationDirection)

    enum NavigationDirection {
        case up, down, right, left
    }
}
