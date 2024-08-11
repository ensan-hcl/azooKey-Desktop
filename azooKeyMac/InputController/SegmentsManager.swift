//
//  SegmentsManager.swift
//  azooKeyMac
//
//  Created by miwa on 2024/08/10.
//

import Foundation
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary

final class SegmentsManager {
    init() {}

    weak var delegate: (any SegmentManagerDelegate)?

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

    private var selectedPrefixCandidate: Candidate?
    private var didExperienceSegmentEdition = false
    private var lastOperation: Operation = .other

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

    var azooKeyMemoryDir: URL {
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

    @MainActor
    func activate() {
        self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options()))
    }

    @MainActor
    func deactivate() {
        self.kanaKanjiConverter.stopComposition()
        self.kanaKanjiConverter.sendToDicdataStore(.setRequestOptions(options()))
        self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
        self.rawCandidates = nil
        self.selectedPrefixCandidate = nil
        self.didExperienceSegmentEdition = false
        self.lastOperation = .other
        self.composingText.stopComposition()
    }

    @MainActor
    /// この入力を打ち切る
    func stopComposition() {
        self.composingText.stopComposition()
        self.kanaKanjiConverter.stopComposition()
        self.rawCandidates = nil
        self.didExperienceSegmentEdition = false
        self.selectedPrefixCandidate = nil
        self.lastOperation = .other
    }

    @MainActor
    /// 日本語入力自体をやめる
    func stopJapaneseInput() {
        self.selectedPrefixCandidate = nil
        self.rawCandidates = nil
        self.didExperienceSegmentEdition = false
        self.lastOperation = .other
        self.kanaKanjiConverter.sendToDicdataStore(.closeKeyboard)
    }

    @MainActor
    func insertAtCursorPosition(_ string: String, inputStyle: InputStyle) {
        self.composingText.insertAtCursorPosition(string, inputStyle: inputStyle)
        self.lastOperation = .insert
        self.updateRawCandidate()
    }

    @MainActor
    func editSegment(count: Int) {
        // 現在選ばれているprefix candidateが存在する場合、まずそれに合わせてカーソルを移動する
        if let selectedPrefixCandidate {
            var afterComposingText = self.composingText
            afterComposingText.prefixComplete(correspondingCount: selectedPrefixCandidate.correspondingCount)
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
        self.updateRawCandidate()
    }

    @MainActor
    func deleteBackwardFromCursorPosition(count: Int = 1) {
        if !self.composingText.isAtEndIndex {
            // 右端に持っていく
            _ = self.composingText.moveCursorFromCursorPosition(count: self.composingText.convertTarget.count - self.composingText.convertTargetCursorPosition)
            // 一度segmentの編集状態もリセットにする
            self.didExperienceSegmentEdition = false
        }
        self.composingText.deleteBackwardFromCursorPosition(count: count)
        self.lastOperation = .delete
        self.updateRawCandidate()
    }

    var candidates: [Candidate]? {
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

    @MainActor private func updateRawCandidate(requestRichCandidates: Bool = false) {
        // 不要
        if composingText.isEmpty {
            self.rawCandidates = nil
            self.kanaKanjiConverter.stopComposition()
            return
        }

        let prefixComposingText = self.composingText.prefixToCursorPosition()
        let leftSideContext = self.delegate?.getLeftSideContext(maxCount: 30).map {
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
        let result = self.kanaKanjiConverter.requestCandidates(prefixComposingText, options: options(leftSideContext: leftSideContext, requestRichCandidates: requestRichCandidates))
        self.rawCandidates = result
    }

    @MainActor func update(requestRichCandidates: Bool) {
        self.updateRawCandidate(requestRichCandidates: requestRichCandidates)
    }

    @MainActor func prefixCandidateCommited(_ candidate: Candidate) {
        self.kanaKanjiConverter.setCompletedData(candidate)
        self.kanaKanjiConverter.updateLearningData(candidate)
        self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)

        if !self.composingText.isEmpty {
            // カーソルを右端に移動する
            _ = self.composingText.moveCursorFromCursorPosition(count: self.composingText.convertTarget.count - self.composingText.convertTargetCursorPosition)
            self.didExperienceSegmentEdition = false
            self.updateRawCandidate()
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
            return text.makeIterator()
        }
    }

    func requestUpdateMarkedText(selectedPrefixCandidate: Candidate) {
        self.selectedPrefixCandidate = selectedPrefixCandidate
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
        case .selecting:
            if let selectedPrefixCandidate {
                var afterComposingText = self.composingText
                afterComposingText.prefixComplete(correspondingCount: selectedPrefixCandidate.correspondingCount)

                return MarkedText(
                    text: [
                        .init(content: selectedPrefixCandidate.text, focus: .focused),
                        .init(content: afterComposingText.convertTarget, focus: .unfocused)
                    ],
                    selectionRange: NSRange(location: selectedPrefixCandidate.text.count, length: 0)
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
