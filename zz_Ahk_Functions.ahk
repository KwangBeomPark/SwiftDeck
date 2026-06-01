; 유틸리티 함수 라이브러리 (재사용 가능 함수 모음)
; 최종 수정: 2026-05-08
#SingleInstance
#Requires AutoHotkey v2.0+

; 함수: file_mostRecentFile
; 설명: 지정된 디렉토리에서 가장 최근에 수정된 파일을 모든 드라이브에서 검색하여 반환
file_mostRecentFile(sSearchDirectory, sWildCard) {
    mostRecentFile := ""
    mostRecentTime := 0
    vDrivers := ["Z","Y","X","W","V","U","T","S","R","Q","P","O","N","M","L","K","J","I","H","G","F","E","D","C","B","A"]

    ; 후행 역슬래시 확인
    if (SubStr(sSearchDirectory, -1) != "\")
        sSearchDirectory := sSearchDirectory . "\"

    ; 와일드카드 정리
    if !InStr(sWildCard, "*")
        sWildCard := "*" . sWildCard . "*"

    sUpdatedDir := SubStr(sSearchDirectory, 3)

    for index, vDriver in vDrivers {
        folderPath := vDriver . ":" . sUpdatedDir
        if FileExist(folderPath) {
            loop files folderPath . sWildCard, "F" {
                fileTime := A_LoopFileTimeModified
                if (fileTime > mostRecentTime) {
                    mostRecentTime := fileTime
                    mostRecentFile := A_LoopFileFullPath
                }
            }
        }
    }

    return (mostRecentFile != "") ? mostRecentFile : "No files match"
}

file_mostRecentFolder(folderName) {
    drives := ["Z", "Y", "X", "W", "V", "U", "T", "S", "R", "Q", "P", "O", "N", "M", "L", "K", "J", "I", "H", "G", "F",
        "E", "D", "C", "B", "A"]
    foundPath := ""
    ; 드라이브 문자 제거 후 나머지 경로를 기반으로 전부 순회
    sUpdatedDir := SubStr(folderName, 3)
    for index, drive in drives {
        loop files, drive . "\*", "D" {
            if FileExist(A_LoopFileName) = "D" {
                return A_LoopFileFullPath
            } else {
                return "No Folder match"
            }
        }
    }

}

file_getFileName(path) {
    ; 경로에서 파일명과 확장자를 추출
    SplitPath path, &name
    return name
}

file_openFolder(folderPath, Args*) {
    if !folderPath {
        MsgBox "Folder path is not specified.", "Error", 48
        return
    }

    ; 파일과 폴더 구분
    if FileExist(folderPath) && !DirExist(folderPath) {
        ; 파일이면 해당 파일을 선택한 상태로 열기
        Run('explorer.exe /select,"' folderPath '"')
        return
    }

    ; 폴더가 존재하는지 확인
    if !DirExist(folderPath) {
        MsgBox "The specified folder does not exist.`n`n" folderPath, "Error", 48
        return
    }

    ; 폴더 열기
    Run('explorer.exe "' folderPath '"')
}



file_addTrailBackslash(path) {
; 함수: file_addTrailBackslash(path)
; 설명: 지정된 경로의 끝에 역슬래시(\)가 없으면 추가해줍니다.
;       예) C:\Temp -> C:\Temp\
    if !RegExMatch(path, "[\\/]$")
        path .= "\"
    return path
}

