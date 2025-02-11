import Cocoa

class PredictiveSuggestionCandidateView: NSView {
    private let textField: NSTextField
    private let statusLabel: NSTextField
    private var currentCandidate: String = ""
    private var rectHeight: CGFloat = 16 // デフォルト値

    override init(frame frameRect: NSRect) {
        self.textField = NSTextField()
        self.statusLabel = NSTextField()
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.textField = NSTextField()
        self.statusLabel = NSTextField()
        super.init(coder: decoder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    private func setupView() {
        // TextFieldのセットアップ
        self.textField.isEditable = false
        self.textField.isBordered = false
        self.textField.backgroundColor = NSColor.clear
        self.textField.font = NSFont.systemFont(ofSize: 16)
        self.textField.alignment = .left
        self.textField.translatesAutoresizingMaskIntoConstraints = false

        self.statusLabel.isEditable = false
        self.statusLabel.isBordered = false
        self.statusLabel.backgroundColor = NSColor.clear
        self.statusLabel.font = NSFont.systemFont(ofSize: 16)
        self.statusLabel.textColor = NSColor.white
        self.statusLabel.alignment = .left
        self.statusLabel.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.textField)
        self.addSubview(self.statusLabel)

        // 制約から余白を削除
        NSLayoutConstraint.activate([
            self.textField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.textField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.textField.topAnchor.constraint(equalTo: self.topAnchor),
            self.textField.bottomAnchor.constraint(equalTo: self.bottomAnchor),

            self.statusLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.statusLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.statusLabel.topAnchor.constraint(equalTo: self.topAnchor),
            self.statusLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    // intrinsicContentSize を rectHeight に合わせる
    override var intrinsicContentSize: NSSize {
        let width = max(self.textField.intrinsicContentSize.width, self.statusLabel.intrinsicContentSize.width)
        return NSSize(width: width, height: self.rectHeight)
    }

    func displayCandidate(_ candidate: String, rectHeight: CGFloat = 16) {
        self.rectHeight = rectHeight
        self.currentCandidate = candidate

        // ステータスラベルをクリア
        self.statusLabel.stringValue = ""

        // 属性付き文字列を設定
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: rectHeight * 0.9)
        ]
        let attributedString = NSAttributedString(string: candidate, attributes: attributes)
        self.textField.attributedStringValue = attributedString

        // intrinsicContentSize を更新
        self.invalidateIntrinsicContentSize()
    }

    func displayStatusText(_ statusText: String, rectHeight: CGFloat = 16) {
        self.rectHeight = rectHeight

        // テキストフィールドをクリア
        self.textField.stringValue = ""

        // ステータスラベルにテキストを設定
        self.statusLabel.font = NSFont.systemFont(ofSize: rectHeight * 0.9)
        self.statusLabel.stringValue = statusText

        // intrinsicContentSize を更新
        self.invalidateIntrinsicContentSize()
    }

    func getSelectedCandidate() -> String? {
        self.currentCandidate.isEmpty ? nil : self.currentCandidate
    }
}
class PredictiveSuggestionCandidateViewController: NSViewController {
    override func loadView() {
        self.view = PredictiveSuggestionCandidateView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForRoundedCorners()
        // サンプルのデータを設定
        if let predictiveSuggestionCandidateView = self.view as? PredictiveSuggestionCandidateView {
            predictiveSuggestionCandidateView.displayCandidate("...")
            predictiveSuggestionCandidateView.displayStatusText("..")
        }
    }

    // ウィンドウの角丸設定
    private func configureWindowForRoundedCorners() {
        guard let window = self.view.window else {
            return
        }
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.masksToBounds = true
        window.styleMask = [.borderless, .resizable]
        window.isMovable = true
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView?.layer?.cornerRadius = 10
        window.backgroundColor = .clear
        window.isOpaque = false
    }

    func displayCandidate(_ candidate: String, cursorPosition: NSPoint, fontSize: CGFloat = 16) {
        if let predictiveSuggestionCandidateView = self.view as? PredictiveSuggestionCandidateView {
            predictiveSuggestionCandidateView.displayCandidate(candidate, rectHeight: fontSize)

            // ウィンドウのサイズを更新
            if let window = self.view.window {
                window.setContentSize(predictiveSuggestionCandidateView.intrinsicContentSize)
            }
        }
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    func displayStatusText(_ statusText: String, cursorPosition: NSPoint, fontSize: CGFloat = 16) {
        if let predictiveSuggestionCandidateView = self.view as? PredictiveSuggestionCandidateView {
            predictiveSuggestionCandidateView.displayStatusText(statusText, rectHeight: fontSize)

            // ウィンドウのサイズを更新
            if let window = self.view.window {
                window.setContentSize(predictiveSuggestionCandidateView.intrinsicContentSize)
            }
        }
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    private func positionWindowAtCursor(cursorPosition: NSPoint) {
        guard let window = self.view.window else {
            return
        }
        let windowSize = window.frame.size
        let screenFrame = NSScreen.main?.frame ?? .zero

        // ウィンドウの位置をカーソルに合わせる
        let position = NSPoint(
            x: min(cursorPosition.x, screenFrame.width - windowSize.width),
            y: max(cursorPosition.y, 0)
        )
        window.setFrameOrigin(position)
    }

    func getSelectedCandidate() -> String? {
        (self.view as? PredictiveSuggestionCandidateView)?.getSelectedCandidate()
    }
}
