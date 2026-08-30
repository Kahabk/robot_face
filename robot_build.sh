#!/usr/bin/env bash
# robot_alshifa_build.sh — Diagnose environment & build release APK
set -euo pipefail
LOG="/tmp/robot_alshifa_build.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================================"
echo " Robot Alshifa — Environment Diagnosis & Build Script"
echo "========================================================"
echo "Timestamp: $(date)"
echo ""

# ── 1. Flutter binary ──────────────────────────────────────
echo "=== Flutter Binary ==="
FLUTTER_BIN="/home/user/flutter/bin/flutter"
if [ ! -f "$FLUTTER_BIN" ]; then
  echo "ERROR: Flutter binary not found at $FLUTTER_BIN"
  exit 1
fi
ls -la "$FLUTTER_BIN"
file "$FLUTTER_BIN"
head -n 3 "$FLUTTER_BIN"
echo "Is executable: $(test -x "$FLUTTER_BIN" && echo YES || echo NO)"
echo ""

# ── 2. Flutter version ─────────────────────────────────────
echo "=== Flutter Version ==="
which flutter
flutter --version
echo ""

# ── 3. Java version ────────────────────────────────────────
echo "=== Java Version ==="
java -version 2>&1 || echo "java not in PATH"
which java || echo "java not found"
# Also check JAVA_HOME used by Gradle
if [ -n "${JAVA_HOME:-}" ]; then
  echo "JAVA_HOME=$JAVA_HOME"
  "$JAVA_HOME/bin/java" -version 2>&1
fi
echo ""

# ── 4. Android SDK ─────────────────────────────────────────
echo "=== Android SDK ==="
ANDROID_HOME="${ANDROID_HOME:-/home/user/Android/Sdk}"
echo "ANDROID_HOME=$ANDROID_HOME"
ls "$ANDROID_HOME/build-tools/" 2>/dev/null | tail -5 || echo "build-tools not found"
ls "$ANDROID_HOME/platforms/" 2>/dev/null | tail -5 || echo "platforms not found"
echo ""

# ── 5. Flutter doctor ──────────────────────────────────────
echo "=== Flutter Doctor ==="
flutter doctor -v 2>&1 || true
echo ""

# ── 6. Print existing Gradle files ─────────────────────────
echo "=== android/gradle/wrapper/gradle-wrapper.properties ==="
cat android/gradle/wrapper/gradle-wrapper.properties
echo ""

echo "=== android/settings.gradle ==="
cat android/settings.gradle
echo ""

echo "=== android/build.gradle ==="
cat android/build.gradle
echo ""

echo "=== android/app/build.gradle ==="
cat android/app/build.gradle
echo ""

echo "=== android/gradle.properties ==="
cat android/gradle.properties
echo ""

echo "=== pubspec.yaml ==="
cat pubspec.yaml
echo ""

# ── 7. Check Gradle wrapper jar ────────────────────────────
echo "=== Gradle Wrapper JAR ==="
ls -lh android/gradle/wrapper/ || echo "wrapper dir not found"
echo ""

# ── 8. Detect actual Flutter Gradle plugin location ────────
echo "=== Flutter Gradle Plugin Files ==="
ls /home/user/flutter/packages/flutter_tools/gradle/
echo ""

# Print app_plugin_loader to see what it does now
echo "--- app_plugin_loader.gradle first 15 lines ---"
head -15 /home/user/flutter/packages/flutter_tools/gradle/app_plugin_loader.gradle || true
echo ""

# ── 9. Clean build ─────────────────────────────────────────
echo "=== Flutter Clean ==="
flutter clean
echo ""

echo "=== Remove Android Gradle Cache ==="
rm -rf android/.gradle
echo ""

echo "=== Flutter Pub Get ==="
flutter pub get
echo ""

# ── 10. Build APK ──────────────────────────────────────────
echo "=== Building Release APK ==="
flutter build apk --release 2>&1
BUILD_EXIT=$?
echo ""
echo "Build exit code: $BUILD_EXIT"

if [ $BUILD_EXIT -eq 0 ]; then
  echo ""
  echo "========================================================"
  echo "✓ BUILD SUCCESS"
  echo "APK: $(find build/app/outputs/flutter-apk/ -name '*.apk' 2>/dev/null || echo 'not found')"
  echo "========================================================"
else
  echo ""
  echo "========================================================"
  echo "✗ BUILD FAILED — see errors above"
  echo "========================================================"
fi

echo ""
echo "Full log saved to: $LOG"
