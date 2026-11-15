#!/bin/sh
# Tests how the config file is read, using `MenubarLauncher --print`.
# Builds into a temp folder and never touches the installed app or your config.
cd "$(dirname "$0")/.."
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
clang -O2 -fobjc-arc -framework AppKit -framework Carbon -framework UserNotifications app/MenubarLauncher.m -o "$T/ml" || exit 1

fail=0
check() { if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }
parse() { printf '%s\n' "$1" > "$T/conf"; HOME=/home/me "$T/ml" --print "$T/conf"; }
has() { printf '%s\n' "$1" | grep -qxF "$2"; }
tab=$(printf '\t')

out=$(parse '[Personal]
blog   = cursor ~/src/blog
---
[Work]
chat = open -a Slack')
check "section header" 'has "$out" "section${tab}Personal"'
check "item name and command are trimmed" 'has "$out" "item${tab}blog${tab}cursor /home/me/src/blog"'
check "separator" 'has "$out" "separator"'
check "entries keep their order" '[ "$(printf "%s\n" "$out" | cut -f1 | tr "\n" " ")" = "path section item separator section item " ]'

out=$(parse 'Slack = open "slack://open?team=T1"
Chrome = open -na "Google Chrome" --args --profile-directory="Profile 1"')
check "command keeps = after the first one" 'has "$out" "item${tab}Slack${tab}open \"slack://open?team=T1\""'
check "command keeps quotes" 'has "$out" "item${tab}Chrome${tab}open -na \"Google Chrome\" --args --profile-directory=\"Profile 1\""'

out=$(parse 'a = cd ~ && ls ~/x "~/y" '"'"'~/z'"'"' ~user/w a~/b ~~')
check "~ expands at word starts, inside quotes too" 'has "$out" "item${tab}a${tab}cd /home/me && ls /home/me/x \"/home/me/y\" '"'"'/home/me/z'"'"' ~user/w a~/b ~~"'

out=$(parse 'PATH=/opt/homebrew/bin:~/.local/bin:/usr/bin')
check "PATH line sets the command PATH with ~ expanded" 'has "$out" "path${tab}/opt/homebrew/bin:/home/me/.local/bin:/usr/bin"'
check "PATH line is not a menu item" '! printf "%s\n" "$out" | grep -q "^item"'

out=$(parse 'x = true')
check "missing PATH line falls back to a default" 'printf "%s\n" "$out" | head -1 | grep -q "^path${tab}.*/usr/bin:/bin"'

out=$(parse '# comment

   # indented comment
x = true')
check "comments and blank lines are ignored" '[ "$(printf "%s\n" "$out" | wc -l | tr -d " ")" = 2 ]'

out=$(parse 'x = true
no equals sign
= no name
no command =')
status=$?
check "lines without a name or command are errors with line numbers" 'has "$out" "error${tab}2${tab}no equals sign" && has "$out" "error${tab}3${tab}= no name" && has "$out" "error${tab}4${tab}no command ="'
check "errors still keep the good items" 'has "$out" "item${tab}x${tab}true"'
check "errors give exit code 2" '[ $status = 2 ]'

out=$(parse 'HOTKEY = Cmd + ctrl + l
x = true')
check "HOTKEY is normalized and is not a menu item" 'has "$out" "hotkey${tab}ctrl+cmd+L" && ! printf "%s\n" "$out" | grep -q "^item${tab}HOTKEY"'
check "HOTKEY accepts option/alt, digits and space" '[ "$(parse "HOTKEY=alt+shift+cmd+7" | grep ^hotkey)" = "hotkey${tab}opt+shift+cmd+7" ] && [ "$(parse "HOTKEY=option+space" | grep ^hotkey)" = "hotkey${tab}opt+space" ]'
check "no HOTKEY line means no hot key" '! parse "x = true" | grep -q ^hotkey'
out=$(parse 'HOTKEY=shift+L
HOTKEY=cmd+F13
HOTKEY=cmd+L+K
HOTKEY=cmd')
check "HOTKEY needs cmd/ctrl/opt and exactly one known key" '[ "$(printf "%s\n" "$out" | grep -c ^error)" = 4 ] && ! printf "%s\n" "$out" | grep -q ^hotkey'

check "chrome-profile needs a profile folder" '! bin/chrome-profile 2>/dev/null'
check "chrome-profile rejects an unknown profile folder" '! bin/chrome-profile "no such profile $$" 2>/dev/null'

check "missing file gives exit code 1" '! "$T/ml" --print "$T/nope" 2>/dev/null'
check "example config has no errors" '"$T/ml" --print menu.conf.example >/dev/null'

exit $fail
