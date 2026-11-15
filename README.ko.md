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
Chrome         = ~/.local/bin/chrome-profile "Profile 1"
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
| `HOTKEY=...` | 메뉴를 여는 전역 단축키, 선택 사항 (아래 설명) |
| `# ...` | 주석. 빈 줄도 무시합니다. |

- 경로 앞의 `~`는 홈 폴더로 바뀝니다. 따옴표 안에서도 바뀝니다.
- 명령은 백그라운드에서 실행되어, 오래 걸려도 메뉴가 멈추지 않습니다. 종료 코드가 0이 아니면 종료 코드와 오류 출력을 알림으로 보여 줍니다.
- 읽을 수 없는 줄은 메뉴에 줄 번호와 함께 경고로 표시됩니다.
- 터미널에서 파일 확인: `~/Applications/MenubarLauncher.app/Contents/MacOS/MenubarLauncher --print`

### PATH

로그인할 때 실행된 앱은 `~/.zshrc`를 읽지 않아서, Homebrew, nvm, pipx 등으로 설치한 도구를 찾지 못합니다. 그 폴더들을 `PATH=` 줄에 적어 주세요. 폴더는 터미널에서 `dirname "$(command -v <도구>)"`로 알 수 있습니다. `PATH=` 줄이 없으면 `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`을 씁니다.

### 단축키

```ini
HOTKEY=ctrl+cmd+J
```

어디서든 단축키를 누르면 마우스 커서 위치에 메뉴가 뜹니다. 화살표 키와 Return으로 고르고, Esc로 닫습니다. 앞에 있던 앱의 포커스는 그대로 유지되고, 손쉬운 사용 권한도 필요 없습니다.

- 보조 키: `cmd`, `shift`, `opt`(`option`, `alt`도 됨), `ctrl`. `cmd`, `opt`, `ctrl` 중 하나는 꼭 들어가야 합니다. 키: `A`–`Z`, `0`–`9`, `space`
- 키는 자판 위치로 인식하므로 한글 입력 상태에서도 동작합니다. 다만 메뉴에서 이름 앞글자를 쳐서 이동하는 기능은 입력 상태가 이름의 글자와 맞을 때만 됩니다(영문 이름은 영문 입력일 때).
- 전역 단축키는 그 조합을 모든 앱에서 가져갑니다. `cmd`+글자 조합은 거의 모든 앱이 쓰고, `ctrl`+`cmd`나 `opt`+`shift`+`cmd` 조합은 훨씬 덜 붐빕니다.
- 파일을 2초마다 확인하므로, 메뉴를 열지 않아도 저장하고 잠시 뒤 새 단축키가 동작합니다.

## 명령 예시

런처는 명령을 실행하기만 합니다. 이미 열린 창이 앞으로 나오는지는 명령에 달려 있고, 아래 명령들은 그렇게 동작합니다.

```ini
my-project = open -a Cursor ~/src/my-project
Codex      = open -b com.openai.codex
메모       = open -a Notes
Chrome     = ~/.local/bin/chrome-profile "Profile 1"
Slack      = open "slack://open?team=T0000000000"
빌드       = osascript -e 'tell app "Terminal" to do script "cd ~/src/my-project && make"' -e 'tell app "Terminal" to activate'
대시보드   = open https://example.com/dashboard
```

