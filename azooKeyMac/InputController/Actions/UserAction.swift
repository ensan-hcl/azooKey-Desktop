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
    case function(Function)
    case number(Number)

    enum NavigationDirection {
        case up, down, right, left
    }

    enum Function {
        case six, seven, eight
    }

    enum Number {
        case one, two, three, four, five, six, seven, eight, nine, zero
        var intValue: Int {
            switch self {
            case .one: 1
            case .two: 2
            case .three: 3
            case .four: 4
            case .five: 5
            case .six: 6
            case .seven: 7
            case .eight: 8
            case .nine: 9
            case .zero: 0
            }
        }

        var inputString: String {
            switch self {
            case .one: "1"
            case .two: "2"
            case .three: "3"
            case .four: "4"
            case .five: "5"
            case .six: "6"
            case .seven: "7"
            case .eight: "8"
            case .nine: "9"
            case .zero: "0"
            }
        }
    }
}
