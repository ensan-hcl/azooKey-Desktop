//
//  azooKeyMacInputController.swift
//  azooKeyMacInputController
//
//  Created by ensan on 2021/09/07.
//

import Cocoa
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary
import OSLog

@objc(azooKeyMacInputController)
class azooKeyMacInputController: IMKInputController { // swiftlint:disable:this type_name
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

    private var suggestionWindow: NSWindow
    private var suggestionController: SuggestionViewController

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.segmentsManager = SegmentsManager()

        self.appMenu = NSMenu(title: "azooKey")
        self.zenzaiToggleMenuItem = NSMenuItem()
        self.liveConversionToggleMenuItem = NSMenuItem()
        self.englishConversionToggleMenuItem = NSMenuItem()

        // Initialize the candidates window
        self.candidatesViewController = CandidatesViewController()
        self.candidatesWindow = NSWindow(contentViewController: self.candidatesViewController)
        self.candidatesWindow.styleMask = [.borderless]
        self.candidatesWindow.level = .popUpMenu

        var rect: NSRect = .zero
        if let client = inputClient as? IMKTextInput {
            client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        }
        rect.size = .init(width: 400, height: 1000)
        self.candidatesWindow.setFrame(rect, display: true)
        // init直後はこれを表示しない
        self.candidatesWindow.setIsVisible(false)
        self.candidatesWindow.orderOut(nil)

        // SuggestionControllerの初期化
        self.suggestionController = SuggestionViewController()
        self.suggestionWindow = NSWindow(contentViewController: self.suggestionController)

        // 背景を透過させる設定
        self.suggestionWindow.isOpaque = false
        self.suggestionWindow.backgroundColor = NSColor.clear
        self.suggestionWindow.hasShadow = false

