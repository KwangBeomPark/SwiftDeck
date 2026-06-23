# AI_CODE_MAP.md

이 문서는 SwiftDeck 프로젝트의 구조, 설정 위치, 핵심 기능, 공개 업로드 전 주의사항을 정리한 프로젝트 전용 코드 지도입니다. AI 에이전트는 코드 변경 전 `myAGENT.md`와 함께 이 문서를 먼저 확인해야 합니다.

## 1. 프로젝트 개요

* 프로젝트명: SwiftDeck
* 현재 작업 폴더: `AHK_FolderHotKey`
* 목적: AutoHotkey v2 기반 Windows 포터블 오피스 자동화 도구
* 주요 기능: 즐겨찾기 폴더 메뉴, 빠른 프롬프트 실행, 프롬프트 팝업 메뉴, Hotstring 자동완성, 키 리매핑, 이모지/특수기호 선택기, 앱 설정 대시보드
* 실행 환경: Windows 10/11, AutoHotkey v2 또는 Ahk2Exe로 빌드한 단독 실행 파일
* 설정 저장 위치: `%AppData%\SwiftDeck\`

## 2. 폴더 구조와 주요 파일

```text
AHK_FolderHotKey/
├── src/
│   ├── SwiftDeck.ahk          # 앱 진입점, 전역 설정, Include, 시작 시 초기화, 트레이 메뉴
│   └── lib/
│       ├── Config.ahk         # 설정 파일 생성/읽기/쓰기/백업/복원/기본값
│       ├── Utils.ahk          # 안전 실행, 단축키 표시 변환, 번역 API, GUI 위치 보정
│       ├── Clipboard.ahk      # HTML/Plain Text 클립보드 처리와 메모리 해제
│       ├── Migration.ahk      # 기존 설정 마이그레이션과 인코딩 보정
│       ├── Theme.ahk          # UI 색상 상수와 다크모드 적용
│       ├── DashboardManager.ahk
│       ├── FolderManager.ahk
│       ├── PromptManager.ahk
│       ├── HotstringManager.ahk
│       ├── KeyRemapManager.ahk
│       ├── PreferencesManager.ahk
│       ├── FolderMenu.ahk
│       ├── PromptMenu.ahk
│       ├── HotstringRuntime.ahk
│       ├── EmojiPicker.ahk
│       ├── AppInfo.ahk
│       └── Manual.ahk
├── assets/
│   ├── SwiftDeck.ico
│   ├── demo.gif
│   ├── manual.png
│   ├── bmc_button.png
│   └── github_icon.png
├── dist/                      # 로컬 릴리즈 산출물 폴더, Git 제외
├── README.md
├── README.ko.md
├── LICENSE
├── myAGENT.md
├── AGENTS.md
├── AI_CODE_MAP.md
└── .gitignore
```

업로드 제외 또는 로컬 전용 대상:

* `.vscode/`
* `Backups/`
* `dist/`, `release/`, `build/`, `out/`
* `SwiftDeck.exe`, `SwiftDeck.zip`
* `test_json.ahk` 및 `test_json_out.txt`
* `*.bak`, `*.tmp`, `*.log`, `*.lnk`

## 3. 핵심 전역 변수와 설정 파일

* `g_appVersion`: `src/SwiftDeck.ahk`에서 정의. 앱 버전 표시와 대시보드 타이틀에 사용.
* `g_targetFolder`: `src/SwiftDeck.ahk`에서 `%AppData%\SwiftDeck\`로 정의. 기존 `%AppData%\AHK_FolderHotKey` 폴더가 있으면 SwiftDeck 폴더로 마이그레이션.
* `g_fileName_Folder`, `g_fileName_Hotkey`, `g_fileName_Hotstring`, `g_fileName_KeyRemap`: 설정 파일명 상수.
* `g_filePath_Folder`, `g_filePath_Hotkey`, `g_filePath_Hotstring`, `g_filePath_KeyRemap`: 설정 파일 전체 경로.
* `g_registeredHotstrings`: 동적으로 등록된 Hotstring 추적용 배열.
* `g_registeredKeyRemaps`: 동적으로 등록된 키 리매핑 추적용 `Map`.
* `g_FolderMenuCache`: `src/lib/FolderMenu.ahk`에서 관리하는 폴더 메뉴 캐시.

관리되는 설정 파일:

* `App02_01FavFolderSetting_v2_DoNotDelete.ini`: 즐겨찾기 폴더와 기본 앱 설정
* `App02_02HotkeySetting_v2_DoNotDelete.ini`: 빠른 프롬프트 슬롯
* `App02_03HotstringSetting_DoNotDelete.ini`: Hotstring 그룹과 항목
* `App02_04KeyRemap_DoNotDelete.ini`: 키 리매핑 항목

## 4. 주요 기능별 위치

* 앱 초기화: `src/SwiftDeck.ahk`의 `OnStartup()`
* 트레이 메뉴: `src/SwiftDeck.ahk`의 `SetupTrayMenu()`
* 앱 자산 경로 탐색: `src/SwiftDeck.ahk`의 `GetAppAssetPath()`
* 설정 파일 관리: `src/lib/Config.ahk`의 `ConfigGetManagedFiles()`, `InitializeAllConfigs()`, `ConfigWriteTextFileSafely()`, `BackupConfigs()`, `RestoreConfigs()`
* 기본 설정 템플릿: `src/lib/Config.ahk`의 `GetDefaultFolderData()`, `GetDefaultHotkeyData()`, `GetDefaultHotstringData()`, `GetDefaultKeyRemapData()`
* 즐겨찾기 폴더 메뉴: `src/lib/FolderMenu.ahk`의 `ShowFavoritesMenu()`
* 현재 Explorer 폴더 추가: `src/lib/FolderMenu.ahk`의 `GetActiveExplorerPath()`, `AddCurrentExplorerFolder()`
* 빠른 프롬프트 실행: `src/lib/PromptManager.ahk`의 `PromptManager.ProcessQuickPrompt()` 및 `ExecutePromptItem()`
* 프롬프트 팝업 메뉴: `src/lib/PromptMenu.ahk`의 `ShowPromptMenu()`
* Hotstring 로딩/실행: `src/lib/HotstringRuntime.ahk`의 `LoadHotstrings()`
* Hotstring 설정 UI: `src/lib/HotstringManager.ahk`
* 키 리매핑 설정/런타임: `src/lib/KeyRemapManager.ahk`
* 이모지/특수기호 메뉴: `src/lib/EmojiPicker.ahk`의 `BuildEmojiMenu()`
* 앱 정보와 유지보수 도구: `src/lib/AppInfo.ahk`
* 내장 도움말: `src/lib/Manual.ahk`
* 안전 실행과 셸 인젝션 방어: `src/lib/Utils.ahk`의 `RunSafely()`
* 번역 API: `src/lib/Utils.ahk`의 `GoogleTranslate()`
* 멀티 모니터 GUI 위치 보정: `src/lib/Utils.ahk`의 `ShowCenteredOnMouse()`

## 5. 기본 단축키

* `F1`: 즐겨찾기 폴더 메뉴
* `Ctrl + F1`: 현재 Explorer 폴더를 즐겨찾기에 추가
* `Win + Numpad 0~9`: 빠른 프롬프트 슬롯 실행
* `Shift + Win + Space`: 프롬프트 팝업 메뉴
* `Ctrl + Win + Space`: 이모지/특수기호 메뉴
* `Ctrl + Win + Escape`: 앱 종료

사용자는 `src/lib/PreferencesManager.ahk`의 일반 설정 UI를 통해 일부 단축키를 변경할 수 있다.

## 6. 자산 및 릴리즈 산출물 관리

* README 이미지와 앱 아이콘은 `assets/`에 둔다.
* `src/SwiftDeck.ahk`는 `GetAppAssetPath()`로 `assets/`, `../assets/`, 실행 파일 옆 경로를 순서대로 확인한다.
* 로컬 빌드 결과물과 GitHub Releases에 올릴 `.exe`, `.zip`은 `dist/`에 둔다.
* `dist/`는 Git 제외 대상이며 저장소 본문에 커밋하지 않는다.
* Ahk2Exe 아이콘 지시자는 `src/SwiftDeck.ahk`의 `;@Ahk2Exe-SetMainIcon ..\assets\SwiftDeck.ico`를 사용한다.

## 7. 외부 의존성과 네트워크 동작

* 런타임 의존성: AutoHotkey v2
* 빌드 도구: AutoHotkey에 포함된 Ahk2Exe
* Windows COM 사용:
  * `Shell.Application`: 활성 Explorer 경로 확인
  * `WinHttp.WinHttpRequest.5.1`: 번역 API 호출
  * `htmlfile`: 내장 도움말 HTML 표시
* 외부 네트워크 동작:
  * `GoogleTranslate()` 사용 시 선택한 텍스트가 `https://translate.googleapis.com/translate_a/single`로 전송된다.
  * `AppInfo.ahk`는 번들 이미지가 없을 경우 Buy Me a Coffee 버튼 이미지와 GitHub favicon을 다운로드할 수 있다.
  * GitHub/Buy Me a Coffee 링크는 사용자가 클릭할 때 브라우저로 열린다.

