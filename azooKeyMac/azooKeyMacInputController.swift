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
    case ignore
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)
    case commitMarkedText
    case submitSelectedCandidate
    case insertText(String)
    case removeLastMarkedText
    case forwardToCandidateWindow(NSEvent)
    case nextCandidate
    case sequence([ClientAction])
}

enum InputState {
    case none
    case composing
    case selecting

    mutating func event(_ event: NSEvent!, userAction: UserAction) -> ClientAction {
        if event.modifierFlags.contains(.command) {
            return .ignore
        }
        switch self {
        case .none:
            switch userAction {
            case .input(let string):
                self = .composing
                return .appendToMarkedText(string)
            case .unknown, .navigation, .space, .delete, .enter:
                return .ignore
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
            case .unknown, .navigation:
                return .ignore
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
                return .nextCandidate
            case .navigation:
                return .forwardToCandidateWindow(event)
            case .unknown:
                return .ignore
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
        case 102: // Lang1
            self.inputState.event(event, userAction: .unknown)
        case 104: // Lang2
            self.inputState.event(event, userAction: .unknown)
        case 123: // Left
            self.inputState.event(event, userAction: .navigation(.left))
        case 124: // Right
            self.inputState.event(event, userAction: .navigation(.right))
        case 125: // Down
            self.inputState.event(event, userAction: .navigation(.down))
        case 126: // Up
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
                    self.inputState.event(event, userAction: .input("「 "))
                } else if text == "]" {
                    self.inputState.event(event, userAction: .input("」"))
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
        case .insertText(let string):
            client.insertText(string, replacementRange: .notFound)
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
        case .nextCandidate:
            self.candidatesWindow.selectCandidate(withIdentifier: self.candidatesWindow.selectedCandidate() + 1)
        case .ignore:
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
        return result.mainResults.map { $0.text }
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
            selectionRange: NSRange(location: self.selectionRange().location, length: candidateString.count),
            replacementRange: NSRange(location: self.selectionRange().location, length: candidateString.count)
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
