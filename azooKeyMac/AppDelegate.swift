//
//  AppDelegate.swift
//  AppDelegate
//
//  Created by ensan on 2021/09/06.
//

import Cocoa
import InputMethodKit
import KanaKanjiConverterModuleWithDefaultDictionary
import SwiftUI

// Necessary to launch this app
class NSManualApplication: NSApplication {
    let appDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = appDelegate
    }

    required init?(coder: NSCoder) {
        // No need for implementation
        fatalError("init(coder:) has not been implemented")
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server = IMKServer()
    weak var configWindow: NSWindow?
    weak var userDictionaryEditorWindow: NSWindow?
    var configWindowController: NSWindowController?
    var userDictionaryEditorWindowController: NSWindowController?
    @MainActor var kanaKanjiConverter = KanaKanjiConverter()

    private static func buildSwiftUIWindow(
        _ view: some View,
        contentRect: NSRect = NSRect(x: 0, y: 0, width: 400, height: 300),
        styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .borderless],
        title: String = ""
    ) -> (window: NSWindow, windowController: NSWindowController) {
        // Create a new window
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        // Set the window title
        window.title = title
        window.contentViewController = NSHostingController(rootView: view)
        // Keep window with in a controller
        let windowController = NSWindowController(window: window)
        // Show the window
        window.level = .modalPanel
        window.makeKeyAndOrderFront(nil)
        return (window, windowController)
    }

    func openConfigWindow() {
        if let configWindow {
            // Show the window
            configWindow.level = .modalPanel
            configWindow.makeKeyAndOrderFront(nil)
        } else {
            // Create a new window
            (self.configWindow, self.configWindowController) = Self.buildSwiftUIWindow(ConfigWindow(), title: "設定")
        }
    }

    func openUserDictionaryEditorWindow() {
        if let userDictionaryEditorWindow {
            // Show the window
            userDictionaryEditorWindow.level = .modalPanel
            userDictionaryEditorWindow.makeKeyAndOrderFront(nil)
        } else {
            (self.userDictionaryEditorWindow, self.userDictionaryEditorWindowController) = Self.buildSwiftUIWindow(UserDictionaryEditorWindow(), title: "設定")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Insert code here to initialize your application
        self.server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        NSLog("tried connection")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }
}
