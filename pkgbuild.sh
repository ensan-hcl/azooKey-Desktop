set -e


# Suppose we have build/azooKeyMac.app
# Use this script to create a plist package for distribution
# pkgbuild --analyze --root ./build/ pkg.plist

# Create a temporary package
pkgbuild --root ./build/ \
         --component-plist pkg.plist --identifier dev.ensan.inputmethod.azooKeyMac \
         --version 0 \
         --install-location /Library/Input\ Methods \
         azooKey-tmp.pkg

# Create a distribution file
# productbuild --synthesize --package azooKey-tmp.pkg distribution.xml

# Build the final package
productbuild --distribution distribution.xml --package-path . azooKey-release.pkg

# Clean up
rm azooKey-tmp.pkg
