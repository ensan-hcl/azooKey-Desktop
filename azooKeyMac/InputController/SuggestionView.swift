//
//  Suggestion.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//
import Cocoa

class Suggestion: NSView {
    private let textField: NSTextField
    private var currentCandidate: String = "" // 現在表示中の候補

    override init(frame frameRect: NSRect) {
        self.textField = NSTextField()
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.textField = NSTextField()
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

        self.addSubview(self.textField)

        // TextFieldのレイアウト
        NSLayoutConstraint.activate([
            self.textField.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.textField.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.textField.topAnchor.constraint(equalTo: self.topAnchor),
            self.textField.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    func displayCandidate(_ candidate: String) {
        self.currentCandidate = candidate

        // 下線を追加したNSAttributedStringを作成
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue, // 下線のスタイルを指定
            .font: NSFont.systemFont(ofSize: 16) // フォントを適用
        ]
        let attributedString = NSAttributedString(string: candidate, attributes: attributes)

        // attributedStringをtextFieldに設定
        self.textField.attributedStringValue = attributedString
    }

    // 選択された候補を取得するメソッドを追加
    func getSelectedCandidate() -> String? {
        self.currentCandidate.isEmpty ? nil : self.currentCandidate
    }
}

class SuggestionController: NSViewController {
    override func loadView() {
        self.view = Suggestion()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForRoundedCorners()
        // サンプルのデータを設定
        if let suggestion = self.view as? Suggestion {
            suggestion.displayCandidate("Sample Option")
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

    func displayCandidate(_ candidate: String, cursorPosition: NSPoint) {
        (self.view as? Suggestion)?.displayCandidate(candidate)
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
        (self.view as? Suggestion)?.getSelectedCandidate()
    }
}
