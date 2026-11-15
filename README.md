# Menubar Launcher

[한국어](README.ko.md)

A menu bar icon that lists your own shortcuts, grouped into sections. Pick one and its app or window comes to the front, or starts if it isn't running.

Each shortcut is just a name and a shell command, so anything you can start from a terminal can be a menu item: a project folder in your editor, a browser profile, a chat workspace, a terminal running a command.

```
▦
├─ Personal
│   my-project
│   Chrome
│   Terminal agent
├─ ─────────
├─ Work
│   work-project
│   Chrome (work)
│   Slack
├─ ─────────
│   Edit List…
└─ Quit
```

## Install

Requirements: macOS, Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/tedkim81/menubar-launcher.git
cd menubar-launcher
./install.sh
```

No password needed. The installer builds the app, copies `menu.conf.example` to `~/.config/menubar-launcher/menu.conf` (an existing file is kept) and starts the app at every login.

When the app first starts, macOS asks whether MenubarLauncher may send notifications. Until you allow it, error messages still appear, but under Script Editor's name.

## The menu file

`~/.config/menubar-launcher/menu.conf` is read again every time you open the menu. Save it and click the icon: no restart needed. **Edit List…** opens it in your default text editor.

```ini
PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin

[Personal]
my-project     = open -a Cursor ~/src/my-project
Chrome         = ~/.local/bin/chrome-profile "Profile 1"
Terminal agent = osascript -e 'tell app "Terminal" to do script "cd ~/src/my-project && codex"' -e 'tell app "Terminal" to activate'
---
[Work]
Slack          = open "slack://open?team=T0000000000"
```

| Line | Meaning |
|---|---|
| `name = command` | Menu item. The command runs with `/bin/sh`; everything after the first `=` belongs to it. |
| `[Title]` | Section header |
| `---` | Separator |
| `PATH=...` | PATH for every command (see below) |
| `HOTKEY=...` | Optional global shortcut that opens the menu (see below) |
| `# ...` | Comment. Blank lines are ignored too. |

- `~` at the start of a path becomes your home folder, even inside quotes.
- Commands run in the background, so a slow one never freezes the menu. If one exits with a non-zero code, a notification shows the code and its error output.
- A line the app can't read shows up in the menu as a warning with its line number.
- Check a file from the terminal: `~/Applications/MenubarLauncher.app/Contents/MacOS/MenubarLauncher --print`

### PATH

An app started at login doesn't read `~/.zshrc`, so tools installed by Homebrew, nvm, pipx and so on aren't on its PATH. List their folders on the `PATH=` line. To find one, run `dirname "$(command -v <tool>)"` in your terminal. Without a `PATH=` line, commands get `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`.

### Keyboard shortcut

```ini
HOTKEY=ctrl+cmd+J
```

Press the shortcut anywhere and the menu opens at the mouse pointer. Pick an item with the arrow keys and Return, or press Esc to close it. The app in front keeps focus, and no Accessibility permission is needed.

- Modifiers: `cmd`, `shift`, `opt` (or `option`, `alt`), `ctrl`. At least one of `cmd`, `opt` or `ctrl`. Key: `A`–`Z`, `0`–`9` or `space`.
- The key is matched by its position on the keyboard, so it works with any input source. Typing the start of an item's name to jump to it only works while the input source matches the name's script.
- A global shortcut takes the key combination away from every app. Plain `cmd`+letter is used by almost every app; combinations with `ctrl`+`cmd` or `opt`+`shift`+`cmd` are much less crowded.
- The file is checked every 2 seconds, so a new shortcut works shortly after you save, even without opening the menu.

## Command examples

The launcher only runs the command. Whether a window that is already open comes forward is up to the command, and these do:

```ini
my-project = open -a Cursor ~/src/my-project
Codex      = open -b com.openai.codex
Notes      = open -a Notes
Chrome     = ~/.local/bin/chrome-profile "Profile 1"
Slack      = open "slack://open?team=T0000000000"
Build      = osascript -e 'tell app "Terminal" to do script "cd ~/src/my-project && make"' -e 'tell app "Terminal" to activate'
Dashboard  = open https://example.com/dashboard
```