file_getLastFolderName(path) {
    trimmedPath := RTrim(path, "\/")
    ; Windows 경로는 주로 역슬래시(\)를 사용하지만, 
    ; 여기서는 RTrim을 통해 끝의 /나 \를 제거한 후 
    ; StrSplit을 "\\"로 수행해 마지막 폴더명을 구합니다.
    partList := StrSplit(trimmedPath, "\")

    if (partList.Length) {
        return partList[partList.Length]
    } else {
;   - 가장 마지막 폴더 이름, 없으면 전체 경로를 반환
        return path
    }
}

file_getFoldersList(folderPath, attributes := "") {
; 함수: file_getFoldersList(folderPath, attributes := "")
; 설명: 특정 폴더 안의 서브 폴더 목록(경로)을 배열로 반환합니다.
;   - attributes : 'D'와 같은 속성 필터를 지정할 수 있음 (기본값: "")
;   - folderList : 하위 폴더 경로가 담긴 배열
    folderList := []
    loop files folderPath, attributes {
        if InStr(A_LoopFileAttrib, "H")   ; 숨김 속성(H)이 있으면 건너뜀
            continue
        folderList.Push(A_LoopFileFullPath)
    }  ; 블록 종료
    return folderList
}



data_Capitalize(str) {
    return StrUpper(SubStr(str, 1, 1)) SubStr(str, 2)
}

data_Extract_ExcludeString(source, excl_Sting, optCapital :=false) {
    result := ""
    targetStrings := StrSplit(source, [",", ";"," "]) ; 여러 개 이메일을 구분하기 위해 , 또는 ; 기준으로 나눔
    for each, sTarget in targetStrings {
        sTarget := Trim(sTarget)  ; 앞뒤 공백 제거
        ; 도메인 제거: "@lge.com" 제거
        if InStr(sTarget, excl_Sting){
            if (optCapital){
                sTarget := data_Capitalize(StrReplace(sTarget, excl_Sting))
            }
            else{
                sTarget := StrReplace(sTarget, excl_Sting)
            }
        }
        ; 여전히 @가 남아있으면 제거 (오타 대비)
        ; sTarget := StrSplit(sTarget, "@")[1]
        result := result . sTarget
    }

    return result
}

; str_RegExMatchAll 함수 - 주어진 문자열(haystack)에서 정규식 패턴(pattern)에 일치하는 모든 결과를 배열로 반환
; 2024-06-13 수정: 상세 주석 추가 (by GitHub Copilot)
str_RegExMatchAll(haystack, pattern) {
    result := [] ; 결과를 저장할 배열 생성
    pos := 1 ; 검색 시작 위치 초기화
    ; haystack 전체에서 pattern에 일치하는 부분을 반복적으로 찾음
    while RegExMatch(haystack, pattern, &m, pos) {
        result.Push(m[0]) ; 일치한 전체 문자열을 결과 배열에 추가
        pos := m.Pos + m.Len ; 다음 검색 시작 위치를 현재 일치한 부분 이후로 이동
    }
    return result ; 모든 일치 결과 배열 반환
}

; =================================================================================
; --- 폴더 메뉴 캐싱 시스템 ---
; =================================================================================

; 전역 캐시 저장소 선언 (최상위 및 1단계 폴더 캐싱)
global g_FolderMenuCache := Map()

; 함수: file_getFolderTreeHash(sPath0)
; 설명: 대상 폴더(Level 0)와 1단계 하위 폴더(Level 1)들의 '수정 시간'을 합쳐서 해시 문자열로 반환
file_getFolderTreeHash(sPath0) {
    hashStr := ""
    try {
        hashStr := FileGetTime(sPath0, "M")
    } catch {
        return "ERROR"
    }
    
    loop files file_addTrailBackslash(sPath0) . "*", "D" {
        if InStr(A_LoopFileAttrib, "H")
            continue
        try hashStr .= "|" . A_LoopFileTimeModified
    }
    return hashStr
}

; 함수: gui_makeFolderMenu
; 설명: 지정된 경로의 폴더 구조를 기반으로 다단계 컨텍스트 메뉴를 생성합니다.
; 작성일: 2024-06-13 (수정), 2026-05-01 (폴더 개수 제한 추가), 2026-05-08 (캐싱 추가)
gui_makeFolderMenu(sPath0, sMenu0) {
    global g_FolderMenuCache
    maxLv1 := 30  ; 1단계 하위 폴더 최대 표시 개수
    maxLv2 := 20  ; 2단계 하위 폴더 최대 표시 개수

    MenuLv0 := Menu()
    ; 폴더가 존재하지 않거나 드라이브가 아예 없으면 경고 메뉴 항목을 보여줌
    if !FileExist(sPath0) || !InStr(FileExist(sPath0), "D") {
        MenuLv0.Add("No Folder Exist: " . sPath0, ShowFolderWarningMsg.Bind())
        return MenuLv0
    }

    ; [캐싱 로직 시작]
    ; 현재 폴더 구조의 수정 시간 해시 추출 (네트워크라도 1단계까지만 읽으므로 매우 빠름)
    currentHash := file_getFolderTreeHash(sPath0)
    
    ; 캐시 검사
    if (g_FolderMenuCache.Has(sPath0)) {
        cacheObj := g_FolderMenuCache[sPath0]
        if (cacheObj.Hash == currentHash) {
            return cacheObj.Menu  ; 시간이 일치하면 즉시 캐시 메뉴 반환
        }
    }
    ; [캐싱 로직 끝]

    menuLv1 := Menu()
    ; 상위 폴더(lv0) 열기 메뉴 항목 추가
    menuLv1.Add("Open " . sMenu0, file_openFolder.Bind(sPath0))
    menuLv1.Add()  ; 구분선

    ; -------------------- 1단계 폴더 --------------------
    cntLv1 := 0
    for sPath1 in file_getFoldersList(file_addTrailBackslash(sPath0) . "*", "D") {
        cntLv1++
        if (cntLv1 > maxLv1) {
            menuLv1.Add("... (" . (cntLv1 - 1) . "+ more folders)", file_openFolder.Bind(sPath0))
            break
        }
        sMenu1 := file_getLastFolderName(sPath1)
        if !sMenu1
            continue

        menuLv2 := Menu()
        ; 상위 폴더(lv1) 열기 메뉴 항목 추가
        menuLv2.Add("Open " . sMenu1, file_openFolder.Bind(sPath1))
        menuLv2.Add()  ; 구분선

        ; -------------------- 2단계 폴더 --------------------
        cntLv2 := 0
        for sPath2 in file_getFoldersList(file_addTrailBackslash(sPath1) . "*", "D") {
            cntLv2++
            if (cntLv2 > maxLv2) {
                menuLv2.Add("... (" . (cntLv2 - 1) . "+ more folders)", file_openFolder.Bind(sPath1))
                break
            }
            sMenu2 := file_getLastFolderName(sPath2)
            if !sMenu2
                continue
            ; 2단계 폴더 메뉴 항목 추가
            menuLv2.Add(sMenu2, file_openFolder.Bind(sPath2))
        }
        ; 1단계 폴더 메뉴에 2단계 메뉴 추가
        menuLv1.Add(sMenu1, menuLv2)
    }
    
    ; [캐시에 결과 저장]
    g_FolderMenuCache[sPath0] := { Menu: menuLv1, Hash: currentHash }
    return menuLv1
}

ShowFolderWarningMsg() {
    ; 함수: ShowFolderWarningMsg()
    ; 설명: 폴더가 존재하지 않거나 액세스할 수 없을 때 경고 메시지를 표시합니다.
    MsgBox("The specified folder could not be found. The network drive may be disconnected or inaccessible.",
        "Folder Not Found!", 0x0)
}

; =================================================================================
; --- GUI 유틸리티 및 테마 ---
; =================================================================================

; --- 테마 상수 정의 ---
global THEME_BG := "1E1E1E"
global THEME_PANEL := "2D2D30"
global THEME_ACCENT := "007ACC"
global THEME_TEXT := "FFFFFF"
global THEME_MUTED := "A0A0A0"

; 함수: gui_EnableDarkMode
; 설명: 윈도우 10/11의 기본 다크 모드 속성을 GUI 창의 타이틀바에 적용합니다.
gui_EnableDarkMode(hGui) {
    ; DWMWA_USE_IMMERSIVE_DARK_MODE: Windows 10 build 17763 에서는 19, Windows 11 에서는 20
    attr := 19
    if (VerCompare(A_OSVersion, "10.0.22000") >= 0)
        attr := 20
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hGui.Hwnd, "int", attr, "int*", 1, "int", 4)
}

