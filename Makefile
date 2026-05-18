.PHONY: run build

run:
	./scripts/run-ios.sh

build:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild \
		-project RingVoice.xcodeproj \
		-scheme RingVoice \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		-derivedDataPath DerivedData \
		CODE_SIGNING_ALLOWED=NO \
		build
