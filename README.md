# iOS Hello World

Minimal SwiftUI iOS boilerplate.

## Run

Open `HelloWorld.xcodeproj` in Xcode and run the `HelloWorld` scheme on an iOS Simulator.

From the command line:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project HelloWorld.xcodeproj \
  -scheme HelloWorld \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

