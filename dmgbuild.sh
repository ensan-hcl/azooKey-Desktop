set -e
xcodebuild -workspace azooKeyMac.xcodeproj/project.xcworkspace -scheme azooKeyMac clean archive -archivePath build/archive.xcarchive | xcpretty
dmgbuild -s dmgbuildsettings.py -D app="build/archive.xcarchive/Products/Applications/azooKeyMac.app" "azooKey" azooKey.dmg
