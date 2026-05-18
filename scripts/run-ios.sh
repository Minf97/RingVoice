#!/usr/bin/env bash
set -euo pipefail

PROJECT="RingVoice.xcodeproj"
SCHEME="RingVoice"
BUNDLE_ID="com.example.ringvoice"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
DERIVED_DATA="DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/RingVoice.app"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

# 读取环境变量
if [[ -f ".env" ]]; then
  set -a
  source ".env"
  set +a
fi

device_id=$(
  /usr/bin/xcrun simctl list devices available |
    awk -v name="$DEVICE_NAME" '$0 ~ name { print; exit }' |
    sed -E 's/.*\(([0-9A-F-]+)\).*/\1/'
)

if [[ -z "$device_id" ]]; then
  echo "Simulator not found: $DEVICE_NAME" >&2
  exit 1
fi

# 构建 App
/usr/bin/xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

# 启动模拟器
/usr/bin/open -a Simulator
if ! /usr/bin/xcrun simctl list devices booted | grep -q "$device_id"; then
  /usr/bin/xcrun simctl boot "$device_id"
fi
/usr/bin/xcrun simctl bootstatus "$device_id" -b

# 安装并运行
/usr/bin/xcrun simctl install "$device_id" "$APP_PATH"
SIMCTL_CHILD_STEP_API_KEY="${STEP_API_KEY:-}" \
SIMCTL_CHILD_STEP_API_BASE_URL="${STEP_API_BASE_URL:-}" \
SIMCTL_CHILD_STEP_AI_MODEL="${STEP_AI_MODEL:-}" \
  /usr/bin/xcrun simctl launch --terminate-running-process "$device_id" "$BUNDLE_ID"
