# RingVoice

SwiftUI iOS demo for a Bluetooth ring voice workflow.

## Run

Open `RingVoice.xcodeproj` in Xcode and run the `RingVoice` scheme on an iOS Simulator.

From the command line:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project RingVoice.xcodeproj \
  -scheme RingVoice \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

## AI Env

Copy `.env.example` to `.env`, then fill `STEP_API_KEY`.

The simulator app reads env values from the process environment. Launch it with:

```sh
set -a; source .env; set +a
SIMCTL_CHILD_STEP_API_KEY="$STEP_API_KEY" \
SIMCTL_CHILD_STEP_API_BASE_URL="$STEP_API_BASE_URL" \
SIMCTL_CHILD_STEP_AI_MODEL="$STEP_AI_MODEL" \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
/usr/bin/xcrun simctl launch --terminate-running-process \
  <device-id> com.example.ringvoice
```

Do not ship a production API key in the iOS app. Use a backend proxy later.
