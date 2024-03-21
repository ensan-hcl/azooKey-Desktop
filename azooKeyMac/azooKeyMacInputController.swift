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
    case 英数
    case かな
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
    case removeLastMarkedText
    case moveCursorToStart
    case moveCursor(Int)

    enum DefaultInitialPosition {
        case end
    }

    case commitMarkedText
    case submitSelectedCandidate
    case forwardToCandidateWindow(NSEvent)
    case selectInputMode(InputMode)

    enum InputMode {
        case roman
        case japanese
    }

    case sequence([ClientAction])
}

enum InputState {
    case none
    case composing
    /// 変換範囲をユーザが調整したか
    case selecting(rangeAdjusted: Bool)

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
            case .かな:
                return .selectInputMode(.japanese)
            case .英数:
                return .selectInputMode(.roman)
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

@objc(azooKeyMacInputController)
class azooKeyMacInputController: IMKInputController {
    private var composingText: ComposingText = ComposingText()
    private var selectedCandidate: String? = nil
    private var inputState: InputState = .none
    private var candidatesWindow: IMKCandidates = IMKCandidates()
    private var directMode = false
    private var liveConversionEnabled: Bool {
        if let value = UserDefaults.standard.value(forKey: "dev.ensan.inputmethod.azooKeyMac.preference.enableLiveConversion") {
            value as? Bool ?? true
        } else {
            true
        }
    }
    private var displayedTextInComposingMode: String? = nil
    @MainActor private var kanaKanjiConverter = KanaKanjiConverter()
    private var rawCandidates: ConversionResult? = nil
    private let appMenu: NSMenu
    private let liveConversionToggleMenuItem: NSMenuItem

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        // menu
        self.appMenu = NSMenu(title: "azooKey")
        self.liveConversionToggleMenuItem = NSMenuItem(title: "ライブ変換をOFF", action: #selector(self.toggleLiveConversion(_:)), keyEquivalent: "")
        self.appMenu.addItem(self.liveConversionToggleMenuItem)
        self.appMenu.addItem(NSMenuItem(title: "View on GitHub", action: #selector(self.openGitHubRepository(_:)), keyEquivalent: ""))
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        guard let value = value as? NSString else {
            return
        }
        self.directMode = value == "com.apple.inputmethod.Roman"
    }

    override func menu() -> NSMenu! {
        self.appMenu
    }

    @objc private func toggleLiveConversion(_ sender: Any) {
        UserDefaults.standard.set(!self.liveConversionEnabled, forKey: "dev.ensan.inputmethod.azooKeyMac.preference.enableLiveConversion")
        self.liveConversionToggleMenuItem.title = if self.liveConversionEnabled {
             "ライブ変換をOFF"
        } else {
            "ライブ変換をON"
        }
    }

    @objc private func openGitHubRepository(_ sender: Any) {
        guard let url = URL(string: "https://github.com/ensan-hcl/azooKey-Desktop") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        if event.type != .keyDown && event.type != .flagsChanged {
            return false
        }
        // 入力モードの切り替え以外は無視
        if self.directMode {
            if event.keyCode != 104 && event.keyCode != 102 {
                return false
            }
        }
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        // https://developer.mozilla.org/ja/docs/Web/API/UI_Events/Keyboard_event_code_values#mac_%E3%81%A7%E3%81%AE%E3%82%B3%E3%83%BC%E3%83%89%E5%80%A4
        let clientAction = switch event.keyCode {
        case 36: // Enter
            self.inputState.event(event, userAction: .enter)
        case 48: // Tab
            self.inputState.event(event, userAction: .unknown)
        case 49: // Space
            self.inputState.event(event, userAction: .space)
        case 51: // Delete
            self.inputState.event(event, userAction: .delete)
        case 53: // Escape
            self.inputState.event(event, userAction: .unknown)
        case 102: // Lang2/kVK_JIS_Eisu
            self.inputState.event(event, userAction: .英数)
        case 104: // Lang1/kVK_JIS_Kana
            self.inputState.event(event, userAction: .かな)
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
        self.candidatesWindow.perform(Selector(("setWindowLevel:")), with: NSWindow.Level.screenSaver.rawValue)
        self.candidatesWindow.becomeFirstResponder()
    }

    @MainActor func handleClientAction(_ clientAction: ClientAction, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.showCandidateWindow()
        case .hideCandidateWindow:
            self.candidatesWindow.hide()
        case .selectInputMode(let mode):
            switch mode {
            case .roman: 
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
            case .japanese:
                 client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
            }
        case .appendToMarkedText(let string):
            self.candidatesWindow.hide()
            self.composingText.insertAtCursorPosition(string, inputStyle: .roman2kana)
            self.updateRawCandidate()
            // Live Conversion
            let text = if self.liveConversionEnabled, let firstCandidate = self.rawCandidates?.mainResults.first {
                firstCandidate.text
            } else {
                self.composingText.convertTarget
            }
            self.updateMarkedTextInComposingMode(text: text, client: client)
        case .moveCursor(let value):
            _ = self.composingText.moveCursorFromCursorPosition(count: value)
            self.updateRawCandidate()
        case .moveCursorToStart:
            _ = self.composingText.moveCursorFromCursorPosition(count: -self.composingText.convertTargetCursorPosition)
            self.updateRawCandidate()
        case .commitMarkedText:
            client.insertText(self.displayedTextInComposingMode ?? self.composingText.convertTarget, replacementRange: .notFound)
            self.composingText.stopComposition()
            self.candidatesWindow.hide()
            self.displayedTextInComposingMode = nil
        case .submitSelectedCandidate:
            let candidateString = self.selectedCandidate ?? self.composingText.convertTarget
            client.insertText(candidateString, replacementRange: .notFound)
            guard let candidate = self.rawCandidates?.mainResults.first(where: {$0.text == candidateString}) else {
                self.composingText.stopComposition()
                return true
            }
            self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)
            self.selectedCandidate = nil
            if self.composingText.isEmpty {
                self.composingText.stopComposition()
                self.candidatesWindow.hide()
            } else {
                self.inputState = .selecting(rangeAdjusted: false)
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
            self.updateMarkedTextInComposingMode(text: self.composingText.convertTarget, client: client)
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

    @MainActor private func updateRawCandidate() {
        let prefixComposingText = self.composingText.prefixToCursorPosition()
        let options = ConvertRequestOptions.withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(string: "none")!, sharedContainerURL: URL(string: "none")!, metadata: .init(appVersionString: "1.0"))
        let result = self.kanaKanjiConverter.requestCandidates(prefixComposingText, options: options)
        self.rawCandidates = result
    }

    /// function to provide candidates
    /// - returns: `[String]`
    @MainActor override func candidates(_ sender: Any!) -> [Any]! {
        self.updateRawCandidate()
        return self.rawCandidates?.mainResults.map { $0.text } ?? []
    }

    /// selecting modeの場合はこの関数は使わない
    func updateMarkedTextInComposingMode(text: String, client: IMKTextInput) {
        self.displayedTextInComposingMode = text
        client.setMarkedText(
            NSAttributedString(string: text, attributes: [:]),
            selectionRange: .notFound,
            replacementRange: .notFound
        )
    }

    /// selecting modeでのみ利用する
    @MainActor
    func updateMarkedTextWithCandidate(_ candidateString: String) {
        guard let candidate = self.rawCandidates?.mainResults.first(where: {$0.text == candidateString}) else {
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