; 함수: gui_ApplyTheme
; 설명: 일관된 색상, 폰트, 헤더 구조를 GUI에 적용합니다.
gui_ApplyTheme(guiObj, headerTitle := "", headerDesc := "") {
    gui_EnableDarkMode(guiObj)
    guiObj.BackColor := THEME_BG
    
    if (headerTitle != "") {
        ; 헤더 타이포그래피 (14pt Bold)
        guiObj.SetFont("s14 c" . THEME_TEXT . " bold", "Segoe UI")
        guiObj.Add("Text", "x20 y15 w420 h25 BackgroundTrans", headerTitle)
        
        if (headerDesc != "") {
            ; 보조 텍스트 (9pt Muted)
            guiObj.SetFont("s9 c" . THEME_MUTED . " norm", "Segoe UI")
            guiObj.Add("Text", "x20 y40 w420 h20 BackgroundTrans", headerDesc)
        }
    }
    
    ; 기본 폰트 설정 (10pt Text)
    guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
}

; =================================================================================
; --- 프롬프트 시퀀스 실행 엔진 (텍스트 + 특수키 혼합 입력) ---
; =================================================================================

; 함수: HasSpecialKeys(msg)
; 설명: 메시지에 {Enter}, {Tab}, {Wait:500} 등 특수키 태그가 포함되어 있는지 검사
;       태그가 없으면 기존 클립보드 붙여넣기 로직을 사용 (하위 호환)
HasSpecialKeys(msg) {
    return RegExMatch(msg, "\{[^}]+\}")
}

