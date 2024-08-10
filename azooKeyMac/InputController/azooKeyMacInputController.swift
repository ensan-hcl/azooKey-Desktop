//
//  azooKeyMacInputController.swift
//  azooKeyMacInputController
//
//  Created by ensan on 2021/09/07.
//

import OSLog
import Cocoa
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary

let applicationLogger: Logger = Logger(subsystem: "dev.ensan.inputmethod.azooKeyMac", category: "main")

@objc(azooKeyMacInputController)
class azooKeyMacInputController: IMKInputController {
    var segmentsManager: SegmentsManager
    private var inputState: InputState = .none
    private var directMode = false
    var zenzaiEnabled: Bool {
        Config.ZenzaiIntegration().value
    }
    var liveConversionEnabled: Bool {
        Config.LiveConversion().value
    }
    var englishConversionEnabled: Bool {
        Config.EnglishConversion().value
    }

    var appMenu: NSMenu
    var zenzaiToggleMenuItem: NSMenuItem
    var liveConversionToggleMenuItem: NSMenuItem
    var englishConversionToggleMenuItem: NSMenuItem

    private var candidatesWindow: NSWindow
    private var candidatesViewController: CandidatesViewController

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.segmentsManager = SegmentsManager()

        self.appMenu = NSMenu(title: "azooKey")
        self.zenzaiToggleMenuItem = NSMenuItem()
        self.liveConversionToggleMenuItem = NSMenuItem()
        self.englishConversionToggleMenuItem = NSMenuItem()

        // Initialize the candidates window
        self.candidatesViewController = CandidatesViewController()
        self.candidatesWindow = NSWindow(contentViewController: self.candidatesViewController)
        self.candidatesWindow.styleMask = [.borderless, .resizable]
        self.candidatesWindow.level = .popUpMenu

        var rect: NSRect = .zero
        if let client = inputClient as? IMKTextInput {
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        rect.size = .init(width: 400, height: 200)
        self.candidatesWindow.setFrame(rect, display: true)
        // init直後はこれを表示しない
        self.candidatesWindow.setIsVisible(false)
        self.candidatesWindow.orderOut(nil)
        super.init(server: server, delegate: delegate, client: inputClient)

        // デリゲートの設定を super.init の後に移動
        self.candidatesViewController.delegate = self
        self.segmentsManager.delegate = self
        self.setupMenu()
    }

    @MainActor
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        // アプリケーションサポートのディレクトリを準備しておく
        self.prepareApplicationSupportDirectory()
        self.updateZenzaiToggleMenuItem(newValue: self.zenzaiEnabled)
        self.updateLiveConversionToggleMenuItem(newValue: self.liveConversionEnabled)
        self.updateEnglishConversionToggleMenuItem(newValue: self.englishConversionEnabled)
        self.segmentsManager.activate()

