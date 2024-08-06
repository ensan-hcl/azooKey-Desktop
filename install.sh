set -e

# Check if xcpretty is installed
if command -v xcpretty &> /dev/null
then
    xcodebuild -workspace azooKeyMac.xcodeproj/project.xcworkspace -scheme azooKeyMac clean archive -archivePath build/archive.xcarchive | xcpretty
else
    echo "xcpretty could not be found. Proceeding without xcpretty."
    xcodebuild -workspace azooKeyMac.xcodeproj/project.xcworkspace -scheme azooKeyMac clean archive -archivePath build/archive.xcarchive
fi

sudo rm -rf /Library/Input\ Methods/azooKeyMac.app
sudo cp -r build/archive.xcarchive/Products/Applications/azooKeyMac.app /Library/Input\ Methods/
pkill azooKeyMac
