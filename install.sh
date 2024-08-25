#!/bin/bash
set -xe -o pipefail

IGNORE_LINT=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ignore-lint) IGNORE_LINT=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ "$IGNORE_LINT" = false ]; then
    if command -v swiftlint &> /dev/null
    then
        # Fix auto-fixable errors
        swiftlint --fix --format
        # Check other errors
        swiftlint --quiet --strict
    else
        echo "swiftlint could not be found. Please rerun the script as \`./install.sh --ignore-lint\`."
        echo "For contributing azooKey on macOS, we strongly recommend you to install swiftlint"
        echo "To install swiftlint, run \`brew install swiftlint\`"
        exit 1
    fi
else
    echo "Skipping swiftlint checks due to --ignore-lint option."
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