        if let client = sender as? IMKTextInput {
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            var rect: NSRect = .zero
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            self.candidatesViewController.updateCandidates([], cursorLocation: rect.origin)
        } else {
            self.candidatesViewController.updateCandidates([], cursorLocation: .zero)
        }
        // activate直後はwindowをhideする
        self.hideCandidateWindow()
    }

    @MainActor
    override func deactivateServer(_ sender: Any!) {
        self.segmentsManager.deactivate()
        self.candidatesWindow.orderOut(nil)
        self.candidatesViewController.updateCandidates([], cursorLocation: .zero)
        if let client = sender as? IMKTextInput {
            client.insertText("", replacementRange: .notFound)
        }
        super.deactivateServer(sender)
    }

    @MainActor override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        if let value = value as? NSString {
            self.client()?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            self.directMode = value == "com.apple.inputmethod.Roman"
            if self.directMode {
                self.segmentsManager.stopJapaneseInput()
            }
        }
        super.setValue(value, forTag: tag, client: sender)
    }

    override func menu() -> NSMenu! {
        self.appMenu
    }

    private func isPrintable(_ text: String) -> Bool {
        let printable: CharacterSet = [.alphanumerics, .symbols, .punctuationCharacters]
            .reduce(into: CharacterSet()) {
                $0.formUnion($1)
            }
        return CharacterSet(text.unicodeScalars).isSubset(of: printable)
    }

    @MainActor override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else { return false }

        if event.type != .keyDown {
            return false
        }

        switch self.handleDirectMode(event, client: client) {
        case .done:
            return true
        case .break:
            return false
        case .continue:
            break
        }

        let userAction = InputMode.getUserAction(event: event)
        let clientAction = inputState.event(event, userAction: userAction)
        return handleClientAction(clientAction, client: client)
    }

    enum HandleDirectModeRequest {
        /// azooKey on macOS内部で入力をハンドルした場合
        case done

        /// azooKey on macOS内部で入力をハンドルしない場合
        case `break`

        /// directModeではなかった場合
        case `continue`
    }

    private func handleDirectMode(_ event: NSEvent, client: IMKTextInput) -> HandleDirectModeRequest {
        if self.directMode, event.keyCode == 93, !event.modifierFlags.contains(.shift) {
            switch (Config.TypeBackSlash().value, event.modifierFlags.contains(.option)) {
            case (true, false), (false, true):
                client.insertText("\\", replacementRange: .notFound)
            case (true, true), (false, false):
                client.insertText("¥", replacementRange: .notFound)
            }
            return .done
        } else if self.directMode, event.keyCode != 104 && event.keyCode != 102 {
            return .break
        }
        return .continue
    }

    func showCandidateWindow() {
        var rect: NSRect = .zero
        self.client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        self.candidatesViewController.updateCandidates(self.segmentsManager.candidates ?? [], cursorLocation: rect.origin)
        self.candidatesViewController.selectFirstCandidate()
        self.candidatesWindow.orderFront(nil)
    }

    func hideCandidateWindow() {
        self.candidatesWindow.setIsVisible(false)
        self.candidatesWindow.orderOut(nil)
    }

    @MainActor func handleClientAction(_ clientAction: ClientAction, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.showCandidateWindow()
        case .hideCandidateWindow:
            self.hideCandidateWindow()
        case .selectInputMode(let mode):
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            switch mode {
            case .roman:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                self.segmentsManager.stopJapaneseInput()
            case .japanese:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
            }
        case .enterCandidateSelectionMode:
            self.segmentsManager.update(requestRichCandidates: true)
            self.showCandidateWindow()
        case .appendToMarkedText(let string):
            self.hideCandidateWindow()
            self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
            self.refreshMarkedText()
        case .moveCursor(let value):
            self.segmentsManager.moveCursor(count: value)
        case .moveCursorToStart:
            self.segmentsManager.moveCursorToStart()
        case .commitMarkedText:
            let markedText = self.segmentsManager.getCurrentMarkedText(inputState: self.inputState)
            let text = markedText.reduce(into: "") {$0.append(contentsOf: $1.content)}
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            if let candidate = self.segmentsManager.candidates?.first(where: {$0.text == text}) {
                self.segmentsManager.candidateCommited(candidate)
            }
            self.segmentsManager.stopComposition()
            self.hideCandidateWindow()
        case .submitSelectedCandidate:
            self.candidatesViewController.confirmCandidateSelection()
        case .removeLastMarkedText:
            self.hideCandidateWindow()
            self.segmentsManager.deleteBackwardFromCursorPosition()
            if self.segmentsManager.isEmpty {
                self.inputState = .none
            }
            self.refreshMarkedText()
        case .consume:
            return true
        case .fallthrough:
            return false
        case .selectPrevCandidate:
            self.candidatesViewController.selectCandidate(offset: -1)
        case .selectNextCandidate:
            self.candidatesViewController.selectCandidate(offset: 1)
        case .selectNumberCandidate(let num):
            self.candidatesViewController.selectNumberCandidate(num: num)
            self.candidatesViewController.confirmCandidateSelection()
        case .stopComposition:
            self.segmentsManager.stopComposition()
            self.refreshMarkedText()
            self.hideCandidateWindow()
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
        self.segmentsManager.candidates?.map { $0.text } ?? []
    }

    func refreshMarkedText() {
        let highlight = self.mark(
            forStyle: kTSMHiliteSelectedConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let underline = self.mark(
            forStyle: kTSMHiliteConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let text = NSMutableAttributedString(string: "")
        let currentMarkedText = self.segmentsManager.getCurrentMarkedText(inputState: self.inputState)
        for part in currentMarkedText where !part.content.isEmpty {
            let attributes: [NSAttributedString.Key: Any]? = switch part.focus {
            case .focused: highlight
            case .unfocused: underline
            case .none: [:]
            }
            text.append(
                NSAttributedString(
                    string: part.content,
                    attributes: attributes
                )
            )
        }
        self.client()?.setMarkedText(
            text,
            selectionRange: currentMarkedText.selectionRange,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
    }
}

extension azooKeyMacInputController: CandidatesViewControllerDelegate {
    @MainActor func candidateSubmitted(_ candidate: Candidate) {
        self.inputState = .none
        if let client = self.client() {
            client.insertText(candidate.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            // アプリケーションサポートのディレクトリを準備しておく
            self.segmentsManager.candidateCommited(candidate)

            if self.segmentsManager.isEmpty {
                self.segmentsManager.stopComposition()
                self.candidatesViewController.clearCandidates()
                self.hideCandidateWindow()
            } else {
                self.inputState = .selecting(rangeAdjusted: false)
                client.setMarkedText(
                    NSAttributedString(string: self.segmentsManager.convertTarget, attributes: [:]),
                    selectionRange: .notFound,
                    replacementRange: NSRange(location: NSNotFound, length: 0)
                )
                self.showCandidateWindow()
            }
        }
    }

    @MainActor func candidateSelectionChanged(_ candidate: Candidate) {
        self.segmentsManager.requestUpdateMarkedText(selectedPrefixCandidate: candidate)
        self.refreshMarkedText()
    }
}

extension azooKeyMacInputController: SegmentManagerDelegate {
    func getLeftSideContext(maxCount: Int) -> String? {
        let endIndex = client().markedRange().location
        let leftRange = NSRange(location: max(endIndex - maxCount, 0), length: min(endIndex, maxCount))
        var actual = NSRange()
        // 同じ行の文字のみコンテキストに含める
        let leftSideContext = self.client().string(from: leftRange, actualRange: &actual)
        return leftSideContext
    }
}
