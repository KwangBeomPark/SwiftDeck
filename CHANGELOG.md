# Changelog

## 1.3.1 — 2026-08-23

### Settings UX

- Folders, Prompts, Hotstrings, Key Remap의 별도 `Save & Apply` 버튼을 제거했습니다.
- 항목 추가·수정·삭제·순서 변경과 Hotstring 그룹 변경을 성공 즉시 안전 저장하고 런타임에 적용합니다.
- 파일 저장이 실패하면 디스크의 마지막 정상 상태를 다시 불러오고 변경이 적용되지 않았음을 안내합니다.
- 여러 단축키 값을 함께 조정하는 General 탭만 미저장 상태와 `Save & Apply` 흐름을 유지합니다.

### Update visibility

- 새 릴리스가 감지되면 App Settings 헤더에 `New version vX available`을 바로 표시합니다.
- 헤더에 `App Info`와 별도의 `Update` 버튼을 표시해, 정보 접근은 유지하면서 다운로드·검증·재시작을 바로 시작할 수 있습니다.

### Layout & Manual

- 각 설정 탭의 상단 여백과 우측 액션 버튼 폭을 통일해 `Reset` 등의 문구가 잘리지 않도록 조정했습니다.
- 상단의 Manual/App Info는 기존 정렬을 유지하고, 업데이트가 있을 때만 둘 아래에 전용 `Update to vX` 버튼을 표시합니다.
- 내장 매뉴얼은 마지막으로 선택한 언어를 저장하고 다음에 그 언어로 열립니다.

## 1.3.0 — 2026-08-23

### Automatic updates

- GitHub Releases의 최신 정식 버전을 시작 후 지연 확인하고, 마지막 성공 확인 결과를 24시간 캐시합니다.
- App Information과 트레이 메뉴에서 현재 버전과 GitHub 최신 버전을 직접 확인할 수 있습니다.
- 새 버전이 있으면 `Update & Restart`로 현재 실행 파일과 같은 경로에 다운로드하고 SHA-256을 검증합니다.
- 실행 중인 파일을 직접 덮어쓰지 않고 임시 자기 복사본이 종료·교체·재실행을 처리합니다.
- 새 버전이 정상 시작하지 못하면 기존 실행 파일을 자동 복구하고 다시 실행합니다.
- 소스 실행 모드와 읽기 전용 폴더에서는 자동 교체를 차단하고 수동 다운로드 경로를 안내합니다.

### Reliability

- 트레이에서 App Information을 열 때 `+Owner0`이 전달되어 발생하던 오류를 수정했습니다.
- 공개 릴리스 자산을 `SwiftDeck.exe`, `SwiftDeck.zip`, `SwiftDeck.update.ini`로 표준화했습니다.
- 공개된 릴리스와 태그를 삭제·재생성하지 않는 opt-in 릴리스 파이프라인으로 변경했습니다.

## 1.2.0 — 2026-08-22

### UX/UI

- 클릭 가능한 `Text` 컨트롤을 표준 `Button`으로 교체해 키보드 포커스와 Windows 접근성 트리 인식을 개선했습니다.
- Folders, Prompts, Hotstrings, Key Remap, General의 저장 버튼에 미저장 상태를 표시합니다.
- 설정 창을 닫거나 앱을 종료할 때 미저장 변경이 있으면 Save All, Discard, Keep Editing을 선택할 수 있습니다.
- 각 탭 Reset, Restore, Factory Reset도 다른 탭의 미저장 변경을 버리기 전에 추가 경고를 표시합니다.
- 대시보드 높이를 약 583px로 줄이고 모든 탭의 주요 목록·미리보기·저장 버튼을 작은 화면에서도 보이도록 재배치했습니다.
- General의 `Data, Startup & Recovery`에 자동 시작, 설정 폴더, 저장 설정 백업, 복원, 초기화를 통합했습니다.
- App Info는 버전, 사용 통계, 설정 경로, 지원 정보에 집중하도록 단순화했습니다.

### Hotkeys and reliability

- Favorites 단축키를 바꿔도 Explorer의 현재 폴더 추가 단축키가 겹치지 않도록 첫 번째 미사용 수정키를 파생합니다.
- Favorites, Add Current Folder, Quick Prompts, Prompt Popup, Emoji, Exit 단축키의 충돌을 저장 전에 검사합니다.
- Prompt 슬롯 라벨은 Numpad/Standard 설정과 동일하게 표시하며 1~9, 0 순서를 유지합니다.
- Prompt Popup 단축키 정의를 `GetPromptMenuHotkey()`로 중앙화했습니다.
- 자동 시작 바로가기는 임시 파일을 검증한 뒤 교체하며, 실패하면 체크박스를 실제 파일 상태로 되돌립니다.
- 멀티 모니터의 음수 좌표와 작업 영역 경계를 처리하고, 화면보다 큰 창은 작업 영역 좌측/상단에 배치합니다.

### Documentation and verification

- 내장 매뉴얼 상단에 현재 적용된 단축키를 동적으로 표시하고 영어/한국어 저장·복구 안내를 갱신했습니다.
- 영어/한국어 README의 General, 백업/복원, 미저장 보호, Explorer 폴더 추가 단축키 설명을 현재 동작과 맞췄습니다.
- 오래된 버전 정보를 담은 정적 매뉴얼 이미지는 README에서 제거하고, 현재 설정을 반영하는 내장 Manual 경로를 안내합니다.
- `tests/UtilsTests.ahk`를 추가해 단축키 파생/충돌 검사와 멀티 모니터 위치 계산을 회귀 검증합니다.
- AutoHotkey v2 문법 검사, 유틸리티 테스트, Windows 실제 UI 확인, 단계별 Claude Code CLI 독립 리뷰를 수행했습니다.
