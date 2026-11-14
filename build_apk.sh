#!/usr/bin/env bash
# Build the updated Safe to Spend APK with the AI features.
# Requires: Flutter SDK (~/tools/flutter), JDK 17 (~/Android/jdk17),
# Android SDK (~/Android/sdk) with platform-tools;build-tools;platforms;android-3x
set -e

export JAVA_HOME="$HOME/Android/jdk17"
export PATH="$JAVA_HOME/bin:$HOME/tools/flutter/bin:$HOME/Android/sdk/cmdline-tools/latest/bin:$HOME/Android/sdk/platform-tools:$PATH"
export ANDROID_SDK_ROOT="$HOME/Android/sdk"
export ANDROID_HOME="$HOME/Android/sdk"

# Accept licenses (needed for first sdkmanager run)
yes | sdkmanager --licenses > /dev/null 2>&1 || true

# Install required SDK components if missing
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" > /dev/null 2>&1 || true

cd "$HOME/safe-to-spend"

flutter build apk --release

echo
echo "APK BUILT:"
ls -la build/app/release/flutter-release.apk build/app/outputs/flutter-apk/release-app-release.apk 2>/dev/null