; 함수: ExecutePromptSequence(msg)
; 설명: 텍스트와 특수키 태그가 혼합된 문자열을 순서대로 실행
;   예: "admin{Tab}pass{Enter}" → 붙여넣기("admin") → Send("{Tab}") → 붙여넣기("pass") → Send("{Enter}")
;   - 텍스트 부분은 클립보드 붙여넣기로 처리 (줄바꿈이 Enter 제출로 오작동하는 것을 방지)
;   - 모든 동작 사이에 디폴트 딜레이 자동 삽입 (키 입력 누락 방지)
;   - {Wait:N}으로 명시적 대기 가능
ExecutePromptSequence(msg) {
    static DEFAULT_KEY_DELAY := 50
    static PASTE_DELAY := 100  ; 클립보드 붙여넣기 후 대기 (앱이 붙여넣기를 완료할 시간)
    pos := 1
    msgLen := StrLen(msg)

    while (pos <= msgLen) {
        ; 현재 위치에서 {…} 태그 매칭 시도
        if (RegExMatch(msg, "\{[^}]+\}", &m, pos) && m.Pos == pos) {
            tagContent := SubStr(m[0], 2, StrLen(m[0]) - 2)

            if (RegExMatch(tagContent, "i)^Wait:(\d+)$", &wm)) {
                ; 명시적 대기: {Wait:N}
                Sleep(Integer(wm[1]))
            } else if (RegExMatch(tagContent, "i)^(Ctrl|Alt|Shift|Win)\+")) {
                ; 조합키: {Ctrl+a}, {Alt+F4}, {Ctrl+Shift+Tab} 등
                Send(_ConvertComboKey(tagContent))
                Sleep(DEFAULT_KEY_DELAY)
            } else {
                ; 단일 특수키: {Enter}, {Tab}, {F1} 등
                Send("{" . tagContent . "}")
                Sleep(DEFAULT_KEY_DELAY)
            }
            pos := m.Pos + m.Len
        } else {
            ; 일반 텍스트: 다음 태그까지 또는 문자열 끝까지
            nextTag := RegExMatch(msg, "\{[^}]+\}", &nm, pos)
            if (nextTag > 0) {
                plainText := SubStr(msg, pos, nextTag - pos)
                pos := nextTag
            } else {
                plainText := SubStr(msg, pos)
                pos := msgLen + 1
            }
            ; 텍스트는 클립보드로 붙여넣기 (줄바꿈이 Enter 제출되는 문제 방지)
            if (plainText != "") {
                A_Clipboard := plainText
                ClipWait(1)
                Send("^v")
                Sleep(PASTE_DELAY)
            }
        }
    }
}

; 함수: _ConvertComboKey(tagContent)
; 설명: "Ctrl+a" → "^a", "Alt+F4" → "!{F4}", "Ctrl+Shift+Tab" → "^+{Tab}"
_ConvertComboKey(tagContent) {
    parts := StrSplit(tagContent, "+")
    modStr := ""
    keyPart := ""

    for i, part in parts {
        p := Trim(part)
        if (i < parts.Length) {
            switch StrLower(p) {
                case "ctrl":  modStr .= "^"
                case "alt":   modStr .= "!"
                case "shift": modStr .= "+"
                case "win":   modStr .= "#"
                default:      keyPart .= p . "+"
            }
        } else {
            keyPart .= p
        }
    }

    if (StrLen(keyPart) > 1)
        keyPart := "{" . keyPart . "}"

    return modStr . keyPart
}
