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
    private var lastOperation: Operation = .other

    private enum Operation: Sendable {
        case insert
        case delete
        case moveCursor
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
        self.lastOperation = .other
        self.composingText.stopComposition()
    }

    @MainActor
    /// この入力を打ち切る
    func stopComposition() {
        self.composingText.stopComposition()
        self.kanaKanjiConverter.stopComposition()
        self.rawCandidates = nil
        self.lastOperation = .other
    }

    @MainActor
    /// 日本語入力自体をやめる
    func stopJapaneseInput() {
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
    func moveCursor(count: Int) {
        _ = self.composingText.moveCursorFromCursorPosition(count: count)
        if self.composingText.convertTargetCursorPosition == 0 {
            _ = self.composingText.moveCursorFromCursorPosition(count: 1)
        }
        self.lastOperation = .moveCursor
        self.updateRawCandidate()
    }

    @MainActor
    func deleteBackwardFromCursorPosition(count: Int = 1) {
        self.composingText.deleteBackwardFromCursorPosition(count: count)
        self.lastOperation = .delete
        self.updateRawCandidate()
    }

    @MainActor
    func moveCursorToStart() {
        _ = self.composingText.moveCursorFromCursorPosition(count: -self.composingText.convertTargetCursorPosition)
        self.updateRawCandidate()
    }

    var candidates: [Candidate]? {
        self.rawCandidates?.mainResults
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
        self.updateRawCandidate(requestRichCandidates: true)
    }

    @MainActor func candidateCommited(_ candidate: Candidate) {
        self.kanaKanjiConverter.setCompletedData(candidate)
        self.kanaKanjiConverter.updateLearningData(candidate)
        self.composingText.prefixComplete(correspondingCount: candidate.correspondingCount)

        if !self.composingText.isEmpty {
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
