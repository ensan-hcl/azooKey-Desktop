import InputMethodKit

enum InputState {
    case none
    case composing
    case previewing
    case selecting

    // この種のコードは複雑にしかならないので、lintを無効にする
    // swiftlint:disable:next cyclomatic_complexity
    func event(_ event: NSEvent!, userAction: UserAction, liveConversionEnabled: Bool, enableDebugWindow: Bool) -> (ClientAction, ClientActionCallback) {
        if event.modifierFlags.contains(.command) {
            return (.fallthrough, .fallthrough)
        }
        if event.modifierFlags.contains(.option) {
            guard case .input = userAction else {
                return (.fallthrough, .fallthrough)
            }
        }
        switch self {
        case .none:
            switch userAction {
            case .input(let string):
                return (.appendToMarkedText(string), .transition(.composing))
            case .number(let number):
                return (.appendToMarkedText(number.inputString), .transition(.composing))
            case .かな:
                return (.selectInputMode(.japanese), .transition(.none))
            case .英数:
                return (.selectInputMode(.roman), .transition(.none))
            case .unknown, .navigation, .space, .backspace, .enter, .escape, .function:
                return (.fallthrough, .fallthrough)
            }
        case .composing:
            switch userAction {
            case .input(let string):
                return (.appendToMarkedText(string), .fallthrough)
            case .number(let number):
                return (.appendToMarkedText(number.inputString), .fallthrough)
            case .backspace:
                return (.removeLastMarkedText, .basedOnBackspace(ifIsEmpty: .none, ifIsNotEmpty: .composing))
            case .enter:
                return (.commitMarkedText, .transition(.none))
            case .escape:
                return (.stopComposition, .transition(.none))
            case .space:
                if liveConversionEnabled {
                    return (.enterCandidateSelectionMode, .transition(.selecting))
                } else {
                    return (.enterFirstCandidatePreviewMode, .transition(.previewing))
                }
            case let .function(function):
                switch function {
                case .six:
                    return (.submitHiraganaCandidate, .transition(.none))
                case .seven:
                    return (.submitKatakanaCandidate, .transition(.none))
                case .eight:
                    return (.submitHankakuKatakanaCandidate, .transition(.none))
                }
            case .かな:
                return (.selectInputMode(.japanese), .fallthrough)
            case .英数:
                return (.commitMarkedTextAndSelectInputMode(.roman), .transition(.none))
            case .navigation(let direction):
                if direction == .down {
                    return (.enterCandidateSelectionMode, .transition(.selecting))
                } else if direction == .right && event.modifierFlags.contains(.shift) {
                    return (.editSegment(1), .transition(.selecting))
                } else if direction == .left && event.modifierFlags.contains(.shift) {
                    return (.editSegment(-1), .transition(.selecting))
                } else {
                    // ナビゲーションはハンドルしてしまう
                    return (.consume, .fallthrough)
                }
            case .unknown:
                return (.fallthrough, .fallthrough)
            }
        case .previewing:
            switch userAction {
            case .input(let string):
                return (.commitMarkedTextAndAppendToMarkedText(string), .transition(.composing))
            case .number(let number):
                return (.appendToMarkedText(number.inputString), .transition(.composing))
            case .backspace:
                return (.removeLastMarkedText, .transition(.composing))
            case .enter:
                return (.commitMarkedText, .transition(.none))
            case .space:
                return (.enterCandidateSelectionMode, .transition(.selecting))
            case .escape:
                return (.hideCandidateWindow, .transition(.composing))
            case let .function(function):
                switch function {
                case .six:
                    return (.submitHiraganaCandidate, .transition(.none))
                case .seven:
                    return (.submitKatakanaCandidate, .transition(.none))
                case .eight:
                    return (.submitHankakuKatakanaCandidate, .transition(.none))
                }
            case .かな:
                return (.selectInputMode(.japanese), .fallthrough)
            case .英数:
                return (.commitMarkedTextAndSelectInputMode(.roman), .transition(.none))
            case .navigation(let direction):
                if direction == .down {
                    return (.enterCandidateSelectionMode, .transition(.selecting))
                } else if direction == .right && event.modifierFlags.contains(.shift) {
                    return (.editSegment(1), .transition(.selecting))
                } else if direction == .left && event.modifierFlags.contains(.shift) {
                    return (.editSegment(-1), .transition(.selecting))
                } else {
                    // ナビゲーションはハンドルしてしまう
                    return (.consume, .fallthrough)
                }
            case .unknown:
                return (.fallthrough, .fallthrough)
            }
        case .selecting:
            switch userAction {
            case .input(let string):
                if string == "d" && enableDebugWindow {
                    return (.enableDebugWindow, .fallthrough)
                } else if string == "D" && enableDebugWindow {
                    return (.disableDebugWindow, .fallthrough)
                }
                return (.commitMarkedTextAndAppendToMarkedText(string), .transition(.composing))
            case .enter:
                return (.submitSelectedCandidate, .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .previewing))
            case .backspace:
                return (.removeLastMarkedText, .basedOnBackspace(ifIsEmpty: .none, ifIsNotEmpty: .composing))
            case .escape:
                if liveConversionEnabled {
                    return (.hideCandidateWindow, .transition(.composing))
                } else {
                    return (.enterFirstCandidatePreviewMode, .transition(.previewing))
                }
            case .space:
                // シフトが入っている場合は上に移動する
                if event.modifierFlags.contains(.shift) {
                    return (.selectPrevCandidate, .fallthrough)
                } else {
                    return (.selectNextCandidate, .fallthrough)
                }
            case .navigation(let direction):
                if direction == .right {
                    if event.modifierFlags.contains(.shift) {
                        return (.editSegment(1), .fallthrough)
                    } else {
                        return (.submitSelectedCandidate, .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .selecting))
                    }
                } else if direction == .left && event.modifierFlags.contains(.shift) {
                    return (.editSegment(-1), .fallthrough)
                } else if direction == .down {
                    return (.selectNextCandidate, .fallthrough)
                } else if direction == .up {
                    return (.selectPrevCandidate, .fallthrough)
                } else {
                    return (.consume, .fallthrough)
                }
            case let .function(function):
                switch function {
                case .six:
                    return (.submitHiraganaCandidate, .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .selecting))
                case .seven:
                    return (.submitKatakanaCandidate, .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .selecting))
                case .eight:
                    return (.submitHankakuKatakanaCandidate, .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .selecting))
                }
            case .number(let num):
                switch num {
                case .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
                    return (.selectNumberCandidate(num.intValue), .basedOnSubmitCandidate(ifIsEmpty: .none, ifIsNotEmpty: .previewing))
                case .zero:
                    return (.submitSelectedCandidateAndAppendToMarkedText(num.inputString), .transition(.composing))
                }
            case .かな:
                return (.selectInputMode(.japanese), .fallthrough)
            case .英数:
                return (.commitMarkedTextAndSelectInputMode(.roman), .transition(.none))
            case .unknown:
                return (.fallthrough, .fallthrough)
            }
        }
    }
}
