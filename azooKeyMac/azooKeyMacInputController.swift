//
//  azooKeyMacInputController.swift
//  azooKeyMacInputController
//
//  Created by ensan on 2021/09/07.
//

import Cocoa
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary

enum UserAction {
    case input(String)
    case delete
    case enter
    case space
    case unknown
    case navigation(NavigationDirection)

    enum NavigationDirection {
        case up, down, right, left
    }
}

indirect enum ClientAction {
    case `consume`
    case `fallthrough`
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)
    case commitMarkedText
    case submitSelectedCandidate
    case removeLastMarkedText
    case forwardToCandidateWindow(NSEvent)
    case sequence([ClientAction])
}

enum InputState {
    case none
    case composing
    case selecting

    mutating func event(_ event: NSEvent!, userAction: UserAction) -> ClientAction {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            return .fallthrough
        }
        switch self {
        case .none:
            switch userAction {
            case .input(let string):
                self = .composing
                return .appendToMarkedText(string)
            case .unknown, .navigation, .space, .delete, .enter:
                return .fallthrough
            }
        case .composing:
            switch userAction {
            case .input(let string):
                return .appendToMarkedText(string)
            case .delete:
                return .removeLastMarkedText
            case .enter:
                self = .none
                return .commitMarkedText
            case .space:
                self = .selecting
                return .showCandidateWindow
            case .navigation(let direction):
                if direction == .down {
                    self = .selecting
                    return .showCandidateWindow
                } else {
                    // ナビゲーションはハンドルしてしまう
                    return .consume
                }
            case .unknown:
                return .fallthrough
            }
        case .selecting:
            switch userAction {
            case .input(let string):
                self = .composing
                return .sequence([.submitSelectedCandidate, .appendToMarkedText(string)])
            case .enter:
                self = .none
                return .submitSelectedCandidate
            case .delete:
                self = .composing
                return .removeLastMarkedText
            case .space:
                // Spaceは下矢印キーに、Shift + Spaceは上矢印キーにマップする
                // 下矢印キー: \u{F701} / 125
                // 上矢印キー: \u{F700} / 126
                let (keyCode, characters) = if event.modifierFlags.contains(.shift) {
                    (126 as UInt16, "\u{F700}")
                } else {
                    (125 as UInt16, "\u{F701}")
                }
                // 下矢印キーを押した場合と同等のイベントを作って送信する
                return .forwardToCandidateWindow(
                    .keyEvent(
                        with: .keyDown,
                        location: event.locationInWindow,
                        modifierFlags: event.modifierFlags.subtracting(.shift),  // シフトは除去する
                        timestamp: event.timestamp,
                        windowNumber: event.windowNumber,
                        context: nil,
                        characters: characters,
                        charactersIgnoringModifiers: characters,
                        isARepeat: event.isARepeat,
                        keyCode: keyCode
                    ) ?? event
                )
            case .navigation:
                return .forwardToCandidateWindow(event)
            case .unknown:
                return .fallthrough
            }
        }
    }
}

