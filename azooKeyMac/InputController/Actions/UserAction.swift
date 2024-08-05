enum UserAction {
    case input(String)
    case backspace
    case enter
    case space
    case escape
    case unknown
    case 英数
    case かな
    case navigation(NavigationDirection)
    case number(Number)

    enum NavigationDirection {
        case up, down, right, left
    }

    enum Number {
        case one, two, three, four, five, six, seven, eight, nine, zero
    }
}
