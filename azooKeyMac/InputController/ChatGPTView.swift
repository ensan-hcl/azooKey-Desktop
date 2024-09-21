//
//  ChatGPTView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Cocoa

class ChatGPTView: NSView {
    private let label: NSTextField

    override init(frame frameRect: NSRect) {
        self.label = NSTextField(labelWithString: "ChatGPTへのリクエストを表示します。")
        super.init(frame: frameRect)
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.label = NSTextField(labelWithString: "ChatGPTへのリクエストを表示します。")
        super.init(coder: decoder)
        self.setupView()
    }

    private func setupView() {
        self.addSubview(self.label)
        self.label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
}

class ChatGPTViewController: NSViewController {
    override func loadView() {
        self.view = ChatGPTView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureWindowForAppearance()
    }

    private func configureWindowForAppearance() {
        guard let window = self.view.window else { return }
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "ChatGPT"
        window.setContentSize(NSSize(width: 400, height: 300))
        window.center()
    }
}
