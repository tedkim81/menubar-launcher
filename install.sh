#!/bin/sh
# Installs Menubar Launcher for the current user. No sudo needed.
set -e
cd "$(dirname "$0")"

APP="$HOME/Applications/MenubarLauncher.app"
CONFIG_DIR="$HOME/.config/menubar-launcher"
BIN="$HOME/.local/bin"
LABEL=io.github.tedkim81.menubar-launcher
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

[ "$(uname)" = Darwin ] || { echo "Menubar Launcher runs on macOS only." >&2; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Command Line Tools are required: xcode-select --install" >&2; exit 1; }

echo "==> Building the menu bar app"
mkdir -p "$APP/Contents/MacOS"
clang -O2 -fobjc-arc -framework AppKit -framework Carbon -framework UserNotifications app/MenubarLauncher.m \
  -o "$APP/Contents/MacOS/MenubarLauncher"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleName</key><string>MenubarLauncher</string>
  <key>CFBundleExecutable</key><string>MenubarLauncher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Menu items can run AppleScript (for example, to open a Terminal window).</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

echo "==> Installing chrome-profile to $BIN"
mkdir -p "$BIN"
install -m 755 bin/chrome-profile "$BIN/chrome-profile"

echo "==> Preparing the menu file"
mkdir -p "$CONFIG_DIR"
if [ -e "$CONFIG_DIR/menu.conf" ]; then
  echo "    keeping your $CONFIG_DIR/menu.conf"
else
  cp menu.conf.example "$CONFIG_DIR/menu.conf"
  echo "    created $CONFIG_DIR/menu.conf from menu.conf.example"
fi

echo "==> Registering the login item"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Starts MenubarLauncher at login and restarts it if it crashes. Choosing Quit in the menu
     exits cleanly, so it stays off until the next login.
     It runs the executable directly (not via /usr/bin/open) so System Settings lists it as MenubarLauncher. -->
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP/Contents/MacOS/MenubarLauncher</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key><false/>
  </dict>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x MenubarLauncher 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "Done. Click the menu bar icon, then choose Edit List… to add your own items."
