# What is this?

This is a sample implementation of the IMKit App with Swift/SwiftUI.

## Working Environment

Checked in July 2022.
* macOS 12.4
* Swift 5.6
* Xcode 13.4.1

Checked in 2021.
* macOS 11.5
* Swift 5.5
* Xcode 13 (beta)

## Usage
To try this sample project, follow these steps:

* Open this project in Xcode.
* Run the project.
* In the terminal, type `sudo chmod -R 777 /Library/Input\ Methods`.
* Add 'azooKeyMac' under **Settings** > **Keyboard** > **Input Sources** > **English**.
* Choose azooKeyMac as the input source and try it on a text field.

## Procedure to make project
I used the following steps to prepare this sample project:

* Create a new project with a bundle identifier that contains `.inputmethod.` in the string.
* Run the project.
* Remove `azooKeyMacApp.swift` and `ContentView.swift`.

* Add Swift files `AppDelegate.swift` and `azooKeyMacInputController.swift`.

  ```swift
  // AppDelegate.swift
  import Cocoa
  import InputMethodKit
  
  // necessary to launch this app
  class NSManualApplication: NSApplication {
      private let appDelegate = AppDelegate()
  
      override init() {
          super.init()
          self.delegate = appDelegate
      }
  
      required init?(coder: NSCoder) {
          fatalError("init(coder:) has not been implemented")
      }
  }
  
  @main
  class AppDelegate: NSObject, NSApplicationDelegate {
      var server = IMKServer()
      var candidatesWindow = IMKCandidates()
  
      func applicationDidFinishLaunching(_ notification: Notification) {
          // Insert code here to initialize your application
          server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
          candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType: kIMKMain)
          NSLog("tried connection")
      }
  
      func applicationWillTerminate(_ notification: Notification) {
          // Insert code here to tear down your application
      }
  }
  ```

  ```swift
  // azooKeyMacInputController.swift
  import Cocoa
  import InputMethodKit
  
  @objc(azooKeyMacInputController)
  class azooKeyMacInputController: IMKInputController {
      override func inputText(_ string: String!, client sender: Any!) -> Bool {
          NSLog(string)
          // get client to insert
          guard let client = sender as? IMKTextInput else {
              return false
          }
          client.insertText(string+string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
          return true
      }
  }
  ```
* Add icon file `main.tiff`.

* Modify Info.plist

  ```
  key: NSPrincipalClass  type: _  value: $(PRODUCT_MODULE_NAME).NSManualApplication
  key: InputMethodConnectionName  type: String  value: $(PRODUCT_BUNDLE_IDENTIFIER)_Connection
  key: InputMethodServerControllerClass  type: String  value: $(PRODUCT_MODULE_NAME).azooKeyMacInputController
  key: Application is background only  type: Boolean  value: YES
  key: tsInputMethodCharacterRepertoireKey  type: Array  value: [item0: String = Latn]
  key: tsInputMethodIconFileKey  type: String  value: main.tiff
  ```

* Add entitlements

  * Go **Signing & Capabilities** → **+Capability** → **App Sandbox**

  * Go azooKeyMac.entitlements, add 

  ```
  key: com.apple.security.temporary-exception.mach-register.global-name
  type: String
  value: $(PRODUCT_BUNDLE_IDENTIFIER)_Connection
  ```

  * Do `sudo chmod -R 777 /Library/Input\ Methods` on terminal.

* Modify build settings.
  * Go **Build Locations** → **Build Products Path** of debug → value `/Library/Input Methods`
  * Go **+** → **Add User-Defined Setting** → Set key `CONFIGURATION_BUILD_DIR`, value `/Library/Input Methods`.
  * !!! DO NOT edit thinklessly, this setting is really fragile.

* Try Run.

## Trouble Shooting

*I'm not an expert of macOS. Please don't ask too much, I don't know either.*

* InputMethods says **connection \*\*Failed\*\*** all though there are no diff!
  * Open 'Activity Monitor' app, search the name of your InputMethods, and kill the process. Then try again.

* `print()` doesn't work!
  * Use `NSLog()`.

* App doesn't run!
  * Check the path of build product file. If it isn't at `/Library/Input Methods/...`, something went wrong.
  * Maybe build setting went wrong. Check the settings. Especially, if `CONFIGURATION_BUILD_DIR="";` found, remove the line.
* Where's my InputMethod!?!?
  * Check English section. You would found it.
  * If still not, you will have to restart your computer.

## Reference

Thanks to authors!!

* https://mzp.hatenablog.com/entry/2017/09/17/220320
* https://www.logcg.com/en/archives/2078.html
* https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift
