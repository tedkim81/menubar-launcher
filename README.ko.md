# Menubar Launcher

[English](README.md)

메뉴 막대 아이콘을 누르면 미리 정해 둔 바로 가기가 구역별로 나옵니다. 하나를 고르면 그 앱이나 창이 앞으로 나오고, 꺼져 있으면 실행됩니다.

바로 가기는 이름과 셸 명령 한 줄이라서, 터미널에서 실행할 수 있는 것은 모두 메뉴 항목이 될 수 있습니다. 에디터의 프로젝트 폴더, 브라우저 프로필, 채팅 워크스페이스, 명령을 실행하는 터미널 창 같은 것들입니다.

```
▦
├─ 개인
│   my-project
│   Chrome
│   Terminal agent
├─ ─────────
├─ 회사
│   work-project
│   Chrome (work)
│   Slack
├─ ─────────
│   목록 편집…
└─ 종료
```

## 설치

필요한 것: macOS, Command Line Tools(`xcode-select --install`)

```sh
git clone https://github.com/tedkim81/menubar-launcher.git
cd menubar-launcher
./install.sh
```

비밀번호는 묻지 않습니다. 설치 스크립트는 앱을 빌드하고, `menu.conf.example`을 `~/.config/menubar-launcher/menu.conf`로 복사하고(이미 있으면 그대로 둡니다), 로그인할 때마다 앱이 실행되게 등록합니다.

앱이 처음 실행될 때 macOS가 MenubarLauncher의 알림을 허용할지 묻습니다. 허용하기 전에도 오류 알림은 뜨지만, 스크립트 편집기 이름으로 뜹니다.

## 메뉴 파일

`~/.config/menubar-launcher/menu.conf`는 메뉴를 열 때마다 새로 읽습니다. 저장하고 아이콘을 다시 누르면 바로 반영되고, 앱을 다시 띄울 필요가 없습니다. **목록 편집…** 을 누르면 기본 텍스트 편집기로 열립니다.

```ini
PATH=/opt/homebrew/bin:/usr/local/bin:~/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin

[개인]
my-project     = open -a Cursor ~/src/my-project
Chrome         = open -na "Google Chrome" --args --profile-directory="Profile 1"
Terminal agent = osascript -e 'tell app "Terminal" to do script "cd ~/src/my-project && codex"' -e 'tell app "Terminal" to activate'
---
[회사]
Slack          = open "slack://open?team=T0000000000"
```

| 줄 | 뜻 |
|---|---|
| `이름 = 명령` | 메뉴 항목. 명령은 `/bin/sh`로 실행하며, 첫 `=` 뒤는 모두 명령입니다. |
| `[제목]` | 구역 제목 |
| `---` | 구분선 |
| `PATH=...` | 모든 명령에 쓸 PATH (아래 설명) |
| `# ...` | 주석. 빈 줄도 무시합니다. |

- 경로 앞의 `~`는 홈 폴더로 바뀝니다. 따옴표 안에서도 바뀝니다.
- 명령은 백그라운드에서 실행되어, 오래 걸려도 메뉴가 멈추지 않습니다. 종료 코드가 0이 아니면 종료 코드와 오류 출력을 알림으로 보여 줍니다.
- 읽을 수 없는 줄은 메뉴에 줄 번호와 함께 경고로 표시됩니다.
- 터미널에서 파일 확인: `~/Applications/MenubarLauncher.app/Contents/MacOS/MenubarLauncher --print`

### PATH

로그인할 때 실행된 앱은 `~/.zshrc`를 읽지 않아서, Homebrew, nvm, pipx 등으로 설치한 도구를 찾지 못합니다. 그 폴더들을 `PATH=` 줄에 적어 주세요. 폴더는 터미널에서 `dirname "$(command -v <도구>)"`로 알 수 있습니다. `PATH=` 줄이 없으면 `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`을 씁니다.

## 창을 앞으로 가져오기

런처는 명령을 실행하기만 합니다. 이미 열린 창이 앞으로 나오는지는 명령에 달려 있습니다.

| 대상 | 명령 | 참고 |
|---|---|---|
| Cursor나 VS Code의 폴더 | `open -a Cursor <폴더>` | 그 폴더를 연 창이 있으면 앞으로 가져오고, 없으면 새 창을 엽니다. `cursor <폴더>`보다 이쪽을 쓰세요. macOS 14부터는 앱이 스스로 다른 앱의 포커스를 가져올 수 없어서, `cursor <폴더>`는 Cursor가 이미 맨 앞에 있을 때만 창을 바꿉니다. |
| 아무 앱 | `open -a <앱>` | |
| Chrome 프로필 | `open -na "Google Chrome" --args --profile-directory="<폴더>"` | 누를 때마다 그 프로필의 **새 창**이 열립니다. 프로필 폴더(`Default`, `Profile 1` 등)는 `~/Library/Application Support/Google/Chrome/Local State`의 `profile.info_cache`에 있습니다. |
| Slack 워크스페이스 | `open "slack://open?team=<팀 ID>"` | 팀 ID는 `T`로 시작합니다. 워크스페이스가 하나면 `open -a Slack`으로 충분합니다. |
| 터미널 명령 | `osascript -e 'tell app "Terminal" to do script "<명령>"' -e 'tell app "Terminal" to activate'` | 새 터미널 창을 엽니다. 처음 실행할 때 MenubarLauncher가 터미널을 제어하도록 허용할지 묻습니다. |

## 동작 방식

| 파일 | 설치 위치 | 역할 |
|---|---|---|
| `app/MenubarLauncher.m` | `~/Applications/MenubarLauncher.app` | 메뉴 막대 앱 |
| `menu.conf.example` | `~/.config/menubar-launcher/menu.conf` (처음 설치할 때만) | 메뉴 목록 |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.menubar-launcher.plist` | 로그인할 때 앱을 실행하고, 비정상 종료되면 다시 띄웁니다. **종료**를 누르면 다음 로그인까지 꺼진 채로 있습니다. |

메뉴 파일 해석 테스트:

```sh
./test/test.sh
```

## 제거

```sh
./uninstall.sh
```

앱과 로그인 항목을 지웁니다. 메뉴 파일은 `~/.config/menubar-launcher/`에 남겨 둡니다.

## 테스트 환경

macOS 15.1 (Apple silicon)

## 라이선스

[MIT](LICENSE)
