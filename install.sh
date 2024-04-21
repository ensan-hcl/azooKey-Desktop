set -e
xcodebuild -workspace azooKeyMac.xcodeproj/project.xcworkspace -scheme azooKeyMac clean archive -archivePath build/archive.xcarchive | xcpretty
sudo rm -rf /Library/Input\ Methods/azooKeyMac.app
sudo cp -r build/archive.xcarchive/Products/Applications/azooKeyMac.app /Library/Input\ Methods/
pkill azooKeyMac
