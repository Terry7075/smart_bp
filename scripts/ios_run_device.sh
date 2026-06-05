#!/bin/bash
# 在 Mac 上跑實機 iOS（Winter 等）
# 重要：請在 ~/Projects/smart_bp-main 建置，勿在 Desktop 目錄（會觸發 com.apple.provenance 導致 codesign 失敗）
set -euo pipefail

DEVICE_ID="${1:-00008130-001E71EE02E1001C}"
DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${IOS_PROJECT_DIR:-$HOME/Projects/smart_bp-main}"

export COPYFILE_DISABLE=1

# 同步 Desktop 程式碼到 Projects（排除 build/Pods 以加快）
mkdir -p "$PROJECT_DIR"
rsync -a --delete \
  --exclude=.dart_tool \
  --exclude=build \
  --exclude=ios/Pods \
  --exclude=ios/.symlinks \
  "$DESKTOP_DIR/" "$PROJECT_DIR/"

echo "專案目錄: $PROJECT_DIR"
cd "$PROJECT_DIR"
flutter pub get
flutter run -d "$DEVICE_ID"
