#!/bin/sh
# Removes everything install.sh added, except your menu file.
APP="$HOME/Applications/MenubarLauncher.app"
CONFIG_DIR="$HOME/.config/menubar-launcher"
LABEL=io.github.tedkim81.menubar-launcher
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
pkill -x MenubarLauncher 2>/dev/null
rm -rf "$PLIST" "$APP" "$HOME/.local/bin/chrome-profile"

echo "Menubar Launcher removed. Your menu file is kept at $CONFIG_DIR/menu.conf (delete it yourself if you like)."
