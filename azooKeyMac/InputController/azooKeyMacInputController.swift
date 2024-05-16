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
    private var composingText: ComposingText = ComposingText()
    private var selectedCandidate: String?
    private var inputState: InputState = .none
    private var directMode = false

    var liveConversionEnabled: Bool {
        Config.LiveConversion().value
    }

    var englishConversionEnabled: Bool {
        Config.EnglishConversion().value
    }

    var appMenu: NSMenu
    var liveConversionToggleMenuItem: NSMenuItem
    var englishConversionToggleMenuItem: NSMenuItem

    private var displayedTextInComposingMode: String?
    private var candidatesWindow: IMKCandidates {
        (
            NSApplication.shared.delegate as? AppDelegate
        )!.candidatesWindow
    }
    @MainActor private var kanaKanjiConverter: KanaKanjiConverter {
        (
            NSApplication.shared.delegate as? AppDelegate
        )!.kanaKanjiConverter
    }
    private var rawCandidates: ConversionResult?
    private var options: ConvertRequestOptions {
        .withDefaultDictionary(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            englishCandidateInRoman2KanaInput: self.englishConversionEnabled,
            learningType: Config.Learning().value.learningType,
            memoryDirectoryURL: self.azooKeyMemoryDir,
            sharedContainerURL: self.azooKeyMemoryDir,
            metadata: .init(appVersionString: "1.0")
        )
    }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.appMenu = NSMenu(title: "azooKey")
        self.liveConversionToggleMenuItem = NSMenuItem()
        self.englishConversionToggleMenuItem = NSMenuItem()
        super.init(server: server, delegate: delegate, client: inputClient)
        self.setupMenu()
    }

    @MainActor
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        // MARK: this is required to move the window front of the spotlight panel
        self.candidatesWindow.perform(
            Selector(("setWindowLevel:")),
            with: Int(max(
                CGShieldingWindowLevel(),
                kCGPopUpMenuWindowLevel
            ))
        )
        // アプリケーションサポートのディレクトリを準備しておく
        self.prepareApplicationSupportDirectory()
        self.updateLiveConversionToggleMenuItem(newValue: self.liveConversionEnabled)
        self.updateEnglishConversionToggleMenuItem(newValue: self.englishConversionEnabled)
        self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options))
        if let client = sender as? IMKTextInput {
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
        }
    }

    @MainActor
    override func deactivateServer(_ sender: Any!) {
        self.kanaKanjiConverter.stopComposition()
        self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options))
        self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
        self.candidatesWindow.hide()
        self.rawCandidates = nil
        self.displayedTextInComposingMode = nil
        self.composingText.stopComposition()
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
                self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
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

        if handleDirectMode(event, client: client) {
            return true
        }

        let userAction = InputMode.getUserAction(event: event)
        let clientAction = inputState.event(event, userAction: userAction)
        return handleClientAction(clientAction, client: client)
    }

    private func handleDirectMode(_ event: NSEvent, client: IMKTextInput) -> Bool {
        if self.directMode, event.keyCode == 93, !event.modifierFlags.contains(.shift) {
            switch (Config.TypeBackSlash().value, event.modifierFlags.contains(.option)) {
            case (true, false), (false, true):
                client.insertText("\\", replacementRange: .notFound)
            case (true, true), (false, false):
                client.insertText("¥", replacementRange: .notFound)
            }
            return true
        } else if self.directMode, event.keyCode != 104 && event.keyCode != 102 {
            return false
        }
        return false
    }

    func showCandidateWindow() {
        self.candidatesWindow.update()
        self.candidatesWindow.show()
    }

    @MainActor func handleClientAction(_ clientAction: ClientAction, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.showCandidateWindow()
        case .hideCandidateWindow:
            self.candidatesWindow.hide()
        case .selectInputMode(let mode):
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            switch mode {
            case .roman:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
            case .japanese:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
            }
        case .appendToMarkedText(let string):
            self.candidatesWindow.hide()
            self.composingText.insertAtCursorPosition(string, inputStyle: .roman2kana)
            self.updateRawCandidate()
            // Live Conversion
            let text = if self.liveConversionEnabled, self.composingText.convertTarget.count > 1, let firstCandidate = self.rawCandidates?.mainResults.first {
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
            let candidateString = self.displayedTextInComposingMode ?? self.composingText.convertTarget
            client.insertText(self.displayedTextInComposingMode ?? self.composingText.convertTarget, replacementRange: NSRange(location: NSNotFound, length: 0))
            if let candidate = self.rawCandidates?.mainResults.first(where: {$0.text == candidateString}) {
                self.update(with: candidate)
            }
            self.kanaKanjiConverter.stopComposition()
            self.composingText.stopComposition()
            self.candidatesWindow.hide()
            self.displayedTextInComposingMode = nil
        case .submitSelectedCandidate:
            let candidateString = self.selectedCandidate ?? self.composingText.convertTarget
            client.insertText(candidateString, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard let candidate = self.rawCandidates?.mainResults.first(where: {$0.text == candidateString}) else {
                self.kanaKanjiConverter.stopComposition()
                self.composingText.stopComposition()
                self.rawCandidates = nil
                return true
            }
            // アプリケーションサポートのディレクトリを準備しておく
            self.update(with: candidate)
            self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)

            self.selectedCandidate = nil
            if self.composingText.isEmpty {
                self.rawCandidates = nil
                self.kanaKanjiConverter.stopComposition()
                self.composingText.stopComposition()
                self.candidatesWindow.hide()
            } else {
                self.inputState = .selecting(rangeAdjusted: false)
                self.updateRawCandidate()
                client.setMarkedText(
                    NSAttributedString(string: self.composingText.convertTarget, attributes: [:]),
                    selectionRange: .notFound,
                    replacementRange: NSRange(location: NSNotFound, length: 0)
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
            replacementRange: NSRange(location: NSNotFound, length: 0)
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
        // これを使うことで文節単位変換の際に変換対象の文節の色が変わる
        let highlight = self.mark(
            forStyle: kTSMHiliteSelectedConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let underline = self.mark(
            forStyle: kTSMHiliteConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let text = NSMutableAttributedString(string: "")
        text.append(NSAttributedString(string: candidateString, attributes: highlight))
        text.append(NSAttributedString(string: afterComposingText.convertTarget, attributes: underline))
        self.client()?.setMarkedText(
            text,
            selectionRange: NSRange(location: candidateString.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
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

    @MainActor private func update(with candidate: Candidate) {
        self.kanaKanjiConverter.setCompletedData(candidate)
        self.kanaKanjiConverter.updateLearningData(candidate)
    }
}
