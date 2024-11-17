import InputMethodKit

enum ClientAction {
    case `consume`
    case `fallthrough`
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)

    /// Marked Textを経由せずにインサートするコマンド。InputStateがnoneの場合のみ有効
    case insertWithoutMarkedText(String)
    case removeLastMarkedText

    case commitMarkedText
    /// Shift+←→で選択範囲をエディットするコマンド
    case editSegment(Int)

    /// previwingに入るコマンド
    case enterFirstCandidatePreviewMode

    /// スペースを押して`.selecting`に入るコマンド
    case enterCandidateSelectionMode
    case submitSelectedCandidate
    case selectNextCandidate
    case selectPrevCandidate
    case selectNumberCandidate(Int)

    case selectInputMode(InputMode)
    case commitMarkedTextAndSelectInputMode(InputMode)
    /// MarkedTextを確定して、さらに追加で入力する
    case commitMarkedTextAndAppendToMarkedText(String)

    /// 現在選ばれている候補を確定して、さらに追加で入力する
    ///  - note:`commitMarkedTextAndAppendToMarkedText`はMarkedText全体を一度に確定するが、`submitSelectedCandidateAndAppendToMarkedText`の場合は部分的に確定されることがあるという違いがある
    case submitSelectedCandidateAndAppendToMarkedText(String)
    case submitSelectedCandidateAndEnterFirstCandidatePreviewMode

    /// デバッグウィンドウを表示するコマンド
    case enableDebugWindow
    case disableDebugWindow

    // Fnキーでの変換
    case submitKatakanaCandidate
    case submitHiraganaCandidate
    case submitHankakuKatakanaCandidate

    // Suggestion
    case requestSuggestion
    case requestReplaceSuggestion
    case submitSuggestion
    case selectNextSuggestionCandidate
    case submitSuggestionCandidate
    case hideSuggestCandidateWindow

    case stopComposition

    enum InputMode {
        case roman
        case japanese
    }
}

enum ClientActionCallback {
    case `fallthrough`
    case transition(InputState)
    ///
    case basedOnBackspace(ifIsEmpty: InputState, ifIsNotEmpty: InputState)
    case basedOnSubmitCandidate(ifIsEmpty: InputState, ifIsNotEmpty: InputState)
}