        // その他のウィンドウスタイル設定
        self.suggestionWindow.styleMask = [.borderless, .resizable]
        self.suggestionWindow.title = "Suggestion"
        self.suggestionWindow.setContentSize(NSSize(width: 400, height: 1000))
        self.suggestionWindow.center()
        self.suggestionWindow.orderOut(nil)
        self.suggestionWindow.level = .popUpMenu

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
            self.candidatesViewController.updateCandidates([], selectionIndex: nil, cursorLocation: rect.origin)
        } else {
            self.candidatesViewController.updateCandidates([], selectionIndex: nil, cursorLocation: .zero)
        }
        self.refreshCandidateWindow()
    }

    @MainActor
    override func deactivateServer(_ sender: Any!) {
        self.segmentsManager.deactivate()
        self.candidatesWindow.orderOut(nil)
        self.suggestionWindow.orderOut(nil)
        self.candidatesViewController.updateCandidates([], selectionIndex: nil, cursorLocation: .zero)
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
        return handleClientAction(clientAction, clientActionCallback: clientActionCallback, client: client)
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
    @MainActor func handleClientAction(_ clientAction: ClientAction, clientActionCallback: ClientActionCallback, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.segmentsManager.requestSetCandidateWindowState(visible: true)
        case .hideCandidateWindow:
            self.segmentsManager.requestSetCandidateWindowState(visible: false)
        case .selectInputMode(let mode):
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            switch mode {
            case .roman:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                self.segmentsManager.stopJapaneseInput()
            case .japanese:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
            }
        case .enterFirstCandidatePreviewMode:
            self.segmentsManager.requestSetCandidateWindowState(visible: false)
        case .enterCandidateSelectionMode:
            self.segmentsManager.update(requestRichCandidates: true)
        case .appendToMarkedText(let string):
            self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
        case .insertWithoutMarkedText(let string):
            assert(self.inputState == .none)
            client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        case .editSegment(let count):
            self.segmentsManager.editSegment(count: count)
        case .commitMarkedText:
            let text = self.segmentsManager.commitMarkedText(inputState: self.inputState)
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            self.segmentsManager.stopComposition()
        case .commitMarkedTextAndAppendToMarkedText(let string):
            let text = self.segmentsManager.commitMarkedText(inputState: self.inputState)
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            self.segmentsManager.stopComposition()
            self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
        case .commitMarkedTextAndSelectInputMode(let mode):
            let text = self.segmentsManager.commitMarkedText(inputState: self.inputState)
            client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
            self.segmentsManager.stopComposition()
            client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
            switch mode {
            case .roman:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Roman")
                self.segmentsManager.stopJapaneseInput()
            case .japanese:
                client.selectMode("dev.ensan.inputmethod.azooKeyMac.Japanese")
            }
        case .submitSelectedCandidate:
            self.submitSelectedCandidate()
        case .submitSelectedCandidateAndAppendToMarkedText(let string):
            self.submitSelectedCandidate()
            self.segmentsManager.insertAtCursorPosition(string, inputStyle: .roman2kana)
        case .submitSelectedCandidateAndEnterFirstCandidatePreviewMode:
            self.submitSelectedCandidate()
            self.segmentsManager.requestSetCandidateWindowState(visible: false)
        case .removeLastMarkedText:
            self.segmentsManager.deleteBackwardFromCursorPosition()
            self.segmentsManager.requestResettingSelection()
        case .selectPrevCandidate:
            self.segmentsManager.requestSelectingPrevCandidate()
        case .selectNextCandidate:
            self.segmentsManager.requestSelectingNextCandidate()
        case .selectNumberCandidate(let num):
            self.candidatesViewController.selectNumberCandidate(num: num)
            self.submitSelectedCandidate()
        case .submitHiraganaCandidate:
            self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                $0.toHiragana()
            })
        case .submitKatakanaCandidate:
            self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                $0.toKatakana()
            })
        case .submitHankakuKatakanaCandidate:
            self.submitCandidate(self.segmentsManager.getModifiedRubyCandidate {
                $0.toKatakana().applyingTransform(.fullwidthToHalfwidth, reverse: false)!
            })
        case .enableDebugWindow:
            self.segmentsManager.requestDebugWindowMode(enabled: true)
        case .disableDebugWindow:
            self.segmentsManager.requestDebugWindowMode(enabled: false)
        case .stopComposition:
            self.segmentsManager.stopComposition()
        case .requestSuggestion:
            // configの有効化をチェック
            if Config.EnableOpenAiApiKey().value && Config.OpenAiApiKey().value.isEmpty == false {
                self.requestSuggestion()
            }
        case .submitSuggestion:
            if Config.EnableOpenAiApiKey().value && Config.OpenAiApiKey().value.isEmpty == false {
                self.submitSelectedSuggestion()
            }
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
            // 遷移した時にSuggestionViewをhideする
            if inputState != .suggestion {
                hideSuggestion()
            }
            self.inputState = inputState
        case .basedOnBackspace(let ifIsEmpty, let ifIsNotEmpty), .basedOnSubmitCandidate(let ifIsEmpty, let ifIsNotEmpty):
            self.inputState = self.segmentsManager.isEmpty ? ifIsEmpty : ifIsNotEmpty
            if self.inputState != .none {
                self.hideSuggestion()
            }
        }

        self.refreshMarkedText()
        self.refreshCandidateWindow()
        return true
    }

    func refreshCandidateWindow() {
        switch self.segmentsManager.getCurrentCandidateWindow(inputState: self.inputState) {
        case .selecting(let candidates, let selectionIndex):
            var rect: NSRect = .zero
            self.client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            self.candidatesViewController.showCandidateIndex = true
            self.candidatesViewController.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: rect.origin)
            self.candidatesWindow.orderFront(nil)
        case .composing(let candidates, let selectionIndex):
            var rect: NSRect = .zero
            self.client().attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
            self.candidatesViewController.showCandidateIndex = false
            self.candidatesViewController.updateCandidates(candidates, selectionIndex: selectionIndex, cursorLocation: rect.origin)
            self.candidatesWindow.orderFront(nil)
        case .hidden:
            self.candidatesWindow.setIsVisible(false)
            self.candidatesWindow.orderOut(nil)
            self.candidatesViewController.hide()
        }
    }

    // azooKeyMacInputController.swift
    @MainActor
    func hideSuggestion() {
        self.suggestionWindow.setIsVisible(false)
        self.suggestionWindow.orderOut(nil)
    }

    var retryCount = 0
    let maxRetries = 3

    @MainActor func requestSuggestion() {
        // Show Suggestion window
        self.suggestionWindow.orderFront(nil)
        self.suggestionWindow.makeKeyAndOrderFront(nil)

        var rect: NSRect = .zero
        self.client()?.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        let cursorPosition = rect.origin
        self.suggestionController.displayStatusText("...", cursorPosition: cursorPosition)

        // Get the text from getLeftSideContext
        guard let prompt = self.getLeftSideContext(maxCount: 100), !prompt.isEmpty else {
            // Display an error message if the prompt cannot be retrieved
            self.segmentsManager.appendDebugMessage("プロンプト取得失敗")

            // 再実行の上限をチェック
            if retryCount < maxRetries {
                retryCount += 1
                // 再実行
                self.suggestionController.displayStatusText("." + String(repeating: ".", count: 5), cursorPosition: cursorPosition)
                self.segmentsManager.appendDebugMessage("再試行中... (\(retryCount)回目)")
                // 0.5秒待って再実行する
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.requestSuggestion()
                }
            } else {
                self.segmentsManager.appendDebugMessage("再試行上限に達しました。")
            }
            retryCount = 0
            return
        }

        self.segmentsManager.appendDebugMessage("prompt \(prompt)")

        // Show Suggestion window
        self.suggestionWindow.makeKeyAndOrderFront(nil)
        self.suggestionController.displayStatusText("...", cursorPosition: cursorPosition)
        self.segmentsManager.appendDebugMessage("リクエスト中...")

        // Get the OpenAI API key
        let apiKey = Config.OpenAiApiKey().value

        // Create the request
        let request = OpenAIRequest(prompt: prompt)

        // Asynchronously send API request
        Task {
            do {
                // Send API request
                let predictions = try await OpenAIClient.sendRequest(request, apiKey: apiKey, segmentsManager: segmentsManager)

                // Format and display structured output
                let formattedResponse = predictions

                // Display response in Suggestion
                await MainActor.run {
                    // 一番の候補のみ表示
                    self.segmentsManager.appendDebugMessage("frame \(rect.size)")
                    self.suggestionController.displayCandidate(formattedResponse[0], cursorPosition: cursorPosition, fontSize: rect.size.height)
                }
            } catch {
                // Handle errors
                await MainActor.run {
                    let errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                    var rect: NSRect = .zero
                    self.client()?.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
                    let cursorPosition = rect.origin
                    self.suggestionController.displayStatusText(errorMessage, cursorPosition: cursorPosition)
                    self.segmentsManager.appendDebugMessage(errorMessage)
                }
            }

        }
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

    @MainActor
    func submitSelectedSuggestion() {
        // SuggestionControllerから選択された候補を取得
        if let selectedCandidate = suggestionController.getSelectedCandidate() {
            if let client = self.client() {
                // 選択された候補をテキスト入力に挿入
                client.insertText(selectedCandidate, replacementRange: NSRange(location: NSNotFound, length: 0))
                // ウィンドウを非表示にする
                self.hideSuggestion()
            }
        }
    }

    @MainActor
    func submitCandidate(_ candidate: Candidate) {
        if let client = self.client() {
            client.insertText(candidate.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            // アプリケーションサポートのディレクトリを準備しておく
            self.segmentsManager.prefixCandidateCommited(candidate)
        }
    }

    @MainActor
    func submitSelectedCandidate() {
        if let candidate = self.segmentsManager.selectedCandidate {
            self.submitCandidate(candidate)
            self.segmentsManager.requestResettingSelection()
        }
    }
}

extension azooKeyMacInputController: CandidatesViewControllerDelegate {
    @MainActor func candidateSubmitted() {
        self.submitSelectedCandidate()
    }

    @MainActor func candidateSelectionChanged(_ row: Int) {
        self.segmentsManager.requestSelectingRow(row)
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
