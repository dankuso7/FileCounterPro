#!/bin/bash
set -e

APP_NAME="FileCounter"
APP_BUNDLE="$APP_NAME.app"
BIN_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"

echo "Building $APP_NAME for macOS 27 Golden Gate (Apple Silicon)..."

mkdir -p "$BIN_DIR"
mkdir -p "$RES_DIR"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RES_DIR/"
fi

# Compile — release optimisations, native Apple Silicon target (macOS 27)
swiftc \
  -O \
  FileCounterApp.swift \
  SciFiTheme.swift \
  ContentView.swift \
  FileCounter.swift \
  DiskMonitor.swift \
  DriveCleaner.swift \
  LargeFileScanner.swift \
  SystemMonitor.swift \
  ActivityTracker.swift \
  ActivityMonitor.swift \
  DuplicateScanner.swift \
  DuplicateFinderView.swift \
  LivePowerMonitor.swift \
  NetworkMonitor.swift \
  HardwareAnalyzer.swift \
  GameDatabase.swift \
  GameScanner.swift \
  GameAdvisorView.swift \
  GPUSideBySideView.swift \
  GameHUDOverlay.swift \
  GameHintEngine.swift \
  LiveSceneAnalyzer.swift \
  SmartUninstaller.swift \
  SmartUninstallerView.swift \
  SystemJunkScanner.swift \
  SystemJunkView.swift \
  MacGamingEstimator.swift \
  MacGamingEstimatorView.swift \
  -o "$BIN_DIR/$APP_NAME"

# Info.plist — declare macOS 27 minimum, Apple Silicon, Liquid Glass ready
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.filecounter.app</string>
    <key>CFBundleName</key>
    <string>File Counter Pro</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>200</string>
    <key>LSMinimumSystemVersion</key>
    <string>27.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>UIRequiresFullScreen</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>File Counter uses ScreenCaptureKit to analyze live game scenes and provide AI hints.</string>
</dict>
</plist>
EOF

chmod +x "$BIN_DIR/$APP_NAME"
echo "✅  Successfully built $APP_BUNDLE (macOS 27 Golden Gate · Apple Silicon · Swift 6)"
