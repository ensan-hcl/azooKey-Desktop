//
//  azooKeyMacInputController.swift
//  azooKeyMacInputController
//
//  Created by ensan on 2021/09/07.
//

import Cocoa
@preconcurrency import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary
import OSLog

@objc(azooKeyMacInputController)
class azooKeyMacInputController: IMKInputController, @unchecked Sendable { // swiftlint:disable:this type_name
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

    private var candidatesWindow: NSWindow!
    private var candidatesViewController: CandidatesViewController!

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.segmentsManager = SegmentsManager()

        self.appMenu = NSMenu(title: "azooKey")
        self.zenzaiToggleMenuItem = NSMenuItem()
        self.liveConversionToggleMenuItem = NSMenuItem()
        self.englishConversionToggleMenuItem = NSMenuItem()

        // Initialize the candidates window
        self.candidatesViewController = nil
        self.candidatesWindow = nil
        super.init(server: server, delegate: delegate, client: inputClient)

        // Get window's default rect size
        var rect: NSRect = .zero
        if let client = inputClient as? IMKTextInput {
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        rect.size = .init(width: 400, height: 200)

        Task {
            await self.postInit(windowFrame: rect)
        }
    }

    private func postInit(windowFrame: NSRect) async {
        let initializedCandidateViewer = Task { @MainActor in
            let candidatesViewController = CandidatesViewController()
            let candidatesWindow = NSWindow(contentViewController: candidatesViewController)
            candidatesWindow.styleMask = [.borderless, .resizable]
            candidatesWindow.level = .popUpMenu
            candidatesWindow.setFrame(windowFrame, display: true)
            // init直後はこれを表示しない
            candidatesWindow.setIsVisible(false)
            candidatesWindow.orderOut(nil)

            self.candidatesWindow = candidatesWindow
            self.candidatesViewController = candidatesViewController
            // デリゲートの設定を super.init の後に移動
            self.candidatesViewController.setDelegate(delegate: self)
            await self.segmentsManager.setDelegate(delegate: self)
            self.setupMenu()
        }
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        // アプリケーションサポートのディレクトリを準備しておく
        self.prepareApplicationSupportDirectory()
        self.updateZenzaiToggleMenuItem(newValue: self.zenzaiEnabled)
        self.updateLiveConversionToggleMenuItem(newValue: self.liveConversionEnabled)
        self.updateEnglishConversionToggleMenuItem(newValue: self.englishConversionEnabled)
        let rectOrigin: CGPoint = {
            if let client = sender as? IMKTextInput {
                client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
                var rect: NSRect = .zero
                client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
                return rect.origin
            } else {
                return .zero
            }
        }()
        Task { @MainActor in
            await self.segmentsManager.activate()
            await self.candidatesViewController.updateCandidates([], selectionIndex: nil, cursorLocation: rectOrigin)
            await self.refreshCandidateWindow()
        }
    }

    override func deactivateServer(_ sender: sending Any!) {
        Task {
            await self.segmentsManager.deactivate()
            await self.candidatesWindow.orderOut(nil)
            await self.candidatesViewController.updateCandidates([], selectionIndex: nil, cursorLocation: .zero)
            if let client = sender as? IMKTextInput {
                client.insertText("", replacementRange: .notFound)
            }
            super.deactivateServer(sender)
        }
    }