| 대상 | 명령 | 참고 |
|---|---|---|
| Cursor나 VS Code의 폴더 | `open -a Cursor <폴더>` | 그 폴더를 연 창이 있으면 앞으로 가져오고, 없으면 새 창을 엽니다. VS Code는 `open -a "Visual Studio Code" <폴더>`. `cursor <폴더>`보다 이쪽을 쓰세요. macOS 14부터는 앱이 스스로 다른 앱의 포커스를 가져올 수 없어서, `cursor <폴더>`는 Cursor가 이미 맨 앞에 있을 때만 창을 바꿉니다. |
| 번들 ID로 데스크톱 앱 | `open -b <번들 ID>` | 앱 이름이 바뀌어도 그대로 동작합니다. Codex 데스크톱 앱의 번들 ID는 `com.openai.codex`입니다(테스트한 버전에서는 앱 이름이 ChatGPT로 나옵니다). |
| 이름으로 아무 앱 | `open -a <앱>` | |
| Chrome 프로필 | `~/.local/bin/chrome-profile "<폴더>"` | 그 프로필에서 가장 최근에 쓴 창을 앞으로 가져오고, 창이 없으면 새로 엽니다. 앱과 함께 설치됩니다([동작 방식](#동작-방식) 참고). 처음 실행할 때 MenubarLauncher가 Google Chrome을 제어하도록 허용할지 묻습니다. |
| Slack 워크스페이스 | `open "slack://open?team=<팀 ID>"` | 워크스페이스가 하나면 `open -a Slack`으로 충분합니다. |
| 터미널에서 명령 실행 | `osascript -e 'tell app "Terminal" to do script "<명령>"' -e 'tell app "Terminal" to activate'` | 새 터미널 창을 엽니다. 처음 실행할 때 MenubarLauncher가 터미널을 제어하도록 허용할지 묻습니다. |
| 웹 페이지 | `open <URL>` | 기본 브라우저로 엽니다. |

### 값 찾기

터미널에서 실행하세요. 결과는 내 화면에만 출력됩니다.

```sh
# Chrome 프로필 폴더와 이름: Default = ..., Profile 1 = ...
python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/Library/Application Support/Google/Chrome/Local State"))); [print(k, "=", v["name"]) for k,v in d["profile"]["info_cache"].items()]'

# Slack 팀 ID와 워크스페이스 이름 (App Store판, 직접 내려받은 판 모두)
python3 -c 'import glob,json,os; f=sorted(glob.glob(os.path.expanduser("~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/storage/root-state.json"))+glob.glob(os.path.expanduser("~/Library/Application Support/Slack/storage/root-state.json")))[0]; [print(k, "=", v["name"]) for k,v in json.load(open(f))["workspaces"].items()]'

# 앱의 번들 ID
osascript -e 'id of app "ChatGPT"'
```

### 개인 정보와 비밀 값은 넣지 않기

- 프로젝트 경로, 프로필 폴더, 팀 ID는 개인 정보입니다. `~/.config/menubar-launcher/menu.conf`에만 두고, 저장소나 이슈, 공유하는 스크린샷에 붙여 넣지 마세요.
- 메뉴 파일은 평범한 텍스트이고, 항목에 마우스를 올리면 명령이 툴팁으로 보입니다. 비밀번호나 토큰은 명령에 절대 넣지 마세요. 꼭 필요하면 스크립트 안에서 키체인에서 읽게 하세요(예: `security find-generic-password -w -s <이름>`).

## 동작 방식

| 파일 | 설치 위치 | 역할 |
|---|---|---|
| `app/MenubarLauncher.m` | `~/Applications/MenubarLauncher.app` | 메뉴 막대 앱 |
| `menu.conf.example` | `~/.config/menubar-launcher/menu.conf` (처음 설치할 때만) | 메뉴 목록 |
| `bin/chrome-profile` | `~/.local/bin/chrome-profile` | Chrome 프로필 창을 앞으로 가져오기 (아래 설명) |
| LaunchAgent | `~/Library/LaunchAgents/io.github.tedkim81.menubar-launcher.plist` | 로그인할 때 앱을 실행하고, 비정상 종료되면 다시 띄웁니다. **종료**를 누르면 다음 로그인까지 꺼진 채로 있습니다. |

Chrome의 스크립팅 기능은 창이 어느 프로필 것인지 알려 주지 않습니다. 그래서 `chrome-profile`은 각 창의 ID를 프로필의 현재 세션 파일(`<프로필>/Sessions/Session_*`)에서 찾아 판단합니다. 기본 데이터 폴더를 쓰는 Chrome 프로세스를 PID로 지정해서 다루므로, 원격 디버깅용처럼 `--user-data-dir`로 따로 띄운 Chrome은 건드리지 않습니다. 방금(몇 초 안에) 연 창은 아직 세션 파일에 없을 수 있고, 그때는 새 창이 열립니다.

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
