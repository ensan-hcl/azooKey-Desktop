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
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor // Set the background to clear
        self.setupView()
    }

    required init?(coder decoder: NSCoder) {
        self.textView = NSTextView()
        super.init(coder: decoder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor // Set the background to clear
        self.setupView()
    }

    private func setupView() {
        self.textView.isEditable = false
        self.textView.font = NSFont.systemFont(ofSize: 14)
        self.textView.backgroundColor = .clear // Make textView background clear
        self.textView.isVerticallyResizable = true
        self.textView.isHorizontallyResizable = false
        self.textView.textContainerInset = NSSize(width: 5, height: 5)
        self.textView.textContainer?.widthTracksTextView = false
        self.textView.textContainer?.containerSize = NSSize(width: 380, height: CGFloat.greatestFiniteMagnitude) // Set a max height
        self.textView.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.textView)

        // Set constraints for textView to expand fully within ChatGPTView
        NSLayoutConstraint.activate([
            self.textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            self.textView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            self.textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 10),
            self.textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10)
        ])
    }

    func displayResponse(_ response: String) {
        self.textView.string = response
        self.adjustSizeToFitContent()
    }

    private func adjustSizeToFitContent() {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            return
        }

        // Force layout manager to update the layout for the content
        layoutManager.ensureLayout(for: textContainer)

        // Calculate the bounding rect needed to display all the text
        let textBoundingRect = layoutManager.boundingRect(forGlyphRange: layoutManager.glyphRange(for: textContainer), in: textContainer)

        // Update the frame size based on the text content size, with some padding
        let newSize = NSSize(width: textBoundingRect.width + 20, height: textBoundingRect.height + 20)
        self.setFrameSize(newSize)

        // Update the window size if this view is inside a window
        self.window?.setContentSize(newSize)
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
        window.styleMask = [.borderless, .resizable]
        window.isOpaque = false
        window.backgroundColor = .clear // Set window background to clear
    }

    func displayResponse(_ response: String, cursorPosition: NSPoint) {
        (self.view as? ChatGPTView)?.displayResponse(response)
        // Adjust window size and position
        self.positionWindowAtCursor(cursorPosition: cursorPosition)
    }

    private func positionWindowAtCursor(cursorPosition: NSPoint) {
        guard let window = self.view.window else {
            return
        }
        let windowSize = self.view.frame.size
        let screenFrame = NSScreen.main?.frame ?? .zero
        let position = NSPoint(x: min(cursorPosition.x, screenFrame.width - windowSize.width),
                               y: max(cursorPosition.y - windowSize.height, 0))
        window.setFrameOrigin(position)
    }
}