    override func setValue(_ value: Any!, forTag tag: Int, client sender: Any!) {
        if let value = value as? NSString {
            self.client()?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            self.directMode = value == "com.apple.inputmethod.Roman"
            if self.directMode {
                Task {
                    await self.segmentsManager.stopJapaneseInput()
                }
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

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else {
            return false
        }

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
        let (clientAction, clientActionCallback) = inputState.event(
            event,
            userAction: userAction,
            liveConversionEnabled: Config.LiveConversion().value,
            enableDebugWindow: Config.DebugWindow().value
        )

        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        // 非同期タスクを作成
        Task { @MainActor in
            let taskResult = await self.handleClientAction(clientAction, clientActionCallback: clientActionCallback, client: client)
            result = taskResult
            semaphore.signal() // タスクが完了したらセマフォを解放
        }
        semaphore.wait() // タスクが完了するまで待機
        return result
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

    // この種のコードは複雑にしかならないので、lintを無効にする
    // swiftlint:disable:next cyclomatic_complexity
    func handleClientAction(
        _ clientAction: ClientAction,
        clientActionCallback: ClientActionCallback,
        client: sending IMKTextInput
    ) async -> Bool {
            // return only false
            switch clientAction {
            case .showCandidateWindow:
                await self.segmentsManager.requestSetCandidateWindowState(visible: true)
            case .hideCandidateWindow:
                await self.segmentsManager.requestSetCandidateWindowState(visible: false)
            case .selectInputMode(let mode):
                client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
                switch mode {
                case .roman:
                    client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                    await self.segmentsManager.stopJapaneseInput()
                case .japanese:
                    client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
                }
            case .enterFirstCandidatePreviewMode:
                await self.segmentsManager.requestSetCandidateWindowState(visible: false)
            case .enterCandidateSelectionMode:
                await self.segmentsManager.update(requestRichCandidates: true)
            case .appendToMarkedText(let string):
                await self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
            case .insertWithoutMarkedText(let string):
                assert(self.inputState == .none)
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
            case .editSegment(let count):
                await self.segmentsManager.editSegment(count: count)
            case .commitMarkedText:
                let text = await self.segmentsManager.commitMarkedText(inputState: self.inputState)
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                await self.segmentsManager.stopComposition()
            case .commitMarkedTextAndAppendToMarkedText(let string):
                let text = await self.segmentsManager.commitMarkedText(inputState: self.inputState)
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                await self.segmentsManager.stopComposition()
                await self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
            case .commitMarkedTextAndSelectInputMode(let mode):
                let text = await self.segmentsManager.commitMarkedText(inputState: self.inputState)
                client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
                await self.segmentsManager.stopComposition()
                client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
                switch mode {
                case .roman:
                    client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                    await self.segmentsManager.stopJapaneseInput()
                case .japanese:
                    client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
                }
            case .submitSelectedCandidate:
                await self.submitSelectedCandidate()
            case .submitSelectedCandidateAndAppendToMarkedText(let string):
                await self.submitSelectedCandidate()
                await self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
            case .submitSelectedCandidateAndEnterFirstCandidatePreviewMode:
                await self.submitSelectedCandidate()
                await self.segmentsManager.requestSetCandidateWindowState(visible: false)
            case .removeLastMarkedText:
                await self.segmentsManager.deleteBackwardFromCursorPosition()
                await self.segmentsManager.requestResettingSelection()
            case .selectPrevCandidate:
                await self.segmentsManager.requestSelectingPrevCandidate()
            case .selectNextCandidate:
                await self.segmentsManager.requestSelectingNextCandidate()
            case .selectNumberCandidate(let num):
                await self.candidatesViewController.selectNumberCandidate(num: num)
                await self.submitSelectedCandidate()
            case .submitHiraganaCandidate:
                await self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                    $0.toHiragana()
                })
            case .submitKatakanaCandidate:
                await self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                    $0.toKatakana()
                })
            case .submitHankakuKatakanaCandidate:
                await self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                    $0.toKatakana().applyingTransform(.fullwidthToHalfwidth, reverse: false)!
                })
            case .enableDebugWindow:
                await self.segmentsManager.requestDebugWindowMode(enabled: true)
            case .disableDebugWindow:
                await self.segmentsManager.requestDebugWindowMode(enabled: false)
            case .stopComposition:
                await self.segmentsManager.stopComposition()
                // MARK: 特殊ケース
            case .consume:
                return true
            case .fallthrough:
                return false
            }

            switch clientActionCallback {
            case .fallthrough:
                break
            case .transition(let inputState):
                self.inputState = inputState
            case .basedOnBackspace(let ifIsEmpty, let ifIsNotEmpty), .basedOnSubmitCandidate(let ifIsEmpty, let ifIsNotEmpty):
                self.inputState = await self.segmentsManager.isEmpty ? ifIsEmpty : ifIsNotEmpty
            }

            await self.refreshMarkedText()
            await self.refreshCandidateWindow()
            return true
    }

    @MainActor
    func refreshCandidateWindow() async {
        switch await self.segmentsManager.getCurrentCandidateWindow(inputState: self.inputState) {
        case .selecting(let candidates, let selectionIndex):
            var rect: NSRect = .zero
            self.client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            self.candidatesViewController.showCandidateIndex = true
            await self.candidatesViewController.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: rect.origin)
            self.candidatesWindow.orderFront(nil)
        case .composing(let candidates, let selectionIndex):
            var rect: NSRect = .zero
            self.client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            self.candidatesViewController.showCandidateIndex = false
            await self.candidatesViewController.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: rect.origin)
            self.candidatesWindow.orderFront(nil)
        case .hidden:
            self.candidatesWindow.setIsVisible(false)
            self.candidatesWindow.orderOut(nil)
            self.candidatesViewController.hide()
        }
    }

    func refreshMarkedText() async {
        let highlight = self.mark(
            forStyle: kTSMHiliteSelectedConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let underline = self.mark(
            forStyle: kTSMHiliteConvertedText,
            at: NSRange(location: NSNotFound, length: 0)
        ) as? [NSAttributedString.Key: Any]
        let text = NSMutableAttributedString(string: "")
        let currentMarkedText = await self.segmentsManager.getCurrentMarkedText(inputState: self.inputState)
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

    func submitCandidate(_ candidate: Candidate) async {
        if let client = self.client() {
            client.insertText(candidate.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            // アプリケーションサポートのディレクトリを準備しておく
            await self.segmentsManager.prefixCandidateCommited(candidate)
        }
    }

    func submitSelectedCandidate() async {
        if let candidate = await self.segmentsManager.selectedCandidate {
            await self.submitCandidate(candidate)
            await self.segmentsManager.requestResettingSelection()
        }
    }
}

extension azooKeyMacInputController: CandidatesViewControllerDelegate {
    func candidateSubmitted() async {
        await self.submitSelectedCandidate()
    }

    func candidateSelectionChanged(_ row: Int) async {
        await self.segmentsManager.requestSelectingRow(row)
    }
}

extension azooKeyMacInputController: SegmentManagerDelegate {
    func getLeftSideContext(maxCount: Int) -> String? {
        let endIndex = client().markedRange().location
        let leftRange = NSRange(location: max(endIndex - maxCount, 0), length: min(endIndex, maxCount))
        var actual = NSRange()
        // 同じ行の文字のみコンテキストに含める
        let leftSideContext = self.client().string(from: leftRange, actualRange: &actual)
        self.segmentsManager.appendDebugMessage("\(#function): leftSideContext=\(leftSideContext ?? "nil")")
        return leftSideContext
    }
}