## 8. 공개 업로드 전 보안 주의사항

* `Backups/`에는 실제 사용자 설정 백업, 회사/조직명, 네트워크 드라이브, 개인 PC 경로가 들어갈 수 있으므로 공개 저장소에 올리지 않는다.
* `dist/`의 `.exe`, `.zip`은 저장소 커밋 대상이 아니라 필요 시 GitHub Releases 자산으로 분리한다.
* `test_json.ahk` 같은 임시 검증 파일과 `test_json_out.txt` 출력 파일은 공개 소스에서 제외한다.
* README는 번역 API와 공개 UI 자산 다운로드 가능성을 명확히 설명해야 한다.
* 비밀번호, API Key, Token, 회사 내부 경로, 개인 계정 경로, 실제 업무 문구가 샘플 설정에 포함되지 않았는지 `rg`로 재검색한다.

## 9. 프로젝트 특수 주의사항

* 설정 파일은 한글 깨짐 방지를 위해 UTF-16로 작성된다.
* `ConfigWriteTextFileSafely()`는 임시 파일과 롤백 파일을 사용하므로 임의 리팩토링 시 데이터 손상 가능성을 검토해야 한다.
* 클립보드 HTML 처리에서는 `SetClipboardData` 실패 시 할당 메모리를 `GlobalFree`로 해제해야 한다.
* `RunSafely()`는 `&`, `|`, `>`, `<` 문자를 차단해 셸 인젝션 위험을 줄인다.
* GUI는 DPI scaling과 멀티 모니터 환경을 고려해 `ShowCenteredOnMouse()`를 우선 사용한다.
* `A_Startup`에는 `SwiftDeck.lnk` 시작프로그램 바로가기를 만들거나 삭제할 수 있다. Registry key를 직접 쓰지는 않는다.

## 10. 변경 이력

* 2026-06-23: 앱 버전 변경 (8.1.1 -> 1.1.1)
* 2026-06-14: GitHub 공개 업로드 준비 기준 반영. `myAGENT.md` 추가, 공개 업로드 제외 대상과 외부 네트워크 동작 정리.
* 2026-06-14: 루트 혼잡을 줄이기 위해 `src/`, `assets/`, `dist/` 구조로 분리. 코드 자산 경로, README, `.gitignore`, 코드 지도 갱신.
