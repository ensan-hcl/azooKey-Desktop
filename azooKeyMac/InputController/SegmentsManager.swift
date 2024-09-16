//
//  SegmentsManager.swift
//  azooKeyMac
//
//  Created by miwa on 2024/08/10.
//

import Foundation
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary

private final actor DebugCandidatesManager {
    var candidates: [Candidate] = []

    func insert(_ candidate: Candidate) {
        self.candidates.insert(candidate, at: 0)
        while self.candidates.count > 100 {
            self.candidates.removeLast()
        }
    }
}

final actor SegmentsManager {
    init() {}

    private weak var delegate: (any SegmentManagerDelegate)?

    private var composingText: ComposingText = ComposingText()

    private var zenzaiEnabled: Bool {
        Config.ZenzaiIntegration().value
    }
    private var liveConversionEnabled: Bool {
        Config.LiveConversion().value
    }
    private var englishConversionEnabled: Bool {
        Config.EnglishConversion().value
    }
    private var rawCandidates: ConversionResult?

    private var selectionIndex: Int?
    private var didExperienceSegmentEdition = false
    private var lastOperation: Operation = .other
    private var shouldShowCandidateWindow = false

    private var shouldShowDebugCandidateWindow: Bool = false
//    private var debugCandidates: [Candidate] = []
    private var debugCandidateManager = DebugCandidatesManager()

    private enum Operation: Sendable {
        case insert
        case delete
        case editSegment
        case other
    }

    @MainActor private var kanaKanjiConverter: KanaKanjiConverter {
        (
            NSApplication.shared.delegate as? AppDelegate
        )!.kanaKanjiConverter
    }

    func setDelegate(delegate: (any SegmentManagerDelegate)?) {
        self.delegate = delegate
    }

    nonisolated func appendDebugMessage(_ string: String) {
        Task {
            await self.debugCandidateManager.insert(
                Candidate(
                    text: string.replacingOccurrences(of: "\n", with: "\\n"),
                    value: 0,
                    correspondingCount: 0,
                    lastMid: 0,
                    data: []
                )
            )
        }
    }

    private func zenzaiMode(leftSideContext: String?, requestRichCandidates: Bool) -> ConvertRequestOptions.ZenzaiMode {
        if self.zenzaiEnabled {
            return .on(
                weight: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/zenz-v2-Q5_K_M.gguf", isDirectory: false),
                inferenceLimit: Config.ZenzaiInferenceLimit().value,
                requestRichCandidates: requestRichCandidates,
                versionDependentMode: .v2(
                    .init(
                        profile: Config.ZenzaiProfile().value,
                        leftSideContext: leftSideContext
                    )
                )
            )
        } else {
            return .off
        }
    }

    private func options(leftSideContext: String? = nil, requestRichCandidates: Bool = false) -> ConvertRequestOptions {
        .withDefaultDictionary(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            englishCandidateInRoman2KanaInput: self.englishConversionEnabled,
            learningType: Config.Learning().value.learningType,
            memoryDirectoryURL: self.azooKeyMemoryDir,
            sharedContainerURL: self.azooKeyMemoryDir,
            zenzaiMode: self.zenzaiMode(leftSideContext: leftSideContext, requestRichCandidates: requestRichCandidates),
            metadata: .init(versionString: "azooKey on macOS / α version")
        )
    }

    nonisolated var azooKeyMemoryDir: URL {
        if #available(macOS 13, *) {
            URL.applicationSupportDirectory
                .appending(path: "azooKey", directoryHint: .isDirectory)
                .appending(path: "memory", directoryHint: .isDirectory)
        } else {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("azooKey", isDirectory: true)
                .appendingPathComponent("memory", isDirectory: true)
        }
    }

    func activate() async {
        self.shouldShowCandidateWindow = false
        let options = self.options()
        await self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options))
    }

    func deactivate() async {
        await self.kanaKanjiConverter.stopComposition()
        let options = self.options()
        await self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options))
        await self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
        self.rawCandidates = nil
        self.didExperienceSegmentEdition = false
        self.lastOperation = .other
        self.composingText.stopComposition()
        self.shouldShowCandidateWindow = false
        self.selectionIndex = nil
    }

    /// この入力を打ち切る
    func stopComposition() async {
        self.composingText.stopComposition()
        await self.kanaKanjiConverter.stopComposition()
        self.rawCandidates = nil
        self.didExperienceSegmentEdition = false
        self.lastOperation = .other
        self.shouldShowCandidateWindow = false
        self.selectionIndex = nil
    }

    /// 日本語入力自体をやめる
    func stopJapaneseInput() async {
        self.rawCandidates = nil
        self.didExperienceSegmentEdition = false
        self.lastOperation = .other
        await self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
        self.shouldShowCandidateWindow = false
        self.selectionIndex = nil
    }

    func insertAtCursorPosition(_ string: String, inputStyle: InputStyle) async {
        self.composingText.insertAtCursorPosition(string, inputStyle: inputStyle)
        self.lastOperation = .insert
        // ライブ変換がオフの場合は変換候補ウィンドウを出したい
        self.shouldShowCandidateWindow = !self.liveConversionEnabled
        await self.updateRawCandidate()
    }

    func editSegment(count: Int) async {
        // 現在選ばれているprefix candidateが存在する場合、まずそれに合わせてカーソルを移動する
        if let selectionIndex, let candidates, candidates.indices.contains(selectionIndex) {
            var afterComposingText = self.composingText
            afterComposingText.prefixComplete(correspondingCount: candidates[selectionIndex].correspondingCount)
            let prefixCount = self.composingText.convertTarget.count - afterComposingText.convertTarget.count
            _ = self.composingText.moveCursorFromCursorPosition(count: -self.composingText.convertTargetCursorPosition + prefixCount)
        }
        if count > 0 {
            if self.composingText.isAtEndIndex && !self.didExperienceSegmentEdition {
                // 現在のカーソルが右端にある場合、左端の次に移動する
                _ = self.composingText.moveCursorFromCursorPosition(count: -self.composingText.convertTargetCursorPosition + count)
            } else {
                // それ以外の場合、右に広げる
                _ = self.composingText.moveCursorFromCursorPosition(count: count)
            }
        } else {
            _ = self.composingText.moveCursorFromCursorPosition(count: count)
        }
        if self.composingText.isAtStartIndex {
            // 最初にある場合は一つ右に進める
            _ = self.composingText.moveCursorFromCursorPosition(count: 1)
        }
        self.lastOperation = .editSegment
        self.didExperienceSegmentEdition = true
        self.shouldShowCandidateWindow = true
        self.selectionIndex = nil
        await self.updateRawCandidate()
    }

    func deleteBackwardFromCursorPosition(count: Int = 1) async {
        if !self.composingText.isAtEndIndex {
            // 右端に持っていく
            _ = self.composingText.moveCursorFromCursorPosition(count: self.composingText.convertTarget.count - self.composingText.convertTargetCursorPosition)
            // 一度segmentの編集状態もリセットにする
            self.didExperienceSegmentEdition = false
        }
        self.composingText.deleteBackwardFromCursorPosition(count: count)
        self.lastOperation = .delete
        // ライブ変換がオフの場合は変換候補ウィンドウを出したい
        self.shouldShowCandidateWindow = !self.liveConversionEnabled
        await self.updateRawCandidate()
    }

    private var candidates: [Candidate]? {
        if let rawCandidates {
            if !self.didExperienceSegmentEdition {
                if rawCandidates.firstClauseResults.lazy.map({$0.correspondingCount}).max() == rawCandidates.mainResults.lazy.map({$0.correspondingCount}).max() {
                    // firstClauseCandidateがmainResultsと同じサイズの場合は、何もしない方が良い
                    return rawCandidates.mainResults
                } else {
                    // 変換範囲がエディットされていない場合
                    let seenAsFirstClauseResults = rawCandidates.firstClauseResults.mapSet(transform: \.text)
                    return rawCandidates.firstClauseResults + rawCandidates.mainResults.filter {
                        !seenAsFirstClauseResults.contains($0.text)
                    }
                }
            } else {
                return rawCandidates.mainResults
            }
        } else {
            return nil
        }
    }

    var convertTarget: String {
        self.composingText.convertTarget
    }

    var isEmpty: Bool {
        self.composingText.isEmpty
    }

    private func updateRawCandidate(requestRichCandidates: Bool = false) async {
        // 不要
        if composingText.isEmpty {
            self.rawCandidates = nil
            await self.kanaKanjiConverter.stopComposition()
            return
        }

        let prefixComposingText = self.composingText.prefixToCursorPosition()
        var leftSideContext = self.delegate?.getLeftSideContext(maxCount: 30)
        leftSideContext = leftSideContext.map {
            var last = $0.split(separator: "\n", omittingEmptySubsequences: false).last ?? $0[...]
            // 空白を削除する
            while last.first?.isWhitespace ?? false {
                last = last.dropFirst()
            }
            while last.last?.isWhitespace ?? false {
                last = last.dropLast()
            }
            return String(last)
        }
        let result = await self.kanaKanjiConverter.requestCandidates(prefixComposingText, options: options(leftSideContext: leftSideContext, requestRichCandidates: requestRichCandidates))
        self.rawCandidates = result
    }

    func update(requestRichCandidates: Bool) async {
        await self.updateRawCandidate(requestRichCandidates: requestRichCandidates)
        self.shouldShowCandidateWindow = true
    }

    func prefixCandidateCommited(_ candidate: Candidate) async {
        await self.kanaKanjiConverter.setCompletedData(candidate)
        await self.kanaKanjiConverter.updateLearningData(candidate)
        self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)

        if !self.composingText.isEmpty {
            // カーソルを右端に移動する
            _ = self.composingText.moveCursorFromCursorPosition(count: self.composingText.convertTarget.count - self.composingText.convertTargetCursorPosition)
            self.didExperienceSegmentEdition = false
            self.shouldShowCandidateWindow = true
            self.selectionIndex = nil
            await self.updateRawCandidate()
        }
    }

    enum CandidateWindow: Sendable {
        case hidden
        case composing([Candidate], selectionIndex: Int?)
        case selecting([Candidate], selectionIndex: Int?)
    }

    func requestSetCandidateWindowState(visible: Bool) {
        self.shouldShowCandidateWindow = visible
    }

    func requestDebugWindowMode(enabled: Bool) {
        self.shouldShowDebugCandidateWindow = enabled
    }

    func requestSelectingNextCandidate() {
        self.selectionIndex = (self.selectionIndex ?? -1) + 1
    }

    func requestSelectingPrevCandidate() {
        self.selectionIndex = max(0, (self.selectionIndex ?? 1) - 1)
    }

    func requestSelectingRow(_ index: Int) {
        self.selectionIndex = max(0, index)
    }

    func requestResettingSelection() {
        self.selectionIndex = nil
    }

    var selectedCandidate: Candidate? {
        if let selectionIndex, let candidates, candidates.indices.contains(selectionIndex) {
            return candidates[selectionIndex]
        }
        return nil
    }

    func getCurrentCandidateWindow(inputState: InputState) async -> CandidateWindow {
        switch inputState {
        case .none, .previewing:
            return .hidden
        case .composing:
            if !self.liveConversionEnabled, let firstCandidate = self.rawCandidates?.mainResults.first {
                return .composing([firstCandidate], selectionIndex: 0)
            } else {
                return .hidden
            }
        case .selecting:
            if self.shouldShowDebugCandidateWindow {
                let debugCandidates = await self.debugCandidateManager.candidates
                self.selectionIndex = max(0, min(self.selectionIndex ?? 0, debugCandidates.count - 1))
                return .selecting(debugCandidates, selectionIndex: self.selectionIndex)
            } else if self.shouldShowCandidateWindow, let candidates, !candidates.isEmpty {
                self.selectionIndex = max(0, min(self.selectionIndex ?? 0, candidates.count - 1))
                return .selecting(candidates, selectionIndex: self.selectionIndex)
            } else {
                return .hidden
            }
        }
    }

    struct MarkedText: Sendable, Equatable, Hashable, Sequence {
        enum FocusState: Sendable, Equatable, Hashable {
            case focused
            case unfocused
            case none
        }

        struct Element: Sendable, Equatable, Hashable {
            var content: String
            var focus: FocusState
        }
        var text: [Element]

        var selectionRange: NSRange

        func makeIterator() -> Array<Element>.Iterator {
            text.makeIterator()
        }
    }

    func getModifiedRubyCandidate(_ transform: (String) -> String) -> Candidate {
        let ruby = if let selectedCandidate {
            // `selectedCandidate.data` の全ての `ruby` を連結して返す
            selectedCandidate.data.map { element in
                element.ruby
            }.joined()
        } else {
            // 選択範囲なしの場合はconvertTargetを返す
            self.composingText.convertTarget
        }
        let candidateText = transform(ruby)
        let candidate = if let selectedCandidate {
            {
                var candidate = selectedCandidate
                candidate.text = candidateText
                return candidate
            }()
        } else {
            Candidate(
                text: candidateText,
                value: 0,
                correspondingCount: composingText.input.count,
                lastMid: 0,
                data: [DicdataElement(
                    word: candidateText,
                    ruby: ruby,
                    cid: CIDData.固有名詞.cid,
                    mid: MIDData.一般.mid,
                    value: 0
                )]
            )
        }

        return candidate
    }

    func commitMarkedText(inputState: InputState) async -> String {
        let markedText = self.getCurrentMarkedText(inputState: inputState)
        let text = markedText.reduce(into: "") {$0.append(contentsOf: $1.content)}
        if let candidate = self.candidates?.first(where: {$0.text == text}) {
            await self.prefixCandidateCommited(candidate)
        }
        await self.stopComposition()
        return text
    }

    func getCurrentMarkedText(inputState: InputState) -> MarkedText {
        switch inputState {
        case .none, .composing:
            let text = if self.lastOperation == .delete {
                // 削除のあとは常にひらがなを示す
                self.composingText.convertTarget
            } else if self.liveConversionEnabled,
                      self.composingText.convertTarget.count > 1,
                      let firstCandidate = self.rawCandidates?.mainResults.first {
                // それ以外の場合、ライブ変換が有効なら
                firstCandidate.text
            } else {
                // それ以外
                self.composingText.convertTarget
            }
            return MarkedText(text: [.init(content: text, focus: .none)], selectionRange: .notFound)
        case .previewing:
            if let fullCandidate = self.rawCandidates?.mainResults.first, fullCandidate.correspondingCount == self.composingText.input.count {
                return MarkedText(text: [.init(content: fullCandidate.text, focus: .none)], selectionRange: .notFound)
            } else {
                return MarkedText(text: [.init(content: self.composingText.convertTarget, focus: .none)], selectionRange: .notFound)
            }
        case .selecting:
            if let candidates, !candidates.isEmpty {
                self.selectionIndex = min(self.selectionIndex ?? 0, candidates.count - 1)
                var afterComposingText = self.composingText
                afterComposingText.prefixComplete(correspondingCount: candidates[self.selectionIndex!].correspondingCount)
                return MarkedText(
                    text: [
                        .init(content: candidates[self.selectionIndex!].text, focus: .focused),
                        .init(content: afterComposingText.convertTarget, focus: .unfocused)
                    ],
                    selectionRange: NSRange(location: candidates[self.selectionIndex!].text.count, length: 0)
                )
            } else {
                return MarkedText(text: [.init(content: self.composingText.convertTarget, focus: .none)], selectionRange: .notFound)
            }
        }
    }
}

protocol SegmentManagerDelegate: AnyObject {
    func getLeftSideContext(maxCount: Int) -> String?
}
