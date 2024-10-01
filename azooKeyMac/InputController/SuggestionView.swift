//
//  Suggestion.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//
import Cocoa

class SuggestionView: NSView {
    private let textField: NSTextField
    private let statusLabel: NSTextField // 状態表示用のラベル
    private var currentCandidate: String = "" // 現在表示中の候補

    override init(frame frameRect: NSRect) {
        self.textField = NSTextField()
        self.statusLabel = NSTextField() // statusLabelの初期化
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.textField = NSTextField()
        self.statusLabel = NSTextField() // statusLabelの初期化
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

        // TextFieldのレイアウト
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

    func displayCandidate(_ candidate: String, fontSize: CGFloat = 16) {
        self.currentCandidate = candidate

        // StatusTextを空にする
        self.statusLabel.stringValue = ""

        // 下線を追加したNSAttributedStringを作成
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: fontSize)
        ]
        let attributedString = NSAttributedString(string: candidate, attributes: attributes)

        // attributedStringをtextFieldに設定
        self.textField.attributedStringValue = attributedString
    }

    func displayStatusText(_ statusText: String, fontSize: CGFloat = 16) {
        // Candidateを空にする
        self.textField.stringValue = ""

        // 状態表示テキストをstatusLabelに設定
        self.statusLabel.font = NSFont.systemFont(ofSize: fontSize)
        self.statusLabel.stringValue = statusText
    }

    // 選択された候補を取得するメソッドを追加
    func getSelectedCandidate() -> String? {
        self.currentCandidate.isEmpty ? nil : self.currentCandidate
    }
}

class SuggestionViewController: NSViewController {
    override func loadView() {
        self.view = SuggestionView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForRoundedCorners()
        // サンプルのデータを設定
        if let suggestion = self.view as? SuggestionView {
            suggestion.displayCandidate("...")
            suggestion.displayStatusText("..")
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
        (self.view as? SuggestionView)?.displayCandidate(candidate, fontSize: fontSize)
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    func displayStatusText(_ statusText: String, cursorPosition: NSPoint, fontSize: CGFloat = 16) {
        (self.view as? SuggestionView)?.displayStatusText(statusText, fontSize: fontSize)
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    private func positionWindowAtCursor(cursorPosition: NSPoint) {
        guard let window = self.view.window else {
            return
        }
        let windowSize = self.view.frame.size
        let screenFrame = NSScreen.main?.frame ?? .zero
        let position = NSPoint(x: min(cursorPosition.x, screenFrame.width - windowSize.width),
                               y: max(cursorPosition.y - windowSize.height + 22, 0))
        window.setFrameOrigin(position)
    }

    // 選択された候補を取得するメソッドを追加
    func getSelectedCandidate() -> String? {
        (self.view as? SuggestionView)?.getSelectedCandidate()
    }
}
