import InputMethodKit

enum InputState {
    case none
    case composing
    /// 変換範囲をユーザが調整したか
    case selecting(rangeAdjusted: Bool)

    mutating func event(_ event: NSEvent!, userAction: UserAction) -> ClientAction {
        if event.modifierFlags.contains(.command) {
            return .fallthrough
        }
        if event.modifierFlags.contains(.option) {
            guard case .input = userAction else {
                return .fallthrough
            }
        }
        switch self {
        case .none:
            switch userAction {
            case .input(let string):
                self = .composing
                return .appendToMarkedText(string)
            case .number(let number):
                self = .composing
                return .appendToMarkedText(number.inputString)
            case .かな:
                return .selectInputMode(.japanese)
            case .英数:
                return .selectInputMode(.roman)
            case .unknown, .navigation, .space, .backspace, .enter, .escape:
                return .fallthrough
            }
        case .composing:
            switch userAction {
            case .input(let string):
                return .appendToMarkedText(string)
            case .number(let number):
                return .appendToMarkedText(number.inputString)
            case .backspace:
                return .removeLastMarkedText
            case .enter:
                self = .none
                return .commitMarkedText
            case .escape:
                return .stopComposition
            case .space:
                self = .selecting(rangeAdjusted: false)
                return .enterCandidateSelectionMode
            case .かな:
                return .selectInputMode(.japanese)
            case .英数:
                self = .none
                return .sequence([.commitMarkedText, .selectInputMode(.roman)])
            case .navigation(let direction):
                if direction == .down {
                    self = .selecting(rangeAdjusted: false)
                    return .enterCandidateSelectionMode
                } else if direction == .right && event.modifierFlags.contains(.shift) {
                    self = .selecting(rangeAdjusted: true)
                    return .sequence([.moveCursorToStart, .moveCursor(1), .showCandidateWindow])
                } else if direction == .left && event.modifierFlags.contains(.shift) {
                    self = .selecting(rangeAdjusted: true)
                    return .sequence([.moveCursor(-1), .showCandidateWindow])
                } else {
                    // ナビゲーションはハンドルしてしまう
                    return .consume
                }
            case .unknown:
                return .fallthrough
            }
        case .selecting(let rangeAdjusted):
            switch userAction {
            case .input(let string):
                self = .composing
                return .sequence([.submitSelectedCandidate, .appendToMarkedText(string)])
            case .enter:
                self = .none
                return .submitSelectedCandidate
            case .backspace:
                self = .composing
                return .removeLastMarkedText
            case .escape:
                self = .composing
                return .hideCandidateWindow
            case .space:
                // シフトが入っている場合は上に移動する
                if event.modifierFlags.contains(.shift) {
                    return .selectPrevCandidate
                } else {
                    return .selectNextCandidate
                }
            case .navigation(let direction):
                if direction == .right {
                    if event.modifierFlags.contains(.shift) {
                        if rangeAdjusted {
                            return .sequence([.moveCursor(1), .showCandidateWindow])
                        } else {
                            self = .selecting(rangeAdjusted: true)
                            return .sequence([.moveCursorToStart, .moveCursor(1), .showCandidateWindow])
                        }
                    } else {
                        return .submitSelectedCandidate
                    }
                } else if direction == .left && event.modifierFlags.contains(.shift) {
                    self = .selecting(rangeAdjusted: true)
                    return .sequence([.moveCursor(-1), .showCandidateWindow])
                } else if direction == .down {
                    return .selectNextCandidate
                } else if direction == .up {
                    return .selectPrevCandidate
                } else {
                    return .consume
                }
            case .number(let num):
                switch num {
                case .one:
                    return .selectNumberCandidate(1)
                case .two:
                    return .selectNumberCandidate(2)
                case .three:
                    return .selectNumberCandidate(3)
                case .four:
                    return .selectNumberCandidate(4)
                case .five:
                    return .selectNumberCandidate(5)
                case .six:
                    return .selectNumberCandidate(6)
                case .seven:
                    return .selectNumberCandidate(7)
                case .eight:
                    return .selectNumberCandidate(8)
                case .nine:
                    return .selectNumberCandidate(9)
                case .zero:
                    return .appendToMarkedText("0")                }
            case .かな:
                return .selectInputMode(.japanese)
            case .英数:
                self = .none
                return .sequence([.submitSelectedCandidate, .selectInputMode(.roman)])
            case .unknown:
                return .fallthrough
            }
        }
    }
}
