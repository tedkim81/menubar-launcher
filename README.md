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
Chrome         = open -na "Google Chrome" --args --profile-directory="Profile 1"
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
| `# ...` | Comment. Blank lines are ignored too. |

- `~` at the start of a path becomes your home folder, even inside quotes.
- Commands run in the background, so a slow one never freezes the menu. If one exits with a non-zero code, a notification shows the code and its error output.
- A line the app can't read shows up in the menu as a warning with its line number.
- Check a file from the terminal: `~/Applications/MenubarLauncher.app/Contents/MacOS/MenubarLauncher --print`

### PATH

An app started at login doesn't read `~/.zshrc`, so tools installed by Homebrew, nvm, pipx and so on aren't on its PATH. List their folders on the `PATH=` line. To find one, run `dirname "$(command -v <tool>)"` in your terminal. Without a `PATH=` line, commands get `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`.

## Bringing a window to the front

The launcher only runs the command. Whether an open window comes forward is up to the command:

| Target | Command | Notes |
|---|---|---|
| A folder in Cursor or VS Code | `open -a Cursor <folder>` | Brings forward the window that already has the folder, or opens a new one. Prefer this to `cursor <folder>`: since macOS 14 an app can't take focus from another app on its own, so `cursor <folder>` switches windows only while Cursor is already in front. |
| Any app | `open -a <App>` | |
| A Chrome profile | `open -na "Google Chrome" --args --profile-directory="<folder>"` | Opens a **new window** of that profile each time. Profile folders (`Default`, `Profile 1`, …) are listed under `profile.info_cache` in `~/Library/Application Support/Google/Chrome/Local State`. |
| A Slack workspace | `open "slack://open?team=<team ID>"` | The team ID starts with `T`. With a single workspace, `open -a Slack` is enough. |
| A terminal command | `osascript -e 'tell app "Terminal" to do script "<command>"' -e 'tell app "Terminal" to activate'` | Opens a new Terminal window. The first run asks to let MenubarLauncher control Terminal. |

## How it works

| File | Installed to | Role |
|---|---|---|
| `app/MenubarLauncher.m` | `~/Applications/MenubarLauncher.app` | Menu bar app |
| `menu.conf.example` | `~/.config/menubar-launcher/menu.conf` (first install only) | Your menu |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.menubar-launcher.plist` | Starts the app at login and restarts it if it crashes. **Quit** stays quit until the next login. |

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
