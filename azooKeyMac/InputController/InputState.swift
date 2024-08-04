
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
            case .backspace:
                return .removeLastMarkedText
            case .enter:
                self = .none
                return .commitMarkedText
            case .escape:
                return .stopComposition
            case .space:
                self = .selecting(rangeAdjusted: false)
                return .showCandidateWindow
            case .かな:
                return .selectInputMode(.japanese)
            case .英数:
                self = .none
                return .sequence([.commitMarkedText, .selectInputMode(.roman)])
            case .navigation(let direction):
                if direction == .down {
                    self = .selecting(rangeAdjusted: false)
                    return .showCandidateWindow
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
                return .forwardToCandidateWindow(
                    .keyEvent(
                        with: .keyDown,
                        location: event.locationInWindow,
                        modifierFlags: event.modifierFlags,
                        timestamp: event.timestamp,
                        windowNumber: event.windowNumber,
                        context: nil,
                        characters: " ",
                        charactersIgnoringModifiers: " ",
                        isARepeat: event.isARepeat,
                        keyCode: 36
                    ) ?? event

                )
            case .backspace:
                self = .composing
                return .removeLastMarkedText
            case .escape:
                self = .composing
                return .hideCandidateWindow
            case .space:
                return .forwardToCandidateWindow(
                    .keyEvent(
                        with: .keyDown,
                        location: event.locationInWindow,
                        modifierFlags: event.modifierFlags,
                        timestamp: event.timestamp,
                        windowNumber: event.windowNumber,
                        context: nil,
                        characters: " ",
                        charactersIgnoringModifiers: " ",
                        isARepeat: event.isARepeat,
                        keyCode: 49
                    ) ?? event
                )
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
                } else {
                    return .forwardToCandidateWindow(event)
                }
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
