@_default:
    just --list --unsorted

# Build this project
build:
	xcodebuild -project DockLock.xcodeproj -target DockLock SYMROOT=build build

# Clean build artifacts
clean:
	rm -rf build
