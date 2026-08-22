# Changelog

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