@objc(azooKeyMacInputController)
class azooKeyMacInputController: IMKInputController {
    private var composingText: ComposingText = ComposingText()
    private var selectedCandidate: String? = nil
    private var inputState: InputState = .none
    private var candidatesWindow: IMKCandidates = IMKCandidates()
    @MainActor private var kanaKanjiConverter = KanaKanjiConverter()
    @MainActor private var rawCandidates: [Candidate] = []

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    @MainActor override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        let clientAction = switch event.keyCode {
        case 36: // Enter
            self.inputState.event(event, userAction: .enter)
        case 49: // Space
            self.inputState.event(event, userAction: .space)
        case 51: // Delete
            self.inputState.event(event, userAction: .delete)
        case 53: // Escape
            self.inputState.event(event, userAction: .unknown)
        case 102: // Lang1
            self.inputState.event(event, userAction: .unknown)
        case 104: // Lang2
            self.inputState.event(event, userAction: .unknown)
        case 123: // Left
            // uF702
            self.inputState.event(event, userAction: .navigation(.left))
        case 124: // Right
            // uF703
            self.inputState.event(event, userAction: .navigation(.right))
        case 125: // Down
            // uF701
            self.inputState.event(event, userAction: .navigation(.down))
        case 126: // Up
            // uF700
            self.inputState.event(event, userAction: .navigation(.up))
        default:
            if let text = event.characters {
                if text == "." {
                    self.inputState.event(event, userAction: .input("。"))
                } else if text == "," {
                    self.inputState.event(event, userAction: .input("、"))
                } else if text == "!" {
                    self.inputState.event(event, userAction: .input("！"))
                } else if text == "?" {
                    self.inputState.event(event, userAction: .input("？"))
                } else if text == "~" {
                    self.inputState.event(event, userAction: .input("〜"))
                } else if text == "-" {
                    self.inputState.event(event, userAction: .input("ー"))
                } else if text == "(" {
                    self.inputState.event(event, userAction: .input("（"))
                } else if text == ")" {
                    self.inputState.event(event, userAction: .input("）"))
                } else if text == "[" {
                    self.inputState.event(event, userAction: .input("「"))
                } else if text == "]" {
                    self.inputState.event(event, userAction: .input("」"))
                } else if text == "{" {
                    self.inputState.event(event, userAction: .input("『"))
                } else if text == "}" {
                    self.inputState.event(event, userAction: .input("』"))
                } else if text == "/" {
                    self.inputState.event(event, userAction: .input("・"))
                } else {
                    self.inputState.event(event, userAction: .input(text))
                }
            } else {
                self.inputState.event(event, userAction: .input(event.keyCode.description))
            }
        }
        return self.handleClientAction(clientAction, client: client)
    }

    func showCandidateWindow() {
        self.candidatesWindow.update()
        self.candidatesWindow.show()
        // MARK: this is required to move the window front of the spotlight panel
        self.candidatesWindow.perform(Selector(("setWindowLevel:")), with: NSWindow.Level.screenSaver)
        self.candidatesWindow.becomeFirstResponder()
    }

    @MainActor func handleClientAction(_ clientAction: ClientAction, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.showCandidateWindow()
        case .hideCandidateWindow:
            self.candidatesWindow.hide()
        case .appendToMarkedText(let string):
            self.candidatesWindow.hide()
            self.composingText.insertAtCursorPosition(string, inputStyle: .roman2kana)
            client.setMarkedText(
                NSAttributedString(string: self.composingText.convertTarget, attributes: [:]),
                selectionRange: .notFound,
                replacementRange: .notFound
            )
        case .commitMarkedText:
            client.insertText(self.composingText.convertTarget, replacementRange: .notFound)
            self.composingText.stopComposition()
            self.candidatesWindow.hide()
        case .submitSelectedCandidate:
            let candidateString = self.selectedCandidate ?? self.composingText.convertTarget
            client.insertText(candidateString, replacementRange: .notFound)
            guard let candidate = self.rawCandidates.first(where: {$0.text == candidateString}) else {
                self.composingText.stopComposition()
                return true
            }
            self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)
            self.selectedCandidate = nil
            if self.composingText.isEmpty {
                self.composingText.stopComposition()
                self.candidatesWindow.hide()
            } else {
                self.inputState = .selecting
                client.setMarkedText(
                    NSAttributedString(string: self.composingText.convertTarget, attributes: [:]),
                    selectionRange: .notFound,
                    replacementRange: .notFound
                )
                self.showCandidateWindow()
            }
        case .removeLastMarkedText:
            self.candidatesWindow.hide()
            self.composingText.deleteBackwardFromCursorPosition(count: 1)
            client.setMarkedText(
                NSAttributedString(string: self.composingText.convertTarget, attributes: [:]),
                selectionRange: .notFound,
                replacementRange: .notFound
            )
            if self.composingText.isEmpty {
                self.inputState = .none
            }
        case .consume:
            return true
        case .fallthrough:
            return false
        case .forwardToCandidateWindow(let event):
            self.candidatesWindow.interpretKeyEvents([event])
        case .sequence(let actions):
            var found = false
            for action in actions {
                if self.handleClientAction(action, client: client) {
                    found = true
                }
            }
            return found
        }
        return true
    }

    /// function to provide candidates
    /// - returns: `[String]`
    @MainActor override func candidates(_ sender: Any!) -> [Any]! {
        let options = ConvertRequestOptions.withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(string: "none")!, sharedContainerURL: URL(string: "none")!, metadata: .init(appVersionString: "1.0"))
        let result = self.kanaKanjiConverter.requestCandidates(composingText, options: options)
        self.rawCandidates = result.mainResults
        return self.rawCandidates.map { $0.text }
    }

    @MainActor
    func updateMarkedTextWithCandidate(_ candidateString: String) {
        guard let candidate = self.rawCandidates.first(where: {$0.text == candidateString}) else {
            return
        }
        var afterComposingText = self.composingText
        afterComposingText.prefixComplete(correspondingCount: candidate.correspondingCount)
        self.client()?.setMarkedText(
            NSAttributedString(string: candidateString + afterComposingText.convertTarget, attributes: [:]),
            selectionRange: NSRange(location: candidateString.count, length: 0),
            replacementRange: .notFound
        )
     }

    @MainActor override func candidateSelected(_ candidateString: NSAttributedString!) {
        self.updateMarkedTextWithCandidate(candidateString.string)
        self.selectedCandidate = candidateString.string
    }

    @MainActor override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        self.updateMarkedTextWithCandidate(candidateString.string)
        self.selectedCandidate = candidateString.string
    }
}
