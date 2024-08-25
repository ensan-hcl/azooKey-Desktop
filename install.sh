#!/bin/bash
set -xe -o pipefail


# Check if swiftlint is installed
if command -v swiftlint &> /dev/null
then
    swiftlint --fix --format --quiet
else
    echo "swiftlint could not be found. Proceeding without swiftlint."
    echo "For contributing azooKey on macOS, we strongly recommend you to install swiftlint"
    echo "to install swiftlint, run \`brew install swiftlint\`"
fi


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