| Target | Command | Notes |
|---|---|---|
| A folder in Cursor or VS Code | `open -a Cursor <folder>` | Brings forward the window that already has the folder, or opens a new one. For VS Code, use `open -a "Visual Studio Code" <folder>`. Prefer this to `cursor <folder>`: since macOS 14 an app can't take focus from another app on its own, so `cursor <folder>` switches windows only while Cursor is already in front. |
| A desktop app by bundle ID | `open -b <bundle ID>` | Keeps working if the app is renamed. The Codex desktop app's bundle ID is `com.openai.codex` (on the version tested, the app itself is named ChatGPT). |
| Any app by name | `open -a <App>` | |
| A Chrome profile | `~/.local/bin/chrome-profile "<folder>"` | Brings forward the most recently used window of that profile, or opens one if it has none. Installed with the app (see [How it works](#how-it-works)). The first run asks to let MenubarLauncher control Google Chrome. |
| A Slack workspace | `open "slack://open?team=<team ID>"` | With a single workspace, `open -a Slack` is enough. |
| A command in Terminal | `osascript -e 'tell app "Terminal" to do script "<command>"' -e 'tell app "Terminal" to activate'` | Opens a new Terminal window. The first run asks to let MenubarLauncher control Terminal. |
| A web page | `open <URL>` | Opens in your default browser. |

### Finding the values

Run these in your terminal. They print only to your screen.

```sh
# Chrome profile folders and their names: Default = ..., Profile 1 = ...
python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/Library/Application Support/Google/Chrome/Local State"))); [print(k, "=", v["name"]) for k,v in d["profile"]["info_cache"].items()]'

# Slack team IDs and workspace names (App Store or direct-download Slack)
python3 -c 'import glob,json,os; f=sorted(glob.glob(os.path.expanduser("~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/storage/root-state.json"))+glob.glob(os.path.expanduser("~/Library/Application Support/Slack/storage/root-state.json")))[0]; [print(k, "=", v["name"]) for k,v in json.load(open(f))["workspaces"].items()]'

# An app's bundle ID
osascript -e 'id of app "ChatGPT"'
```

### Keep personal values and secrets out

- Project paths, profile folders and team IDs are your own. Keep them in `~/.config/menubar-launcher/menu.conf`, and don't paste them into a repository, an issue or a screenshot you share.
- The menu file is plain text, and each item's command shows as a tooltip. Never put a password or token in a command. If a command needs one, have it read the secret from the keychain, for example `security find-generic-password -w -s <name>` inside a script.

## How it works

| File | Installed to | Role |
|---|---|---|
| `app/MenubarLauncher.m` | `~/Applications/MenubarLauncher.app` | Menu bar app |
| `menu.conf.example` | `~/.config/menubar-launcher/menu.conf` (first install only) | Your menu |
| `bin/chrome-profile` | `~/.local/bin/chrome-profile` | Brings a Chrome profile's window forward (below) |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.menubar-launcher.plist` | Starts the app at login and restarts it if it crashes. **Quit** stays quit until the next login. |

`chrome-profile` works out which profile a window belongs to by finding the window's ID in that profile's current session file (`<profile>/Sessions/Session_*`), since Chrome's scripting interface doesn't tell. It talks to the Chrome process that uses the default data folder by process ID, so a second Chrome started with `--user-data-dir` (for remote debugging, say) is left alone. A window opened in the last few seconds may not be in the session file yet; then a new window opens instead.

Run the menu file tests:

```sh
./test/test.sh
```

## Uninstall

```sh
./uninstall.sh
```

This removes the app and the login item. Your menu file stays in `~/.config/menubar-launcher/`.

## Tested on

macOS 15.1 (Apple silicon).

## License

[MIT](LICENSE)
