//
//  ChatGPTView.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Cocoa

class ChatGPTView: NSView {
    private let textView: NSTextView

    override init(frame frameRect: NSRect) {
        self.textView = NSTextView()
        super.init(frame: frameRect)
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.textView = NSTextView()
        super.init(coder: decoder)
        self.setupView()
    }

    private func setupView() {
        self.textView.isEditable = false
        self.textView.font = NSFont.systemFont(ofSize: 14)
        self.addSubview(self.textView)
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            self.textView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            self.textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            self.textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
    }

    func displayResponse(_ response: String) {
        self.textView.string = response
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
        guard let window = self.view.window else {
            return
        }
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "ChatGPT"
        window.setContentSize(NSSize(width: 600, height: 400))
        window.center()
    }

    func displayResponse(_ response: String) {
        (self.view as? ChatGPTView)?.displayResponse(response)
    }
}
