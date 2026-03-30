#!/bin/bash
# Expo/React Native のビルドキャッシュをすべて削除する

set -e

echo "Purging build caches..."

# ローカルビルド成果物
echo "Removing local build artifacts..."
rm -rf ios android .expo node_modules/.cache

# Metro バンドラーキャッシュ（/tmp に生成される）
echo "Removing Metro cache..."
rm -rf /tmp/metro-* /tmp/haste-map-* /tmp/react-native-*

# Xcode キャッシュ
echo "Removing Xcode caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Developer/Xcode/Products
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# シミュレーターキャッシュ
echo "Removing simulator caches..."
rm -rf ~/Library/Developer/CoreSimulator/Caches
xcrun simctl delete unavailable

# Watchman キャッシュ
echo "Resetting Watchman cache..."
watchman watch-del-all 2>/dev/null || true

# CocoaPods キャッシュ
echo "Removing CocoaPods cache..."
pod cache clean --all 2>/dev/null || true

echo "Done."
