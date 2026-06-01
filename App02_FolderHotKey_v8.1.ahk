#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName SwiftDeck
;@Ahk2Exe-SetVersion 8.1.0.0
;@Ahk2Exe-SetDescription SwiftDeck - FinOps Automation & HotKey Suite
;@Ahk2Exe-SetMainIcon SwiftDeck.ico

; =================================================================================
if FileExist(A_ScriptDir . "\SwiftDeck.ico") {
    TraySetIcon(A_ScriptDir . "\SwiftDeck.ico")
}

; --- 스크립트 설정 (Includes 및 전역 변수) ---
; =================================================================================
; --- 외부 파일 포함 ---
#Include %A_ScriptDir%/zz_Ahk_Functions.ahk

; [전역 변수] 앱 버전
global g_appVersion := "8.1"

; [전역 변수] 경로 설정
if (DirExist(A_AppData . "\AHK_FolderHotKey") && !DirExist(A_AppData . "\SwiftDeck")) {
    try DirMove(A_AppData . "\AHK_FolderHotKey", A_AppData . "\SwiftDeck", 1)
}
global g_targetFolder := A_AppData . "\SwiftDeck\"

; [전역 변수] 설정 파일명 (백업/복원 경로 구성에 사용)
global g_fileName_Folder := "App02_01FavFolderSetting_v2_DoNotDelete.ini"
global g_fileName_Hotkey := "App02_02HotkeySetting_v2_DoNotDelete.ini"
global g_fileName_Hotstring := "App02_03HotstringSetting_DoNotDelete.ini"
global g_fileName_KeyRemap := "App02_04KeyRemap_DoNotDelete.ini"

; [전역 변수] 설정 파일 전체 경로 (데이터 읽기/쓰기에 사용)
global g_filePath_Folder := g_targetFolder . g_fileName_Folder
global g_filePath_Hotkey := g_targetFolder . g_fileName_Hotkey
global g_filePath_Hotstring := g_targetFolder . g_fileName_Hotstring
global g_filePath_KeyRemap := g_targetFolder . g_fileName_KeyRemap

; [전역 변수] 핫키 관련
; global iCnt := 0 (PromptManager로 캡슐화됨)
; global dataGroup := [] (PromptManager로 캡슐화됨)
global g_registeredHotstrings := []
global g_registeredKeyRemaps := Map()

; --------------------------
; 프로그램 시작 시 자동 실행 (초기화 로직)
; --------------------------
OnStartup() ; 스크립트 실행 시 즉시 호출

OnStartup() {
    global g_fileName_Folder, g_fileName_Hotkey, g_fileName_Hotstring, g_fileName_KeyRemap, g_targetFolder, g_filePath_Folder

    ; 첫 실행 여부 확인 (설정 파일이 없으면 첫 실행)
    isFirstRun := !FileExist(g_filePath_Folder)

    ; 파일을 체크하고 없으면 생성하는 메인 프로세스 실행
    ; GetDefault...() 함수는 서버에도 파일이 없을 때 만들 '초기값'을 리턴합니다.
    InitializeConfig(g_fileName_Folder, GetDefaultFolderData())
    InitializeConfig(g_fileName_Hotkey, GetDefaultHotkeyData())
    InitializeConfig(g_fileName_Hotstring, GetDefaultHotstringData())
    InitializeConfig(g_fileName_KeyRemap, GetDefaultKeyRemapData())

    ; 기존 설정 마이그레이션 실행
    MigrateHotstringIni()

    ; 기존 설정 자동 백업 (.bak 파일 생성)
    BackupConfigs()

    ; 키 리맵 로드 및 OnExit 클린업 등록
    LoadKeyRemaps()
    OnExit(CleanupKeyRemaps)

    ; 설정 파일에서 단축키 환경 설정 읽어오기
    mainHotkey := "F1"
    promptMod := "#"
    promptUseNumpad := 1
    try {
        mainHotkey := IniRead(g_filePath_Folder, "Settings", "MainHotkey", "F1")
        promptMod := IniRead(g_filePath_Folder, "Settings", "PromptModifier", "#")
        promptUseNumpad := IniRead(g_filePath_Folder, "Settings", "PromptUseNumpad", "1")
    }

    ; 기존 설정 마이그레이션
    if (promptMod == "WinNumpad") {
        promptMod := "#"
        promptUseNumpad := 1
    } else if (promptMod == "WinAlt") {
        promptMod := "#!"
        promptUseNumpad := 0
    } else if (promptMod == "CtrlAlt") {
        promptMod := "^!"
        promptUseNumpad := 0
    }

    ; 동적 단축키 등록 (메인 메뉴)
    try {
        Hotkey(mainHotkey, (*) => ShowFavoritesMenu())
    } catch {
        mainHotkey := "F1"
        Hotkey("F1", (*) => ShowFavoritesMenu())
    }

    ; 상용구(프롬프트) 단축키 동적 등록
    loop 10 {
        num := A_Index - 1
        baseKey := promptUseNumpad ? "Numpad" . num : num
        hk := promptMod . baseKey
        try Hotkey(hk, BindPrompt(num))
    }

    ; 커스텀 트레이 메뉴 설정
    SetupTrayMenu(mainHotkey)

    ; 아이디어 1: 첫 실행 시 웰컴 스크린(매뉴얼) 자동 팝업
    if (isFirstRun) {
        SetTimer(() => OpenAppManual("EN"), -1000) ; 1초 뒤에 매뉴얼 창 띄우기 (default: EN)
    }

    ; 아이디어 2: 시작 알림 (TrayTip) 띄우기
    formattedHK := mainHotkey
    formattedHK := StrReplace(formattedHK, "^", "Ctrl+")
    formattedHK := StrReplace(formattedHK, "+", "Shift+")
    formattedHK := StrReplace(formattedHK, "#", "Win+")
    formattedHK := StrReplace(formattedHK, "!", "Alt+")
    TrayTip("App is running in the background.`nPress [" . formattedHK . "] anytime to open the menu!",
        "✅ SwiftDeck Ready",
        "Iconi")
    SetTimer(() => TrayTip(), -4000) ; 4초 뒤 알림 숨김 (OS 버전에 따라 다를 수 있음)
}

BindPrompt(num) {
    return (*) => PromptManager.ProcessQuickPrompt(num)
}

SetupTrayMenu(hotkeyLabel := "F1") {
    global g_targetFolder

    A_TrayMenu.Delete() ; 기존 AHK 트레이 메뉴 항목 제거 (Open, Pause, Exit 등)

    formattedHK := hotkeyLabel
    formattedHK := StrReplace(formattedHK, "^", "Ctrl+")
    formattedHK := StrReplace(formattedHK, "+", "Shift+")
    formattedHK := StrReplace(formattedHK, "#", "Win+")
    formattedHK := StrReplace(formattedHK, "!", "Alt+")

    A_TrayMenu.Add("📂 Open Folders Menu (" . formattedHK . ")", (*) => ShowFavoritesMenu())
    A_TrayMenu.Add()
    A_TrayMenu.Add("⚙️ App Settings", (*) => DashboardManager.Show(1))
    A_TrayMenu.Add("📁 Open Settings Folder", (*) => Run("explorer.exe `"" . g_targetFolder . "`""))
    A_TrayMenu.Add("📘 Open App Manual", (*) => OpenAppManual("EN"))
    A_TrayMenu.Add("ℹ️ App Information", (*) => ShowAppInformation())
    A_TrayMenu.Add()
    A_TrayMenu.Add("🔄 Reload App", (*) => Reload())
    A_TrayMenu.Add("❌ Exit App", (*) => ExitApp())

    ; 트레이 아이콘 더블 클릭 시 즐겨찾기 메뉴 열기
    A_TrayMenu.Default := "📂 Open Folders Menu (" . formattedHK . ")"
}

; --------------------------
; [핵심 함수] 파일 초기화 및 복사 로직
; --------------------------
InitializeConfig(fileName, defaultText) {
    global g_targetFolder

    ; 폴더가 없으면 생성
    if !DirExist(g_targetFolder) {
        DirCreate(g_targetFolder)
    }

    targetFile := g_targetFolder . fileName

    ; [1단계] 로컬에 이미 파일이 있는지 확인
    if (FileExist(targetFile)) {
        return ; 이미 파일이 존재하면 종료
    }

    ; [2단계] 로컬에 파일이 없을 경우 내장된 기본 템플릿으로 파일 생성
    try {
        ; UTF-8-RAW: BOM 없이 저장 (BOM이 있으면 Windows INI API가 첫 섹션을 인식 못함)
        FileAppend(defaultText, targetFile, "UTF-8-RAW")
    } catch {
        MsgBox("⚠️ Cannot create file in the target drive.`n`nPath: " . targetFile, "Error", "Iconx")
    }
}

; --------------------------
; 설정 파일 자동 백업 로직
; --------------------------
BackupConfigs(showMsg := false) {
    global g_targetFolder, g_fileName_Folder, g_fileName_Hotkey, g_fileName_Hotstring, g_fileName_KeyRemap
    global g_filePath_Folder, g_filePath_Hotkey, g_filePath_Hotstring, g_filePath_KeyRemap
    backupDir := g_targetFolder . "Backups\"
    if !DirExist(backupDir)
        DirCreate(backupDir)

    try {
        FileCopy(g_filePath_Folder, backupDir . g_fileName_Folder . ".bak", true)
        FileCopy(g_filePath_Hotkey, backupDir . g_fileName_Hotkey . ".bak", true)
        FileCopy(g_filePath_Hotstring, backupDir . g_fileName_Hotstring . ".bak", true)
        if FileExist(g_filePath_KeyRemap)
            FileCopy(g_filePath_KeyRemap, backupDir . g_fileName_KeyRemap . ".bak", true)
        if (showMsg)
            MsgBox("✅ Settings have been backed up successfully.", "Backup Complete", "Iconi")
    } catch {
        if (showMsg)
            MsgBox("❌ An error occurred during backup.", "Error", "Iconx")
    }
}

RestoreConfigs() {
    global g_targetFolder, g_fileName_Folder, g_fileName_Hotkey, g_fileName_Hotstring, g_fileName_KeyRemap
    global g_filePath_Folder, g_filePath_Hotkey, g_filePath_Hotstring, g_filePath_KeyRemap
    backupDir := g_targetFolder . "Backups\"

    msgRes := MsgBox(
        "⚠️ Are you sure you want to restore the settings from the last backup?`nYour current settings will be overwritten.",
        "Restore Backup", 262180)
    if (msgRes != "Yes")
        return

    try {
        FileCopy(backupDir . g_fileName_Folder . ".bak", g_filePath_Folder, true)
        FileCopy(backupDir . g_fileName_Hotkey . ".bak", g_filePath_Hotkey, true)
        FileCopy(backupDir . g_fileName_Hotstring . ".bak", g_filePath_Hotstring, true)
        if FileExist(backupDir . g_fileName_KeyRemap . ".bak")
            FileCopy(backupDir . g_fileName_KeyRemap . ".bak", g_filePath_KeyRemap, true)

        MsgBox("✅ Restoration complete. The app will now reload to apply changes.", "Restore Complete", 262208)
        Reload()
    } catch {
        MsgBox("❌ An error occurred during restoration. Please verify that the backup files exist.", "Error", 262160)
    }
}

ResetToDefaults(target := "All") {
    global g_filePath_Folder, g_filePath_Hotkey, g_filePath_Hotstring, g_filePath_KeyRemap

    msg := ""
    if (target == "All")
        msg := "⚠️ Are you sure you want to FACTORY RESET ALL settings?`nAll your custom configurations will be deleted.`n(Backups will not be affected.)"
    else
        msg := "⚠️ Are you sure you want to reset " . target . " to default?`nYour current settings for this feature will be deleted.`n(Backups will not be affected.)"

    if (MsgBox(msg, "Confirm Reset", 262452) != "Yes")
        return

    try {
        if (target == "All" || target == "Favorites") {
            try FileDelete(g_filePath_Folder)
            FileAppend(GetDefaultFolderData(), g_filePath_Folder, "UTF-8-RAW")
        }
        if (target == "All" || target == "Prompts") {
            try FileDelete(g_filePath_Hotkey)
            FileAppend(GetDefaultHotkeyData(), g_filePath_Hotkey, "UTF-8-RAW")
        }
        if (target == "All" || target == "Hotstrings") {
            try FileDelete(g_filePath_Hotstring)
            FileAppend(GetDefaultHotstringData(), g_filePath_Hotstring, "UTF-8-RAW")
        }
        if (target == "All" || target == "Key Remaps") {
            try FileDelete(g_filePath_KeyRemap)
            FileAppend(GetDefaultKeyRemapData(), g_filePath_KeyRemap, "UTF-8-RAW")
        }
        MsgBox("✅ Reset complete. The app will now reload.", "Success", 262208)
        Reload()
    } catch {
        MsgBox("❌ An error occurred while resetting settings.", "Error", 262160)
    }
}

; --------------------------
; [기본값 정의] 서버에 파일이 없을 때 생성될 내용
; --------------------------
GetDefaultFolderData() {
    return "[Settings]`n"
    . "MainHotkey=F1`n"
    . "PromptModifier=WinNumpad`n`n"
    . "[FolderMenu]`n"
    . "💾 C-Drive=C:\`n"
    . "-=-`n"
    . "📥 Downloads=" . EnvGet("USERPROFILE") . "\Downloads`n"
        . "🖥️ Desktop=" . A_Desktop . "`n"
        . "📄 Documents=" . A_MyDocuments . "`n"
        . "-=-`n"
        . "🚀 Startup=" . A_Startup . "`n"
        . "⚙️ AppData (Roaming)=" . A_AppData . "`n"
}

GetDefaultHotkeyData() {
    return "[Numpad1]`n"
    . "1 Outlook Active Email Analyzer=Please analyze this email thread and provide a highly condensed, dense summary in Korean. 1. If I am in CC (Cc/참조), outline the full context, background discussion, and core consensus of the entire thread so I don't miss the big picture. 2. For Tax/Legal/Compliance issues, detail the precise root cause, legal grounds/clauses, and technical terms. 3. For IT System/Finance/Sales improvements, clearly list: Who, What, Why, and the Risks if ignored. Output Style: Keep it extremely compact and space-efficient. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines between sections, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "2 Outlook Draft Business Reply=Write a polite and professional reply email in Korean and in English based on the following key points: [insert]. Ensure a formal business tone suitable for corporate communications. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "3 Outlook Terminology & Abbreviation Decoder=Analyze the email and explain any industry-specific jargon, technical terms, or abbreviations in Korean with simple, clear definitions. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "4 Outlook Recipient & Org Analyzer=Please analyze the recipients (To, Cc) of this email thread and identify the [organizations] in Korean. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n`n"
    . "[Numpad2]`n"
    . "1 Edge Active Page Analyzer=Please analyze the active document/page and provide a concise summary in Korean. First, identify the document type and characteristics (e.g., action-oriented task, informational report, legal/regulatory clause). Then, dynamically highlight approximately three key takeaways tailored to its type: if it requires action, outline the specific next steps; if it is for information, summarize the core concepts to understand; if it carries legal or compliance requirements, point out the essential obligations. Adapt the focus flexibly based on the document's nature. Output Style: Keep it extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines between sections, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "2 Edge Terminology & Abbreviation Decoder=Analyze the active document and explain any industry-specific jargon, technical terms, or abbreviations in Korean with simple, clear definitions. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "3 Edge Contract & Risk Analysis=Please analyze this document or contract and provide a highly condensed review in Korean. First, identify the document type and characteristics. 1) B2B Commercial Transactions: Highlight payment terms, liability limits, termination, acceptance terms, and penalties. 2) Service Agreements (SLA): Focus on SOW, SLA targets, IP ownership, confidentiality, and performance penalties. 3) Tax/Transfer Pricing (TP/CIP/VAT): Focus on tax compliance risks, transfer pricing alignments, customs/declarations, and liabilities. 4) HR/Labor/General Legal: Focus on employment terms, non-competes, compliance with labor standards, and dispute resolution. Dynamically list critical risks (if any). Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n`n"
    . "[Numpad3]`n"
    . "1 AI C-Level Business Drafter=Act as a Top-Tier Management Consultant and Senior Executive Assistant. Draft a highly professional, persuasive, and diplomatically polite business email/proposal based on the following context: [목적 및 핵심 전달 사항 입력]. Structure it logically with a clear introduction, bulleted main points for readability, and a strong call-to-action (CTA). Ensure the tone is C-level appropriate, avoiding fluff. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "2 AI Report Synthesizer=Act as a Senior Business Analyst. Analyze the following raw data, meeting transcript, or complex report text: [방대한 데이터 또는 난해한 텍스트 입력]. Extract the signal from the noise and synthesize it into a structured Executive Summary. Provide: 1. Core Issue/Objective. 2. 3 Key Takeaways (Data-backed if possible). 3. Immediate Action Items (Who needs to do what). Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "3 AI Strategy CSO Reviewer=Act as a sharp, experienced Chief Strategy Officer (CSO). Review the following draft proposal/idea: [기획안/아이디어 초안 입력]. I want ruthless but constructive feedback. 1. Identify logical gaps, weak arguments, or unaddressed risks. 2. Suggest specific, actionable improvements to make it bulletproof. 3. Provide an optimized, polished version of the core pitch. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks.`n"
    . "4 AI Corporate Translator=Act as an Expert Corporate Bilingual Translator. Translate the following text into [Target Language, default: Korean]: [번역할 텍스트 입력]. Do not translate literally word-for-word. Instead, capture the underlying business nuance, industry standard terminology, and professional tone. Elevate informal source text to a formal corporate standard. Provide only the translated result without conversational filler. Output Style: Extremely compact. Use only single newlines (\n) for line breaks. Never use double newlines (\n\n) or blank lines, so that when copied, the entire output pastes as a single, cohesive, tightly spaced text block while preserving the exact line breaks."
}

GetDefaultHotstringData() {
    return "[Meta]`n"
    . "SchemaVersion=3`n`n"
    . "[Group_Space_Bullets_Indicators]`n"
    . "z.z=▣`n"
    . "x.x=※`n"
    . "c.c=⊙`n"
    . "***.=★`n"
    . "**.=☆`n"
    . "v.v=✓`n"
    . "q.q=☑`n"
    . "r.r=☞`n`n"
    . "[Group_Space_Math]`n"
    . "d.d=Δ`n"
    . "+-=±`n"
    . "!==≠`n"
    . ">==≥`n"
    . "<==≤`n`n"
    . "[Group_Space_Arrows]`n"
    . ">>=→`n"
    . "<<=←`n"
    . "0++=↑`n"
    . "0--=↓`n"
    . "<->=↔`n"
    . "t.t=▶`n"
    . "y.y=▷`n`n"
    . "[Group_Space_Currency]`n"
    . "_usd=$`n"
    . "_eur=€`n"
    . "_gbp=£`n"
    . "_chf=₣`n"
    . "_pln=zł`n"
    . "_czk=Kč`n"
    . "_huf=Ft`n"
    . "_ron=lei`n"
    . "_bgn=лв`n"
    . "_try=₺`n"
    . "_rub=₽`n"
    . "_krw=₩`n`n"
    . "[Group_Space_For_Email]`n"
    . "_br=Best regards,`n"
    . "_tr=Thanks and regards,`n"
    . "_fyi=For your information,`n"
    . "_fya=For your action,`n"
    . "_asap=as soon as possible`n"
    . "pkb=park.kwangbemi@gmail.com"
}

GetDefaultKeyRemapData() {
    return "[Remaps]`n"
    . "; Format: SourceKey=DestinationKey`n"
    . "; Example: CapsLock=LButton`n"
    . "; Example: ScrollLock=Tab"
}

LoadHotstrings()
global EmojiMenu := Menu()
BuildEmojiMenu()

MigrateHotstringIni() {
    global g_filePath_Hotstring
    if !FileExist(g_filePath_Hotstring)
        return

    schemaVer := ""
    try schemaVer := IniRead(g_filePath_Hotstring, "Meta", "SchemaVersion", "")

    ; v1 → v3: 레거시 AutoReplace/SpaceReplace 통합 마이그레이션
    if (schemaVer == "" || schemaVer == "1") {
        backupPath := RegExReplace(g_filePath_Hotstring, "\.ini$", "_Backup_v1.ini")
        try {
            if FileExist(backupPath)
                FileDelete(backupPath)
            FileCopy(g_filePath_Hotstring, backupPath, true)
        }

        autoContent := ""
        try autoContent := IniRead(g_filePath_Hotstring, "AutoReplace", , "")
        spaceContent := ""
        try spaceContent := IniRead(g_filePath_Hotstring, "SpaceReplace", , "")

        try FileDelete(g_filePath_Hotstring)
        IniWrite("3", g_filePath_Hotstring, "Meta", "SchemaVersion")

        merged := ""
        if (autoContent != "")
            merged .= autoContent . "`n"
        if (spaceContent != "")
            merged .= spaceContent
        merged := Trim(merged, "`n")
        if (merged != "")
            IniWrite(merged, g_filePath_Hotstring, "Group_Space_Default")
        return
    }

    ; v2 → v3: Group_Auto_* 를 Group_Space_* 로 병합
    if (schemaVer == "2") {
        sections := ""
        try sections := IniRead(g_filePath_Hotstring)
        if (sections != "") {
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (SubStr(secName, 1, 11) != "Group_Auto_")
                    continue

                groupName := SubStr(secName, 12)
                spaceSec := "Group_Space_" . groupName

                autoContent := ""
                try autoContent := IniRead(g_filePath_Hotstring, secName, , "")
                if (autoContent != "") {
                    existingSpace := ""
                    try existingSpace := IniRead(g_filePath_Hotstring, spaceSec, , "")
                    merged := ""
                    if (existingSpace != "")
                        merged := existingSpace . "`n"
                    merged .= autoContent
                    IniWrite(Trim(merged, "`n"), g_filePath_Hotstring, spaceSec)
                }
                try IniDelete(g_filePath_Hotstring, secName)
            }
        }
        IniWrite("3", g_filePath_Hotstring, "Meta", "SchemaVersion")
    }
}

LoadHotstrings() {
    global g_filePath_Hotstring, g_registeredHotstrings

    ; 기존에 등록된 핫스트링 모두 비활성화
    for hsKey in g_registeredHotstrings {
        try Hotstring(hsKey, , "Off")
    }
    g_registeredHotstrings := []

    if !FileExist(g_filePath_Hotstring)
        return

    sections := ""
    try sections := IniRead(g_filePath_Hotstring)
    if (sections == "")
        return

    loop parse, sections, "`n", "`r" {
        secName := Trim(A_LoopField)
        if (secName == "" || secName == "Meta")
            continue
        if (SubStr(secName, 1, 12) != "Group_Space_")
            continue

        pairs := ""
        try pairs := IniRead(g_filePath_Hotstring, secName, , "")
        if (pairs == "")
            continue

        loop parse, pairs, "`n", "`r" {
            if !A_LoopField
                continue
            idx := InStr(A_LoopField, "=")
            if (idx > 0) {
                k := Trim(SubStr(A_LoopField, 1, idx - 1))
                v := Trim(SubStr(A_LoopField, idx + 1))
                if (k == ">" && v == "=≥")
                    k := ">=", v := "≥"
                else if (k == "<" && v == "=≤")
                    k := "<=", v := "≤"
                else if (k == "!" && v == "=≠")
                    k := "!=", v := "≠"
                if (k != "") {
                    hsKey := ":*:" . k
                    Hotstring(hsKey, v)
                    Hotstring(hsKey, , "On")
                    g_registeredHotstrings.Push(hsKey)
                }
            }
        }
    }
}

LoadKeyRemaps() {
    global g_filePath_KeyRemap, g_registeredKeyRemaps

    ; 기존 키 매핑 해제
    for srcKey, _ in g_registeredKeyRemaps {
        try Hotkey("*" . srcKey, , "Off")
    }
    g_registeredKeyRemaps := Map()

    if !FileExist(g_filePath_KeyRemap)
        return

    remapContent := ""
    try remapContent := IniRead(g_filePath_KeyRemap, "Remaps", , "")
    if (remapContent == "")
        return

    loop parse, remapContent, "`n", "`r" {
        if !A_LoopField
            continue
        idx := InStr(A_LoopField, "=")
        if (idx > 0) {
            src := Trim(SubStr(A_LoopField, 1, idx - 1))
            dst := Trim(SubStr(A_LoopField, idx + 1))
            if (src != "" && dst != "") {
                try {
                    Hotkey("*" . src, RemapGenericHandler.Bind(src, dst), "On")
                    g_registeredKeyRemaps[src] := dst

                    ; CapsLock 특수 예외 처리 (SetCapsLockState 복원 안전장치)
                    if (StrLower(src) == "capslock") {
                        Hotkey("+CapsLock", (*) => SetCapsLockState(!GetKeyState("CapsLock", "T")), "On")
                    }
                }
            }
        }
    }
}

RemapGenericHandler(srcKey, dstKey, ThisHotkey) {
    Send("{" . dstKey . " Down}")
    KeyWait(srcKey)
    Send("{" . dstKey . " Up}")
}

CleanupKeyRemaps(ExitReason, ExitCode) {
    global g_registeredKeyRemaps
    for src, dst in g_registeredKeyRemaps {
        if (dst != "")
            try Send("{" . dst . " Up}")
    }
    return 0
}

; --- 폴더 메뉴 핫키 (F1) ---
; (이제 OnStartup에서 동적으로 등록되므로 고정 단축키 정의는 주석 처리합니다)

ShowFavoritesMenu() {
    global g_filePath_Folder, g_targetFolder, g_fileName_Folder

    ; g_filePath_Folder에서 데이터를 읽어와 메뉴 구성
    if !FileExist(g_filePath_Folder) {
        MsgBox("⚠️ Cannot find the setting file.", "Error", 262160)
        return
    }

    folderItems := FolderManager.ReadFolderItems()

    ; --- 폴더 스캔 중 로딩 안내 (캐시 히트 시 즉시 사라짐) ---
    loadGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    loadGui.SetFont("s12", "Segoe UI")
    loadGui.Add("Text", "w280 Center", "📂 Loading folders...")
    loadGui.Show("xCenter yCenter NoActivate")

    mainContextMenu := Menu()
    for idx, obj in folderItems {
        rootFolderPath := obj.Path
        rootFolderName := obj.Name
        if rootFolderPath == "A_Startup"
            rootFolderPath := A_Startup

        if rootFolderName == "-" {
            mainContextMenu.Add()
            continue
        }
        mainContextMenu.Add(rootFolderName, gui_makeFolderMenu(rootFolderPath, rootFolderName))
    }

    loadGui.Destroy()  ; 스캔 완료 → 안내 메시지 제거

    mainContextMenu.Add()

    ; 현재 폴더 추가 및 관리
    mainContextMenu.Add("⭐ Add Current Folder  [Ctrl+F1]", (*) => AddCurrentExplorerFolder())
    if (GetActiveExplorerPath() == "") {
        mainContextMenu.Disable("⭐ Add Current Folder  [Ctrl+F1]")
    }
    mainContextMenu.Add("⚙️ App Settings", (*) => DashboardManager.Show(1))

    mainContextMenu.Show()
    return
}

; =================================================================================
; --- Ctrl+F1: 현재 탐색기 폴더를 즐겨찾기에 추가 ---
; =================================================================================
^F1:: AddCurrentExplorerFolder()

AddCurrentExplorerFolder() {
    explorerPath := GetActiveExplorerPath()
    if (explorerPath == "") {
        MsgBox(
            "⚠️ No Explorer window found. Please open Explorer and try again.",
            "Info", 262208
        )
        return
    }

    ib := InputBox("Enter a nickname for this folder:`nPath: " . explorerPath,
        "Add Folder", "w350 h150", file_getFileName(
            explorerPath))
    if (ib.Result != "OK" || ib.Value == "")
        return

    items := FolderManager.ReadFolderItems()
    items.Push({ Name: ib.Value, Path: explorerPath })
    FolderManager.WriteFolderItems(items)

    ToolTip("✅ Added & Saved")
    SetTimer(() => ToolTip(), -2000)
}

; --- 헬퍼: 활성 탐색기 창의 경로 가져오기 ---
GetActiveExplorerPath() {
    hwnd := WinExist("A")
    if (!hwnd)
        return ""

    try {
        winClass := WinGetClass(hwnd)
    } catch {
        return ""
    }

    if !(winClass ~= "(Progman|WorkerW|CabinetWClass|ExploreWClass)")
        return ""

    for window in ComObject("Shell.Application").Windows {
        if (window.HWND != hwnd)
            continue
        try {
            path := window.Document.Folder.Self.Path
            return path
        }
    }
    return ""
}

class FolderManager {
    static settingFile := ""

    static Init(filePath) {
        this.settingFile := filePath
    }

    static ReadFolderItems() {
        items := []
        global g_filePath_Folder
        if (FolderManager.settingFile == "")
            FolderManager.settingFile := g_filePath_Folder

        content := IniRead(FolderManager.settingFile, "FolderMenu", , "")
        if (content != "") {
            loop parse, content, "`n", "`r" {
                if !A_LoopField
                    continue
                idx := InStr(A_LoopField, "=")
                if (idx > 0) {
                    mName := Trim(SubStr(A_LoopField, 1, idx - 1))
                    fPath := Trim(SubStr(A_LoopField, idx + 1))
                    items.Push({ Name: mName, Path: fPath })
                }
            }
        }
        return items
    }

    static WriteFolderItems(items) {
        content := ""
        for item in items {
            content .= item.Name . "=" . item.Path . "`n"
        }
        if (content != "") {
            IniWrite(content, FolderManager.settingFile, "FolderMenu")
        } else {
            try IniDelete(FolderManager.settingFile, "FolderMenu")
        }
    }

    __New(parentGui := "") {
        global g_filePath_Folder
        FolderManager.Init(g_filePath_Folder)
        this.orderedItems := FolderManager.ReadFolderItems()
        this.parentGui := parentGui
        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.rGui := Gui("+AlwaysOnTop -MaximizeBox", "Folder Manager")
            gui_EnableDarkMode(this.rGui)
            this.BuildUI(this.rGui)
            this.rGui.Show("AutoSize")
        }
    }

    BuildUI(guiObj) {
        this.mainHwnd := guiObj.Hwnd
        startX := this.parentGui ? 35 : 25
        startY := this.parentGui ? 115 : 80
        guiObj.SetFont("s10", "Segoe UI")

        guiObj.Add("Text", "x" . startX . " y" . startY . " w400", "Saved Folders:")

        ; 리스트박스 텍스트 색상을 검은색으로 설정 (흰 배경에서 잘 보이도록)
        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 25) . " w310 h345")
        guiObj.SetFont("c" . THEME_TEXT)

        btnAddDir := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 25) . " w85 h35", "New (+)")
        btnSep := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 65) . " w85 h35", "Separator (-)")
        btnDel := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 105) . " w85 h35", "Delete (x)")

        btnUp := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 290) . " w85 h35", "Up (↑)")
        btnDown := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 330) . " w85 h35", "Down (↓)")

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY - 5) . " w85 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Favorites"))

        guiObj.SetFont("s10 cWhite bold", "Segoe UI")
        btnSave := guiObj.Add("Text", "x" . startX . " y" . (startY + 385) . " w405 h40 Center +0x200 +Border Background4A4F54", "💾 Save and Change")
        guiObj.SetFont("c" . THEME_TEXT . " norm", "Segoe UI")

        guiObj.Add("Text", "x" . startX . " y" . (startY + 435) . " w405 c" . THEME_MUTED . " Center", "💡 Press the Folder Menu Hotkey (default: F1) anywhere to open this menu.")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 465) . " w85 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.RefreshList()

        btnAddDir.OnEvent("Click", (*) => this.AddFolder())
        btnSep.OnEvent("Click", (*) => this.AddSeparator())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnUp.OnEvent("Click", (*) => this.MoveItem(-1))
        btnDown.OnEvent("Click", (*) => this.MoveItem(1))
        btnSave.OnEvent("Click", (*) => this.SaveAndClose(guiObj))
    }

    RefreshList(targetIdx := 0) {
        listData := []
        sepCnt := 0
        for obj in this.orderedItems {
            if (obj.Name == "-") {
                sepCnt++
                listData.Push("── Separator #" . sepCnt . " ──")
            } else {
                listData.Push(obj.Name)
            }
        }
        this.lbItems.Delete()
        if (listData.Length > 0)
            this.lbItems.Add(listData)
        if (targetIdx > 0 && targetIdx <= listData.Length)
            this.lbItems.Choose(targetIdx)
    }

    MoveItem(dir) {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        targetIdx := idx + dir
        if (targetIdx < 1 || targetIdx > this.orderedItems.Length)
            return

        temp := this.orderedItems[idx]
        this.orderedItems[idx] := this.orderedItems[targetIdx]
        this.orderedItems[targetIdx] := temp

        this.RefreshList(targetIdx)
    }

    DeleteItem() {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        item := this.orderedItems[idx]
        friendlyItem := (item.Name == "-") ? "Separator" : "[" . item.Name . "]`nPath: " . item.Path
        msgRes := MsgBox("❓ Are you sure you want to delete this favorite folder?`n`n" . friendlyItem, "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.orderedItems.RemoveAt(idx)
        this.RefreshList(idx > this.orderedItems.Length ? this.orderedItems.Length : idx)
    }

    AddSeparator() {
        this.orderedItems.Push({ Name: "-", Path: "-" })
        this.RefreshList(this.orderedItems.Length)
    }

    AddFolder() {
        ; Temporarily disable AlwaysOnTop of parentGui / main window
        if (this.parentGui) {
            this.parentGui.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.mainHwnd)
        } else if (this.rGui) {
            this.rGui.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.rGui.Hwnd)
        }

        ; 3 = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE
        selectedDir := DirSelect("*" . A_MyDocuments, 3, "Select a folder to add to Favorites")

        if (selectedDir == "") {
            ; Restore AlwaysOnTop before returning
            if (this.parentGui) {
                this.parentGui.Opt("+AlwaysOnTop")
                WinSetAlwaysOnTop(1, this.mainHwnd)
            } else if (this.rGui) {
                this.rGui.Opt("+AlwaysOnTop")
                WinSetAlwaysOnTop(1, this.rGui.Hwnd)
            }
            return
        }

        defaultName := file_getFileName(selectedDir)
        if (defaultName == "")
            defaultName := selectedDir

        ib := InputBox("Enter a nickname for this folder:`nPath: " . selectedDir,
            "Add Folder", "w350 h150", defaultName)

        ; Restore AlwaysOnTop
        if (this.parentGui) {
            this.parentGui.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.mainHwnd)
        } else if (this.rGui) {
            this.rGui.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.rGui.Hwnd)
        }

        if (ib.Result != "OK" || ib.Value == "")
            return

        this.orderedItems.Push({ Name: ib.Value, Path: selectedDir })
        this.RefreshList(this.orderedItems.Length)
    }

    SaveAndClose(guiObj) {
        FolderManager.WriteFolderItems(this.orderedItems)
        if (!this.parentGui)
            guiObj.Destroy()
        ToolTip("✅ Saved successfully")
        SetTimer(() => ToolTip(), -2000)
    }
}

; --- Numpad 핫키 로직 (ProcessNumpadHotkey 등 기존 로직 유지) ---

; --- Numpad 및 일반 숫자패드 단축어 입력 로직 ---

; =================================================================================
; --- 환경 설정 GUI (Preferences) ---
; =================================================================================
class PreferencesManager {
    __New(parentGui := "") {
        global g_filePath_Folder
        this.settingFile := g_filePath_Folder
        this.parentGui := parentGui
        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.pGui := Gui("+AlwaysOnTop", "🔧 Preferences")
            gui_ApplyTheme(this.pGui, "Preferences", "Configure basic app settings and hotkeys.")
            this.BuildUI(this.pGui)
            this.pGui.Show("AutoSize")
        }
    }

    BuildUI(guiObj) {
        ; 부모가 없을 때(단독 창)는 헤더가 있으므로 y시작점을 내림
        startX := this.parentGui ? 35 : 25
        startY := this.parentGui ? 115 : 80

        guiObj.SetFont("s10 c" . THEME_TEXT, "Segoe UI")

        mainHotkey := "F1"
        promptMod := "#"
        promptUseNumpad := 1
        try {
            mainHotkey := IniRead(this.settingFile, "Settings", "MainHotkey", "F1")
            promptMod := IniRead(this.settingFile, "Settings", "PromptModifier", "#")
            promptUseNumpad := IniRead(this.settingFile, "Settings", "PromptUseNumpad", "1")
        }

        ; 기존 설정 마이그레이션
        if (promptMod == "WinNumpad") {
            promptMod := "#"
            promptUseNumpad := 1
        } else if (promptMod == "WinAlt") {
            promptMod := "#!"
            promptUseNumpad := 0
        } else if (promptMod == "CtrlAlt") {
            promptMod := "^!"
            promptUseNumpad := 0
        }

        mainParsed := this.ParseKeyString(mainHotkey)
        promptParsed := this.ParseKeyString(promptMod)

        ; --- Main Hotkey GroupBox ---
        guiObj.Add("GroupBox", "x" . startX . " y" . startY . " w410 h85 c" . THEME_ACCENT, "📁 Favorites Menu Hotkey")
        guiObj.Add("Text", "x" . (startX + 15) . " y" . (startY + 20) . " w380", "Modifiers & Base Key:")

        this.chkMainCtrl := guiObj.Add("CheckBox", "x" . (startX + 15) . " y" . (startY + 48) . " w50", "Ctrl")
        this.chkMainShift := guiObj.Add("CheckBox", "x" . (startX + 70) . " y" . (startY + 48) . " w55", "Shift")
        this.chkMainWin := guiObj.Add("CheckBox", "x" . (startX + 130) . " y" . (startY + 48) . " w50", "Win")
        this.chkMainAlt := guiObj.Add("CheckBox", "x" . (startX + 185) . " y" . (startY + 48) . " w45", "Alt")

        this.chkMainCtrl.Value := mainParsed.Mods.Ctrl
        this.chkMainShift.Value := mainParsed.Mods.Shift
        this.chkMainWin.Value := mainParsed.Mods.Win
        this.chkMainAlt.Value := mainParsed.Mods.Alt

        guiObj.SetFont("cBlack")
        this.cbMainKey := guiObj.Add("ComboBox", "x" . (startX + 240) . " y" . (startY + 45) . " w155", [
            "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
            "Space", "Enter", "Tab", "Escape", "CapsLock", "ScrollLock", "NumLock", "PrintScreen", "Insert", "Delete",
            "LButton", "RButton", "MButton", "XButton1", "XButton2",
            "WheelUp", "WheelDown",
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
            "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
        ])
        guiObj.SetFont("c" . THEME_TEXT)
        this.cbMainKey.Text := mainParsed.Key

        ; --- Quick Prompts GroupBox ---
        guiObj.Add("GroupBox", "x" . startX . " y" . (startY + 100) . " w410 h85 c" . THEME_ACCENT, "⌨️ Quick Prompts Hotkey")
        guiObj.Add("Text", "x" . (startX + 15) . " y" . (startY + 120) . " w380", "Modifiers & Number Key Type:")

        this.chkPromptCtrl := guiObj.Add("CheckBox", "x" . (startX + 15) . " y" . (startY + 148) . " w50", "Ctrl")
        this.chkPromptShift := guiObj.Add("CheckBox", "x" . (startX + 70) . " y" . (startY + 148) . " w55", "Shift")
        this.chkPromptWin := guiObj.Add("CheckBox", "x" . (startX + 130) . " y" . (startY + 148) . " w50", "Win")
        this.chkPromptAlt := guiObj.Add("CheckBox", "x" . (startX + 185) . " y" . (startY + 148) . " w45", "Alt")

        this.chkPromptCtrl.Value := promptParsed.Mods.Ctrl
        this.chkPromptShift.Value := promptParsed.Mods.Shift
        this.chkPromptWin.Value := promptParsed.Mods.Win
        this.chkPromptAlt.Value := promptParsed.Mods.Alt

        numpadChoose := (promptUseNumpad == 1) ? 1 : 2
        guiObj.SetFont("cBlack")
        this.ddlPromptNumpad := guiObj.Add("DropDownList", "x" . (startX + 240) . " y" . (startY + 145) . " w155 Choose" . numpadChoose, ["Numpad 0~9", "Standard 0~9"])
        guiObj.SetFont("c" . THEME_TEXT)

        ; --- Save Preferences ---
        guiObj.SetFont("s10 cWhite bold", "Segoe UI")
        btnSave := guiObj.Add("Text", "x" . startX . " y" . (startY + 230) . " w410 h40 Center +0x200 +Border Background4A4F54", "💾 Save and Change")
        btnSave.OnEvent("Click", ObjBindMethod(this, "SavePreferences"))
        guiObj.SetFont("c" . THEME_TEXT . " norm", "Segoe UI")

        ; --- Advanced Options ---
        guiObj.Add("GroupBox", "x" . startX . " y" . (startY + 295) . " w410 h75", "Advanced Options")

        guiObj.SetFont("s9 cD03A3A bold", "Segoe UI")
        btnResetAll := guiObj.Add("Text", "x" . (startX + 15) . " y" . (startY + 320) . " w380 h30 Center +0x200 +Border Background2D2D30", "⚠️ FACTORY RESET ALL SETTINGS")
        btnResetAll.OnEvent("Click", (*) => ResetToDefaults("All"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
    }

    ParseKeyString(keyStr) {
        mods := { Ctrl: 0, Shift: 0, Win: 0, Alt: 0 }
        baseKey := keyStr
        loop {
            char := SubStr(baseKey, 1, 1)
            if (char == "^") {
                mods.Ctrl := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "+") {
                mods.Shift := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "#") {
                mods.Win := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "!") {
                mods.Alt := 1
                baseKey := SubStr(baseKey, 2)
            } else {
                break
            }
        }
        return { Mods: mods, Key: baseKey }
    }

    BuildKeyString(ctrl, shift, win, alt, baseKey) {
        prefix := ""
        if (ctrl)
            prefix .= "^"
        if (shift)
            prefix .= "+"
        if (win)
            prefix .= "#"
        if (alt)
            prefix .= "!"
        return prefix . baseKey
    }

    SavePreferences(*) {
        mainBase := Trim(this.cbMainKey.Text)
        if (mainBase == "")
            mainBase := "F1"

        try {
            validName := GetKeyName(mainBase)
        } catch {
            validName := ""
        }
        if (validName == "") {
            MsgBox("⚠️ '" . mainBase . "' is not a valid key name.", "Invalid Key", 262160)
            return
        }

        newHotkey := this.BuildKeyString(this.chkMainCtrl.Value, this.chkMainShift.Value, this.chkMainWin.Value, this.chkMainAlt.Value, mainBase)
        newModVal := this.BuildKeyString(this.chkPromptCtrl.Value, this.chkPromptShift.Value, this.chkPromptWin.Value, this.chkPromptAlt.Value, "")
        newUseNumpad := (this.ddlPromptNumpad.Value == 1) ? 1 : 0

        IniWrite(newHotkey, this.settingFile, "Settings", "MainHotkey")
        IniWrite(newModVal, this.settingFile, "Settings", "PromptModifier")
        IniWrite(newUseNumpad, this.settingFile, "Settings", "PromptUseNumpad")

        if (!this.parentGui)
            this.pGui.Destroy()
        MsgBox("✅ Settings saved successfully! The app will now reload.", "Success", 262208)
        Reload()
    }
}

SetStyledClipboard(text, color, sizePt) {
    htmlText := HtmlEncodeWithBr(text)  ; HTML 안전치환 + 개행 → <br>
    frag :=
        '<div style="font-family:Segoe UI, Arial, sans-serif; white-space:pre-wrap;">'
        . '<span style="color:' color '; font-size:' sizePt 'pt;">'
        . htmlText
        . '</span>'
        . '</div>'
    SetClipboardHtml(frag, text)
}

; --------------------------
; HTML 특수문자 치환 + 개행처리
; --------------------------
HtmlEncodeWithBr(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    s := StrReplace(s, ">", "&gt;")
    s := StrReplace(s, '"', "&quot;")
    s := StrReplace(s, "'", "&#39;")
    ; 개행을 <br>로
    s := StrReplace(s, "`r`n", "<br>")
    s := StrReplace(s, "`n", "<br>")
    s := StrReplace(s, "`r", "<br>")
    return s
}

; --------------------------
; CF_HTML 형식으로 클립보드 세팅
;  - HTML + UNICODETEXT 동시 등록
; --------------------------
SetClipboardHtml(htmlFragment, plainText, sourceURL := "") {
    docStart := '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>'
    docEnd := '</body></html>'
    mStart := '<!--StartFragment-->'
    mEnd := '<!--EndFragment-->'
    htmlDoc := docStart . mStart . htmlFragment . mEnd . docEnd

    ; 헤더(오프셋은 나중에 채움)
    hdr :=
    (
        "Version:0.9`r`n"
        "StartHTML:##########`r`n"
        "EndHTML:##########`r`n"
        "StartFragment:##########`r`n"
        "EndFragment:##########`r`n"
    )
    if (sourceURL != "")
        hdr .= "SourceURL:" . sourceURL . "`r`n"

    ; UTF-8 바이트 길이 계산 보조
    StrToUtf8Buffer(s) {
        buf := Buffer(StrPut(s, "UTF-8"))
        StrPut(s, buf, "UTF-8")
        return buf
    }

    hdrBuf := StrToUtf8Buffer(hdr), hdrBytes := hdrBuf.Size - 1
    docBuf := StrToUtf8Buffer(htmlDoc), docBytes := docBuf.Size - 1

    ; 조각 위치(문자 인덱스 → UTF-8 바이트 길이로 변환)
    idxStart := InStr(htmlDoc, mStart)
    idxEnd := InStr(htmlDoc, mEnd)
    preStart := SubStr(htmlDoc, 1, idxStart - 1)
    preEnd := SubStr(htmlDoc, 1, idxEnd - 1)
    preStartBytes := StrToUtf8Buffer(preStart).Size - 1
    preEndBytes := StrToUtf8Buffer(preEnd).Size - 1
    mStartBytes := StrToUtf8Buffer(mStart).Size - 1

    StartHTML := hdrBytes
    EndHTML := hdrBytes + docBytes
    StartFragment := StartHTML + preStartBytes + mStartBytes
    EndFragment := StartHTML + preEndBytes

    fill10(x) => Format("{:010}", x)
    hdrFinal := RegExReplace(hdr, "StartHTML:\K##########", fill10(StartHTML))
    hdrFinal := RegExReplace(hdrFinal, "EndHTML:\K##########", fill10(EndHTML))
    hdrFinal := RegExReplace(hdrFinal, "StartFragment:\K##########", fill10(StartFragment))
    hdrFinal := RegExReplace(hdrFinal, "EndFragment:\K##########", fill10(EndFragment))

    fullFinal := hdrFinal . htmlDoc

    ; 최종 UTF-8 바이너리
    bin := StrToUtf8Buffer(fullFinal), dataSize := bin.Size - 1

    ; PlainText (호환용) - UTF-16
    plain := plainText  ; 원본 텍스트를 그대로 유지 (태그 제거 정규식 삭제)
    ; UTF-16은 문자수 * 2 바이트 필요
    reqW := StrPut(plain, "UTF-16") * 2
    plainBuf := Buffer(reqW), StrPut(plain, plainBuf, "UTF-16")

    ; 클립보드 설정
    hHTML := DllCall("RegisterClipboardFormat", "str", "HTML Format", "uint")
    CF_UNICODETEXT := 13
    opened := false
    loop 5 {
        if DllCall("OpenClipboard", "ptr", 0, "int") {
            opened := true
            break
        }
        Sleep(30)
    }
    if !opened
        throw Error("OpenClipboard failed")

    try {
        DllCall("EmptyClipboard")

        GMEM_MOVEABLE := 0x0002, GMEM_ZEROINIT := 0x0040, GHND := GMEM_MOVEABLE | GMEM_ZEROINIT

        ; --- HTML 데이터 ---
        hMem := DllCall("GlobalAlloc", "uint", GHND, "uptr", dataSize + 1, "ptr")
        pMem := DllCall("GlobalLock", "ptr", hMem, "ptr")
        DllCall("RtlMoveMemory", "ptr", pMem, "ptr", bin.Ptr, "uptr", dataSize + 1)
        DllCall("GlobalUnlock", "ptr", hMem)
        if !DllCall("SetClipboardData", "uint", hHTML, "ptr", hMem, "ptr")
            throw Error("SetClipboardData(HTML) failed")

        ; --- UNICODETEXT ---
        hTxt := DllCall("GlobalAlloc", "uint", GHND, "uptr", plainBuf.Size, "ptr")
        pTxt := DllCall("GlobalLock", "ptr", hTxt, "ptr")
        DllCall("RtlMoveMemory", "ptr", pTxt, "ptr", plainBuf.Ptr, "uptr", plainBuf.Size)
        DllCall("GlobalUnlock", "ptr", hTxt)
        if !DllCall("SetClipboardData", "uint", CF_UNICODETEXT, "ptr", hTxt, "ptr")
            throw Error("SetClipboardData(TEXT) failed")
    } finally {
        DllCall("CloseClipboard")
    }
}

sub5_openWinFolder(Args*) {
    run "explorer.exe " . A_Startup
}

ShowAppInformation(parentHwnd := 0) {
    global g_filePath_Folder, g_filePath_Hotkey, g_filePath_Hotstring, g_targetFolder

    bmcBtnPath := A_ScriptDir . "\bmc_button.png"
    if !FileExist(bmcBtnPath) {
        try {
            Download("https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png", bmcBtnPath)
        }
    }

    if (parentHwnd) {
        WinSetEnabled(0, parentHwnd)
    }

    infoGui := Gui("+AlwaysOnTop +Owner" . parentHwnd . " -MinimizeBox -MaximizeBox", "ℹ️ App Information & Support")
    gui_ApplyTheme(infoGui, "App Information", "v" . g_appVersion . " | Diagnostic info & maintenance tools")

    CleanUpAndClose() {
        if (parentHwnd) {
            WinSetEnabled(1, parentHwnd)
            WinActivate("ahk_id " . parentHwnd)
        }
        infoGui.Destroy()
    }
    infoGui.OnEvent("Close", (*) => CleanUpAndClose())

    ; 통계 수집
    folderCount := FolderManager.ReadFolderItems().Length
    hsAutoCount := 0
    hsSpaceCount := 0
    if FileExist(g_filePath_Hotstring) {
        sections := IniRead(g_filePath_Hotstring)
        if (sections != "") {
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (secName == "" || secName == "Meta")
                    continue

                content := IniRead(g_filePath_Hotstring, secName, , "")
                if (content != "") {
                    loop parse, content, "`n", "`r" {
                        if (A_LoopField != "" && InStr(A_LoopField, "=")) {
                            if (SubStr(secName, 1, 11) == "Group_Auto_")
                                hsAutoCount++
                            else
                                hsSpaceCount++
                        }
                    }
                }
            }
        }
    }
    hsTotal := hsAutoCount + hsSpaceCount

    promptCount := 0
    if FileExist(g_filePath_Hotkey) {
        loop 10 {
            sec := IniRead(g_filePath_Hotkey, "Numpad" . (A_Index - 1), , "")
            loop parse, sec, "`n", "`r" {
                if (A_LoopField != "" && InStr(A_LoopField, "="))
                    promptCount++
            }
        }
    }

    remapCount := 0
    if FileExist(g_filePath_KeyRemap) {
        remapContent := IniRead(g_filePath_KeyRemap, "Remaps", , "")
        loop parse, remapContent, "`n", "`r" {
            if (A_LoopField != "" && InStr(A_LoopField, "="))
                remapCount++
        }
    }

    ; 1. Stats Panel (Left)
    infoGui.Add("GroupBox", "x20 y80 w210 h190 c" . THEME_ACCENT, "📊 System Statistics")
    infoGui.Add("Text", "x35 y105 w180", "📁 Favorites: " . folderCount . " registered")
    infoGui.Add("Text", "x35 y125 w180", "⌨️ Prompts: " . promptCount . " total")
    infoGui.Add("Text", "x35 y145 w180", "✏️ Hotstrings: " . hsTotal . " total")
    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x45 y165 w170", "(Imm: " . hsAutoCount . " / Space: " . hsSpaceCount . ")")
    infoGui.SetFont("s10 c" . THEME_TEXT)
    infoGui.Add("Text", "x35 y215 w180", "🔀 Key Remaps: " . remapCount . " total")

    ; 2. Maintenance Tools (Right)
    infoGui.Add("GroupBox", "x245 y80 w215 h190 c" . THEME_ACCENT, "🛠️ Maintenance Tools")

    btnAppFolder := infoGui.Add("Button", "x260 y105 w185 h30", "📂 Open App Folder")
    btnAppFolder.OnEvent("Click", (*) => Run("explorer.exe `"" . g_targetFolder . "`""))

    btnWinFolder := infoGui.Add("Button", "x260 y140 w185 h30", "📂 Open Startup Folder")
    btnWinFolder.OnEvent("Click", (*) => sub5_openWinFolder())

    btnBackup := infoGui.Add("Button", "x260 y175 w90 h30", "📥 Backup")
    btnBackup.OnEvent("Click", (*) => BackupConfigs(true))

    btnRestore := infoGui.Add("Button", "x355 y175 w90 h30", "🔄 Restore")
    btnRestore.OnEvent("Click", (*) => RestoreConfigs())

    isStartupEnabled := FileExist(A_Startup . "\SwiftDeck.lnk") || FileExist(A_Startup . "\FolderHotKey.lnk")
    chkStartup := infoGui.Add("CheckBox", "x260 y212 w185 h35 Checked" . (isStartupEnabled ? 1 : 0), "🚀 Run app when Windows starts")
    chkStartup.OnEvent("Click", (*) => ToggleStartup())

    ToggleStartup() {
        if (chkStartup.Value) {
            RegisterStartup()
        } else {
            UnregisterStartup()
        }
    }

    RegisterStartup() {
        if FileExist(A_Startup . "\FolderHotKey.lnk")
            try FileDelete(A_Startup . "\FolderHotKey.lnk")

        startupLnk := A_Startup . "\SwiftDeck.lnk"
        try {
            if FileExist(startupLnk) {
                FileDelete(startupLnk)
            }
            FileCreateShortcut(A_ScriptFullPath, startupLnk, A_ScriptDir)
            if FileExist(startupLnk) {
                MsgBox("🚀 Auto-Start has been successfully enabled!`nApp will now run automatically on Windows boot.", "Startup Registration", "64 cIconInfo")
            } else {
                throw Error("Shortcut creation verified but file is missing.")
            }
        } catch Error as err {
            MsgBox("❌ Failed to enable Auto-Start.`n`nError: " . err.Message, "Startup Error", "16 cIconStop")
        }
    }

    UnregisterStartup() {
        if FileExist(A_Startup . "\FolderHotKey.lnk")
            try FileDelete(A_Startup . "\FolderHotKey.lnk")

        startupLnk := A_Startup . "\SwiftDeck.lnk"
        try {
            if FileExist(startupLnk) {
                FileDelete(startupLnk)
                MsgBox("🗑️ Auto-Start has been successfully disabled.`nShortcut removed from Startup folder.", "Startup Unregistration", "64 cIconInfo")
            } else {
                MsgBox("ℹ️ Auto-Start is already disabled.`nNo shortcut found in the Startup folder.", "Startup Status", "48 cIconWarning")
            }
        } catch Error as err {
            MsgBox("❌ Failed to disable Auto-Start.`n`nError: " . err.Message, "Startup Error", "16 cIconStop")
        }
    }

    ; 3. File Paths Section (Bottom)
    infoGui.Add("GroupBox", "x20 y280 w440 h155 c" . THEME_ACCENT, "📂 Configuration File Paths")

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y305 w410", "Favorites Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y323 w345 h22 ReadOnly Background2D2D30 -Border", g_filePath_Folder)
    btnOpenFavFile := infoGui.Add("Button", "x390 y321 w55 h24", "Open")
    btnOpenFavFile.OnEvent("Click", (*) => Run("notepad.exe `"" . g_filePath_Folder . "`""))

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y348 w410", "Quick Prompts Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y366 w345 h22 ReadOnly Background2D2D30 -Border", g_filePath_Hotkey)
    btnOpenPrFile := infoGui.Add("Button", "x390 y364 w55 h24", "Open")
    btnOpenPrFile.OnEvent("Click", (*) => Run("notepad.exe `"" . g_filePath_Hotkey . "`""))

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y391 w410", "Hotstrings Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y409 w345 h22 ReadOnly Background2D2D30 -Border", g_filePath_Hotstring)
    btnOpenHsFile := infoGui.Add("Button", "x390 y407 w55 h24", "Open")
    btnOpenHsFile.OnEvent("Click", (*) => Run("notepad.exe `"" . g_filePath_Hotstring . "`""))
    infoGui.SetFont("s10 c" . THEME_TEXT)

    ; 4. Support Developer Section (Very Bottom)
    infoGui.Add("GroupBox", "x20 y445 w440 h115 c" . THEME_ACCENT, "☕ Support the Developer")
    infoGui.Add("Text", "x35 y467 w410", "If this tool helps your daily workflow, consider buying a coffee!")

    if FileExist(bmcBtnPath) {
        picCoffee := infoGui.Add("Picture", "x130 y490 w217 h60 BackgroundTrans", bmcBtnPath)
        picCoffee.OnEvent("Click", (*) => Run("https://www.buymeacoffee.com/KBPark_Bob"))
    } else {
        infoGui.SetFont("s11 cBlack bold", "Segoe UI")
        btnCoffee := infoGui.Add("Text", "x130 y495 w220 h45 Center +0x200 +Border BackgroundFF813F", "☕ Buy Me a Coffee")
        btnCoffee.OnEvent("Click", (*) => Run("https://www.buymeacoffee.com/KBPark_Bob"))
        infoGui.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
    }

    btnClose := infoGui.Add("Button", "x180 y575 w120 h35 Default", "Close")
    btnClose.OnEvent("Click", (*) => CleanUpAndClose())

    infoGui.Show("w480 h625")
}

OpenAppManual(lang := "EN", parentHwnd := 0) {
    mGui := Gui("+AlwaysOnTop +Resize -MaximizeBox", "App Manual")
    if (parentHwnd)
        mGui.Opt("+Owner" . parentHwnd)
    gui_EnableDarkMode(mGui)
    mGui.SetFont("s11", "Segoe UI")

    ; --- 언어 선택 드롭다운 ---
    mGui.Add("Text", "x10 y10 w80", "Language:")
    langChoices := ["🇺🇸 English", "🇰🇷 한국어", "🇵🇱 Polski", "🇫🇷 Français", "🇩🇪 Deutsch", "🇪🇸 Español", "🇮🇹 Italiano", "🇬🇷 Ελληνικά", "🇵🇹 Português", "🇨🇿 Čeština", "🇱🇻 Latviešu", "🇭🇺 Magyar", "🇷🇴 Română", "🇳🇴 Norsk"]

    ; 초기 선택 인덱스 결정
    langMapRev := Map("EN", 1, "KR", 2, "PL", 3, "FR", 4, "DE", 5, "ES", 6, "IT", 7, "GR", 8, "PT", 9, "CZ", 10, "LV", 11, "HU", 12, "RO", 13, "NO", 14)
    langIdx := langMapRev.Has(lang) ? langMapRev[lang] : 1

    mGui.SetFont("cBlack")
    ddlLang := mGui.Add("DropDownList", "x95 y7 w140 Choose" . langIdx, langChoices)
    mGui.SetFont("c" . THEME_TEXT)

    ; --- 컨텐츠 영역 (Tab + Edit) ---
    ; 언어별 텍스트 반환 헬퍼
    GetManualTexts(langCode) {
        if (langCode == "KR") {
            return {
                tab1: "🚀 퀵 스타트 (기본 사용법)",
                tab2: "⚙️ 앱 설정 (App Settings)",
                part1: "
                (
                    **1. 📂 1초 만에 폴더 열기 (기본 단축키: F1)**`n    - 아무 화면에서나 F1 키를 누르면 내가 저장한 폴더 목록이 짠! 나타남`n    - 폴더탐색기에서 Ctrl+F1을 누르면 지금 보는 폴더를 바로 내 폴더 목록에 추가할 수 있음`n**2. ⌨️ 마법의 자동 타이핑 (기본 단축키: Win + 숫자 0~9)**`n    - 자주 쓰는 긴 문장이나 이메일 양식, 메일주소, AI 프롬프트 등 입력`n    - Win 키와 숫자를 같이 누르면 미리 저장한 문장이 입력`n**3. ✨ Symbol 메뉴 & Symbol 자동 변환 (단축키: Ctrl + Win + 스페이스바)**`n    - 복잡한 기호 찾지 말고 메뉴를 열어서 선택!`n    - '자동 변환'도 있어요! 예를 들어 '_usd'라고 치면 '$'로 변경됨`n**4. 🔀 키보드 내 맘대로 바꾸기 (키 매핑)**`n    - 잘 안 쓰는 'Caps Lock' 키를 다른 키로 바꿔서 내 손에 딱 맞게 커스텀 할 수 있음
                )",
                part2: "
                (
                    - App Settings: 모든 기능을 쉽고 편하게 관리`n**1. 📁 [Folders] 탭, ⌨️ [Prompts] 탭**`n    - 추가(+), 수정(✏️), 지우기(x) 버튼으로 내 입맛대로 리스트를 정리`n**2. ✏️ [Hotstrings] 탭, 🔀 [Key Remap] 탭**`n    - [Hotstrings] 탭에서 나만의 단축어 추가`n    - [Key Remap] 탭에서는 안 쓰는 키를 새롭게 맵핑`n**3. ⚙️ [General] 탭**`n    - 앱 단축키가 마음에 안 든다면? 내가 원하는 버튼으로 자유롭게 변경
                )"
            }
        } else if (langCode == "PL") {
            return {
                tab1: "🚀 Szybki Start",
                tab2: "⚙️ Ustawienia Aplikacji",
                part1: "
                (
                    **1. 📂 Otwórz Foldery w 1 Sekundę (Domyślny skrót: F1)**`n    - Naciśnij F1 w dowolnym miejscu, a natychmiast pojawi się menu Twoich folderów!`n    - Naciśnij Ctrl+F1 w Eksploratorze, aby dodać bieżący folder do listy.`n**2. ⌨️ Magiczne Autouzupełnianie (Domyślny skrót: Win + Numpad 0~9)**`n    - Przestań ręcznie wpisywać częste e-maile czy adresy.`n    - Naciśnij Win + Numpad, aby automatycznie wpisać zapisany tekst.`n**3. ✨ Menu Symboli i Auto-Zamiana (Skrót: Ctrl + Win + Spacja)**`n    - Koniec z szukaniem symboli; otwórz menu i wybierz!`n    - Wypróbuj 'Auto-Zamianę'! Wpisanie '_usd' zmienia się w '$'.`n**4. 🔀 Zmień Klawisze (Mapowanie Klawiszy)**`n    - Zmień rzadko używane klawisze, aby idealnie pasowały do Twoich rąk!
                )",
                part2: "
                (
                    - App Settings: Łatwe zarządzanie wszystkimi funkcjami`n**1. 📁 Zakładka [Folders], ⌨️ Zakładka [Prompts]**`n    - Organizuj swoje listy za pomocą przycisków Dodaj (+), Edytuj (✏️) i Usuń (x).`n**2. ✏️ Zakładka [Hotstrings], 🔀 Zakładka [Key Remap]**`n    - Dodaj własne skróty tekstowe w [Hotstrings].`n    - Zmień rzadko używane klawisze na nowe funkcje w [Key Remap].`n**3. ⚙️ Zakładka [General]**`n    - Nie podobają Ci się domyślne skróty aplikacji? Zmień je!
                )"
            }
        } else if (langCode == "FR") {
            return {
                tab1: "🚀 Démarrage Rapide",
                tab2: "⚙️ Paramètres",
                part1: "
                (
                    **1. 📂 Ouvrir les Dossiers en 1 Seconde (Raccourci: F1)**`n    - Appuyez sur F1 pour faire apparaître vos dossiers favoris !`n    - Appuyez sur Ctrl+F1 dans l'Explorateur pour ajouter le dossier actuel.`n**2. ⌨️ Saisie Magique (Raccourci: Win + Pavé Num. 0~9)**`n    - Ne tapez plus vos e-mails ou adresses manuellement.`n    - Appuyez sur Win + Num pour taper automatiquement votre texte.`n**3. ✨ Menu Symboles & Remplacement Auto (Raccourci: Ctrl + Win + Espace)**`n    - Ne cherchez plus vos symboles ; ouvrez le menu et choisissez !`n    - Essayez le remplacement : tapez '_usd' pour insérer '$'.`n**4. 🔀 Remappage Clavier (Key Mapping)**`n    - Changez les touches peu utiles pour les adapter à vos besoins !
                )",
                part2: "
                (
                    - App Settings : Gérez facilement toutes vos fonctionnalités`n**1. 📁 Onglets [Folders] & ⌨️ [Prompts]**`n    - Organisez vos listes avec les boutons Ajouter (+), Éditer (✏️) et Supprimer (x).`n**2. ✏️ Onglets [Hotstrings] & 🔀 [Key Remap]**`n    - Ajoutez vos propres raccourcis texte dans [Hotstrings].`n    - Remappez les touches inutilisées dans [Key Remap].`n**3. ⚙️ Onglet [General]**`n    - Changez les raccourcis par défaut de l'application à votre guise !
                )"
            }
        } else if (langCode == "DE") {
            return {
                tab1: "🚀 Schnellstart",
                tab2: "⚙️ Einstellungen",
                part1: "
                (
                    **1. 📂 Ordner in 1 Sekunde öffnen (Standard: F1)**`n    - Drücken Sie überall F1, und Ihre Ordnerliste erscheint!`n    - Drücken Sie Strg+F1 im Explorer, um den aktuellen Ordner hinzuzufügen.`n**2. ⌨️ Magisches Auto-Tippen (Standard: Win + Numpad 0~9)**`n    - Tippen Sie häufige E-Mails nicht mehr von Hand.`n    - Drücken Sie Win + Numpad, um Text automatisch einzufügen.`n**3. ✨ Symbol-Menü & Auto-Ersetzen (Standard: Strg + Win + Leerzeichen)**`n    - Suchen Sie nicht nach Symbolen; öffnen Sie das Menü und wählen Sie!`n    - Probieren Sie 'Auto-Ersetzen'! Tippen Sie '_usd' für '$'.`n**4. 🔀 Tastatur-Neubelegung (Key Mapping)**`n    - Ändern Sie selten genutzte Tasten nach Ihren Wünschen!
                )",
                part2: "
                (
                    - App Settings: Verwalten Sie alle Funktionen ganz einfach`n**1. 📁 [Folders]-Tab & ⌨️ [Prompts]-Tab**`n    - Organisieren Sie Ihre Listen mit Hinzufügen (+), Bearbeiten (✏️) und Löschen (x).`n**2. ✏️ [Hotstrings]-Tab & 🔀 [Key Remap]-Tab**`n    - Fügen Sie in [Hotstrings] eigene Textkürzel hinzu.`n    - Weisen Sie ungenutzten Tasten in [Key Remap] neue Funktionen zu.`n**3. ⚙️ [General]-Tab**`n    - Ändern Sie die Standard-Hotkeys der App nach Belieben!
                )"
            }
        } else if (langCode == "ES") {
            return {
                tab1: "🚀 Inicio Rápido",
                tab2: "⚙️ Configuración",
                part1: "
                (
                    **1. 📂 Abrir Carpetas en 1 Segundo (Atajo: F1)**`n    - ¡Presione F1 en cualquier lugar y aparecerán sus carpetas guardadas!`n    - Presione Ctrl+F1 en el Explorador para agregar la carpeta actual.`n**2. ⌨️ Escritura Mágica (Atajo: Win + Numpad 0~9)**`n    - Deje de escribir correos frecuentes a mano.`n    - Presione Win + Número para escribir automáticamente el texto guardado.`n**3. ✨ Menú de Símbolos y Auto-Reemplazo (Atajo: Ctrl + Win + Espacio)**`n    - ¡No busque símbolos complejos; abra el menú y seleccione!`n    - Pruebe el 'Auto-Reemplazo': escriba '_usd' para convertirlo en '$'.`n**4. 🔀 Reasignación de Teclado (Key Mapping)**`n    - ¡Cambie teclas poco usadas para adaptarlas a sus manos!
                )",
                part2: "
                (
                    - App Settings: Administre todas las funciones fácilmente`n**1. 📁 Pestaña [Folders], ⌨️ Pestaña [Prompts]**`n    - Organice sus listas con los botones Agregar (+), Editar (✏️) y Eliminar (x).`n**2. ✏️ Pestaña [Hotstrings], 🔀 Pestaña [Key Remap]**`n    - Agregue sus propios atajos de texto en [Hotstrings].`n    - Reasigne teclas no utilizadas en [Key Remap].`n**3. ⚙️ Pestaña [General]**`n    - ¿No le gustan los atajos predeterminados? ¡Cámbielos a los que prefiera!
                )"
            }
        } else if (langCode == "IT") {
            return {
                tab1: "🚀 Avvio Rapido",
                tab2: "⚙️ Impostazioni",
                part1: "
                (
                    **1. 📂 Apri Cartelle in 1 Secondo (Scorciatoia: F1)**`n    - Premi F1 ovunque e appariranno le tue cartelle preferite!`n    - Premi Ctrl+F1 in Explorer per aggiungere subito la cartella corrente.`n**2. ⌨️ Digitazione Magica (Scorciatoia: Win + Tastierino 0~9)**`n    - Smetti di digitare a mano e-mail o messaggi frequenti.`n    - Premi Win + Numero per inserire automaticamente il testo salvato.`n**3. ✨ Menu Simboli & Auto-Sostituzione (Scorciatoia: Ctrl + Win + Spazio)**`n    - Non cercare simboli complessi; apri il menu e scegli!`n    - Prova 'Auto-Sostituzione'! Digitando '_usd' si trasforma in '$'.`n**4. 🔀 Rimappatura Tastiera (Key Mapping)**`n    - Cambia i tasti poco usati per adattarli alle tue esigenze!
                )",
                part2: "
                (
                    - App Settings: Gestisci tutte le funzionalità facilmente`n**1. 📁 Scheda [Folders], ⌨️ Scheda [Prompts]**`n    - Organizza le tue liste con i pulsanti Aggiungi (+), Modifica (✏️) ed Elimina (x).`n**2. ✏️ Scheda [Hotstrings], 🔀 Scheda [Key Remap]**`n    - Aggiungi scorciatoie di testo in [Hotstrings].`n    - Assegna nuove funzioni ai tasti inutilizzati in [Key Remap].`n**3. ⚙️ Scheda [General]**`n    - Cambia le scorciatoie dell'app come preferisci!
                )"
            }
        } else if (langCode == "GR") {
            return {
                tab1: "🚀 Γρήγορη Εκκίνηση",
                tab2: "⚙️ Ρυθμίσεις",
                part1: "
                (
                    **1. 📂 Άνοιγμα Φακέλων σε 1 Δευτερόλεπτο (Προεπιλογή: F1)**`n    - Πατήστε F1 οπουδήποτε για να εμφανιστούν οι φάκελοί σας!`n    - Πατήστε Ctrl+F1 στην Εξερεύνηση για να προσθέσετε τον τρέχοντα φάκελο.`n**2. ⌨️ Μαγική Πληκτρολόγηση (Προεπιλογή: Win + Numpad 0~9)**`n    - Σταματήστε να πληκτρολογείτε συχνά email με το χέρι.`n    - Πατήστε Win + Αριθμό για να εισαχθεί αυτόματα το κείμενο.`n**3. ✨ Μενού Συμβόλων & Αυτόματη Αντικατάσταση (Ctrl + Win + Space)**`n    - Μην ψάχνετε σύμβολα. Ανοίξτε το μενού και επιλέξτε!`n    - Πληκτρολογήστε '_usd' και θα μετατραπεί σε '$'.`n**4. 🔀 Αλλαγή Πλήκτρων (Key Mapping)**`n    - Αλλάξτε πλήκτρα όπως το 'Caps Lock' στα μέτρα σας!
                )",
                part2: "
                (
                    - App Settings: Εύκολη διαχείριση όλων των λειτουργιών`n**1. 📁 Καρτέλα [Folders], ⌨️ Καρτέλα [Prompts]**`n    - Οργανώστε τις λίστες σας με Προσθήκη (+), Επεξεργασία (✏️), Διαγραφή (x).`n**2. ✏️ Καρτέλα [Hotstrings], 🔀 Καρτέλα [Key Remap]**`n    - Προσθέστε δικές σας συντομεύσεις κειμένου στο [Hotstrings].`n    - Αλλάξτε λειτουργίες πλήκτρων στο [Key Remap].`n**3. ⚙️ Καρτέλα [General]**`n    - Αλλάξτε τις συντομεύσεις της εφαρμογής (π.χ. F1, Win) όπως θέλετε!
                )"
            }
        } else if (langCode == "PT") {
            return {
                tab1: "🚀 Início Rápido",
                tab2: "⚙️ Configurações",
                part1: "
                (
                    **1. 📂 Abrir Pastas em 1 Segundo (Atalho: F1)**`n    - Pressione F1 em qualquer lugar e suas pastas salvas aparecerão!`n    - Pressione Ctrl+F1 no Explorer para adicionar a pasta atual.`n**2. ⌨️ Digitação Mágica (Atalho: Win + NumPad 0~9)**`n    - Pare de digitar e-mails frequentes manualmente.`n    - Pressione Win + Número para colar automaticamente o texto salvo.`n**3. ✨ Menu de Símbolos e Auto-Substituir (Atalho: Ctrl + Win + Espaço)**`n    - Não procure símbolos complexos; abra o menu e escolha!`n    - Digitar '_usd' se transforma magicamente em '$'.`n**4. 🔀 Remapear Teclado (Key Mapping)**`n    - Mude teclas pouco usadas para se adequar às suas mãos!
                )",
                part2: "
                (
                    - App Settings: Gerencie todos os recursos facilmente`n**1. 📁 Aba [Folders], ⌨️ Aba [Prompts]**`n    - Organize suas listas com botões Adicionar (+), Editar (✏️) e Excluir (x).`n**2. ✏️ Aba [Hotstrings], 🔀 Aba [Key Remap]**`n    - Adicione seus atalhos de texto na aba [Hotstrings].`n    - Remapeie teclas não usadas na aba [Key Remap].`n**3. ⚙️ Aba [General]**`n    - Mude os atalhos padrão do app como preferir!
                )"
            }
        } else if (langCode == "CZ") {
            return {
                tab1: "🚀 Rychlý Start",
                tab2: "⚙️ Nastavení",
                part1: "
                (
                    **1. 📂 Otevřete složky za 1 sekundu (Výchozí: F1)**`n    - Stiskněte F1 kdekoli a okamžitě se objeví menu složek!`n    - Stisknutím Ctrl+F1 v Průzkumníkovi přidáte aktuální složku.`n**2. ⌨️ Magické psaní (Výchozí: Win + Numpad 0~9)**`n    - Přestaňte ručně psát časté e-maily.`n    - Stiskněte Win + číslo pro automatické vložení textu.`n**3. ✨ Menu symbolů a automatické nahrazení (Ctrl + Win + Mezerník)**`n    - Už žádné hledání symbolů; otevřete menu a vyberte!`n    - Zkuste '_usd' a magicky se to změní na '$'.`n**4. 🔀 Přebudování klávesnice (Key Mapping)**`n    - Změňte málo používané klávesy jako 'Caps Lock'!
                )",
                part2: "
                (
                    - App Settings: Snadná správa všech funkcí`n**1. 📁 Karta [Folders], ⌨️ Karta [Prompts]**`n    - Organizujte své seznamy pomocí Přidat (+), Upravit (✏️) a Smazat (x).`n**2. ✏️ Karta [Hotstrings], 🔀 Karta [Key Remap]**`n    - Přidejte vlastní textové zkratky v [Hotstrings].`n    - Změňte nepoužívané klávesy v [Key Remap].`n**3. ⚙️ Karta [General]**`n    - Změňte výchozí klávesové zkratky aplikace podle sebe!
                )"
            }
        } else if (langCode == "LV") {
            return {
                tab1: "🚀 Ātrais Starts",
                tab2: "⚙️ Iestatījumi",
                part1: "
                (
                    **1. 📂 Atvērt mapes 1 sekundē (Noklusējums: F1)**`n    - Nospiediet F1 jebkur, un parādīsies jūsu mapju izvēlne!`n    - Nospiediet Ctrl+F1 Pārlūkā, lai pievienotu pašreizējo mapi.`n**2. ⌨️ Maģiskā rakstīšana (Noklusējums: Win + Numpad 0~9)**`n    - Beidziet manuāli rakstīt bieži lietotus e-pastus.`n    - Nospiediet Win + ciparu, lai automātiski ievietotu tekstu.`n**3. ✨ Simbolu izvēlne un Auto-aizvietošana (Ctrl + Win + Atstarpe)**`n    - Nemeklējiet simbolus; atveriet izvēlni un izvēlieties!`n    - Ierakstot '_usd', tas maģiski pārvērtīsies par '$'.`n**4. 🔀 Tastatūras pārveidošana (Key Mapping)**`n    - Mainiet reti izmantotos taustiņus kā 'Caps Lock'!
                )",
                part2: "
                (
                    - App Settings: Viegli pārvaldiet visas funkcijas`n**1. 📁 [Folders] cilne, ⌨️ [Prompts] cilne**`n    - Organizējiet sarakstus ar Pievienot (+), Rediģēt (✏️) un Dzēst (x).`n**2. ✏️ [Hotstrings] cilne, 🔀 [Key Remap] cilne**`n    - Pievienojiet savus teksta saīsinājumus [Hotstrings].`n    - Mainiet neizmantotos taustiņus [Key Remap].`n**3. ⚙️ [General] cilne**`n    - Mainiet lietotnes noklusējuma saīsnes pēc saviem ieskatiem!
                )"
            }
        } else if (langCode == "HU") {
            return {
                tab1: "🚀 Gyors Kezdés",
                tab2: "⚙️ Beállítások",
                part1: "
                (
                    **1. 📂 Mappák megnyitása 1 másodperc alatt (Alapértelmezett: F1)**`n    - Nyomja meg az F1-et bárhol, és megjelenik a mappamenü!`n    - Nyomja meg a Ctrl+F1-et az Intézőben az aktuális mappa hozzáadásához.`n**2. ⌨️ Varázslatos gépelés (Alapértelmezett: Win + Numpad 0~9)**`n    - Ne gépelje be kézzel a gyakori e-maileket.`n    - Nyomja meg a Win + számot az előre mentett szöveg beírásához.`n**3. ✨ Szimbólum menü és Automatikus Csere (Ctrl + Win + Szóköz)**`n    - Ne keressen szimbólumokat; nyissa meg a menüt és válasszon!`n    - Próbálja ki az 'Automatikus cserét'! Írja be az '_usd'-t, és '$' lesz belőle.`n**4. 🔀 Billentyűzet Átrendezése (Key Mapping)**`n    - Változtassa meg a ritkán használt billentyűket, mint a 'Caps Lock'!
                )",
                part2: "
                (
                    - App Settings: Kezeljen minden funkciót egyszerűen`n**1. 📁 [Folders] fül, ⌨️ [Prompts] fül**`n    - Rendszerezze listáit a Hozzáadás (+), Szerkesztés (✏️) és Törlés (x) gombokkal.`n**2. ✏️ [Hotstrings] fül, 🔀 [Key Remap] fül**`n    - Adja hozzá saját szöveges rövidítéseit a [Hotstrings] fülön.`n    - Rendeljen új funkciót a nem használt billentyűkhöz a [Key Remap] fülön.`n**3. ⚙️ [General] fül**`n    - Változtassa meg az alkalmazás gyorsbillentyűit, ahogy csak akarja!
                )"
            }
        } else if (langCode == "RO") {
            return {
                tab1: "🚀 Start Rapid",
                tab2: "⚙️ Setări",
                part1: "
                (
                    **1. 📂 Deschide Foldere în 1 Secundă (Comandă: F1)**`n    - Apasă F1 oriunde și va apărea meniul tău de foldere!`n    - Apasă Ctrl+F1 în Explorer pentru a adăuga folderul curent.`n**2. ⌨️ Tastare Magică (Comandă: Win + Numpad 0~9)**`n    - Nu mai tasta manual e-mailurile frecvente.`n    - Apasă Win + Număr pentru a insera automat textul salvat.`n**3. ✨ Meniu Simboluri & Auto-Înlocuire (Ctrl + Win + Spațiu)**`n    - Nu mai căuta simboluri; deschide meniul și selectează!`n    - Tastând '_usd' se va transforma magic în '$'.`n**4. 🔀 Remapare Tastatură (Key Mapping)**`n    - Schimbă tastele rar folosite precum 'Caps Lock'!
                )",
                part2: "
                (
                    - App Settings: Gestionează toate funcțiile cu ușurință`n**1. 📁 Tab [Folders], ⌨️ Tab [Prompts]**`n    - Organizează listele cu butoanele Adaugă (+), Editează (✏️), Șterge (x).`n**2. ✏️ Tab [Hotstrings], 🔀 Tab [Key Remap]**`n    - Adaugă scurtături de text în tab-ul [Hotstrings].`n    - Remapează tastele nefolosite în tab-ul [Key Remap].`n**3. ⚙️ Tab [General]**`n    - Schimbă scurtăturile aplicației după preferințe!
                )"
            }
        } else if (langCode == "NO") {
            return {
                tab1: "🚀 Hurtigstart",
                tab2: "⚙️ Innstillinger",
                part1: "
                (
                    **1. 📂 Åpne mapper på 1 sekund (Standard: F1)**`n    - Trykk F1 hvor som helst for å åpne mappemenyen!`n    - Trykk Ctrl+F1 i Utforsker for å legge til gjeldende mappe.`n**2. ⌨️ Magisk autotyping (Standard: Win + Numpad 0~9)**`n    - Slutt å skrive vanlige e-poster manuelt.`n    - Trykk Win + Nummer for å sette inn lagret tekst automatisk.`n**3. ✨ Symbolmeny & Auto-erstatt (Ctrl + Win + Mellomrom)**`n    - Ikke let etter symboler; åpne menyen og velg!`n    - Prøv 'Auto-erstatt'! Skriver du '_usd' blir det til '$'.`n**4. 🔀 Endre tastatur (Key Mapping)**`n    - Bytt ut lite brukte taster som 'Caps Lock'!
                )",
                part2: "
                (
                    - App Settings: Administrer alle funksjoner enkelt`n**1. 📁 [Folders]-fane, ⌨️ [Prompts]-fane**`n    - Organiser listene dine med Legg til (+), Rediger (✏️) og Slett (x).`n**2. ✏️ [Hotstrings]-fane, 🔀 [Key Remap]-fane**`n    - Legg til dine egne tekstsnarveier i [Hotstrings].`n    - Gi ubrukte taster nye funksjoner i [Key Remap].`n**3. ⚙️ [General]-fane**`n    - Endre appens snarveier som du vil!
                )"
            }
        } else { ; EN (default)
            return {
                tab1: "🚀 Quick Start",
                tab2: "⚙️ App Settings",
                part1: "
                (
                    **1. 📂 Open Folders in 1 Second (Default Hotkey: F1)**`n    - Press F1 anywhere and your saved folders menu will instantly appear!`n    - Press Ctrl+F1 in Explorer to add the current folder directly to your list.`n**2. ⌨️ Magical Auto-Typing (Default Hotkey: Win + Numpad 0~9)**`n    - Stop typing your frequent emails, AI prompts, or addresses manually.`n    - Press Win + Numpad to automatically type your predefined text.`n**3. ✨ Symbol Menu & Auto-Replace (Hotkey: Ctrl + Win + Space)**`n    - No more searching for complex symbols; just open the menu and select!`n    - Try 'Auto-Replace'! For example, typing '_usd' magically transforms into '$'.`n**4. 🔀 Remap Your Keyboard (Key Mapping)**`n    - Change rarely used keys like 'Caps Lock' to suit your hands perfectly!
                )",
                part2: "
                (
                    - App Settings: Manage all your features easily`n**1. 📁 [Folders] Tab, ⌨️ [Prompts] Tab**`n    - Organize your lists exactly as you want with Add (+), Edit (✏️), and Delete (x) buttons.`n**2. ✏️ [Hotstrings] Tab, 🔀 [Key Remap] Tab**`n    - Add your custom text expansions in the [Hotstrings] tab.`n    - Remap unused keys to new functions in the [Key Remap] tab.`n**3. ⚙️ [General] Tab**`n    - Don't like the app's default hotkeys? Change them to whatever you prefer!
                )"
            }
        }
    }

    ; HTML 변환 및 파란색 강조 헬퍼
    FormatTextToHtml(txt) {
        ; HTML 특수문자 안전 치환
        txt := StrReplace(txt, "&", "&amp;")
        txt := StrReplace(txt, "<", "&lt;")
        txt := StrReplace(txt, ">", "&gt;")

        ; 마크다운 굵게(**text**) 처리
        txt := RegExReplace(txt, "\*\*([^\*]+)\*\*", "<b>$1</b>")

        ; 개행 처리
        txt := StrReplace(txt, "`r`n", "<br>")
        txt := StrReplace(txt, "`n", "<br>")
        txt := StrReplace(txt, "`r", "<br>")

        ; 들여쓰기 공백 처리
        txt := StrReplace(txt, "    ", "&nbsp;&nbsp;&nbsp;&nbsp;")

        ; 괄호 안의 글자를 파란색(#0056b3) 및 굵게 스타일링
        txt := RegExReplace(txt, "\(([^)]+)\)", "<span style='color:#0056b3; font-weight:bold;'>($1)</span>")

        htmlStr := "<!DOCTYPE html>`n<html>`n<head>`n<meta http-equiv='X-UA-Compatible' content='IE=edge'>`n"
        htmlStr .= "<style>`n"
        htmlStr .= "html, body { margin: 0; padding: 0; border: 0; background-color: #ffffff; overflow-y: auto; overflow-x: hidden; }`n"
        htmlStr .= "body { font-family: 'Segoe UI', 'Malgun Gothic', sans-serif; font-size: 11pt; color: #333333; line-height: 1.55; }`n"
        htmlStr .= "</style>`n</head>`n<body>`n" . txt . "`n</body>`n</html>"

        return htmlStr
    }

    ; 초기 텍스트 로드
    texts := GetManualTexts(lang)

    ; ActiveX HTMLFile 컨트롤 생성하여 깔끔한 리치 텍스트 표시
    edtManual := mGui.Add("ActiveX", "x10 y40 w670 h640", "htmlfile")
    doc := edtManual.Value
    doc.write(FormatTextToHtml(texts.tab1 . "`n" . texts.part1 . "`n`n" . texts.tab2 . "`n" . texts.part2))
    doc.close()

    ; --- 언어 변경 시 동적 업데이트 ---
    ddlLang.OnEvent("Change", OnLangChange)
    OnLangChange(*) {
        langMap := Map(1, "EN", 2, "KR", 3, "PL", 4, "FR", 5, "DE", 6, "ES", 7, "IT", 8, "GR", 9, "PT", 10, "CZ", 11, "LV", 12, "HU", 13, "RO", 14, "NO")
        newLang := langMap[ddlLang.Value]
        newTexts := GetManualTexts(newLang)

        doc := edtManual.Value
        doc.open()
        doc.write(FormatTextToHtml(newTexts.tab1 . "`n" . newTexts.part1 . "`n`n" . newTexts.tab2 . "`n" . newTexts.part2))
        doc.close()
    }

    btnClose := mGui.Add("Button", "w100 x295 y+15 Default", "Close")
    btnClose.OnEvent("Click", (*) => mGui.Destroy())
    mGui.Show()
}

class PromptManager {
    static iCnt := 0
    static dataGroup := []

    ; ==========================================
    ; --- 1. Execution Engine (Static) ---
    ; ==========================================
    static ProcessQuickPrompt(groupNum) {
        PromptManager.iCnt := 0
        PromptManager.dataGroup := []

        modifierKey := "LWin"
        tapKey := ""

        if InStr(A_ThisHotkey, "^!") {
            modifierKey := GetKeyState("RCtrl", "P") ? "RCtrl" : "LCtrl"
            tapKey := String(groupNum)
        } else if InStr(A_ThisHotkey, "#!") {
            modifierKey := GetKeyState("RWin", "P") ? "RWin" : "LWin"
            tapKey := String(groupNum)
        } else {
            modifierKey := GetKeyState("RWin", "P") ? "RWin" : "LWin"
            tapKey := "Numpad" . groupNum
        }

        global g_filePath_Hotkey
        if !FileExist(g_filePath_Hotkey)
            return

        sectionContent := IniRead(g_filePath_Hotkey, "Numpad" . groupNum, , "")
        if (sectionContent != "") {
            loop parse, sectionContent, "`n", "`r" {
                if !A_LoopField
                    continue
                idx := InStr(A_LoopField, "=")
                if (idx > 0) {
                    lbl := Trim(SubStr(A_LoopField, 1, idx - 1))
                    itemMsg := Trim(SubStr(A_LoopField, idx + 1))
                    itemMsg := StrReplace(itemMsg, "\n", "`n")

                    PromptManager.dataGroup.Push({
                        fontSize: 11,
                        fontColor: "black",
                        label: lbl,
                        msg: itemMsg
                    })
                }
            }
        }

        if (PromptManager.dataGroup.Length = 0) {
            ToolTip("⚠️ No data for Group " . groupNum . "`n⚠️ Group " . groupNum . " 데이터가 없습니다.")
            SetTimer(() => ToolTip(), -1000)
            return
        }

        PromptManager.dataGroup.Push({
            fontSize: 11,
            fontColor: "black",
            label: "0. Nothing",
            msg: ""
        })

        while GetKeyState(modifierKey, "P") {
            if GetKeyState(tapKey, "P") {
                PromptManager.iCnt := (PromptManager.iCnt < PromptManager.dataGroup.Length) ? PromptManager.iCnt + 1 :
                    1
                ToolTip(PromptManager.dataGroup[PromptManager.iCnt].label)
                Sleep(200)
            } else {
                Sleep(10)
            }
        }

        KeyWait(modifierKey)
        Sleep(100)

        if (PromptManager.iCnt > 0) {
            SetTimer(() => PromptManager.ExecutePrompt(), -1)
        }
        return
    }

    static ExecutePrompt() {
        if (PromptManager.iCnt > 0 && PromptManager.iCnt <= PromptManager.dataGroup.Length && PromptManager.dataGroup[
            PromptManager.iCnt].msg != "") {
            msg := PromptManager.dataGroup[PromptManager.iCnt].msg
            if (HasSpecialKeys(msg)) {
                ExecutePromptSequence(msg)
            } else {
                SetStyledClipboard(msg, PromptManager.dataGroup[PromptManager.iCnt].fontColor, PromptManager.dataGroup[
                    PromptManager.iCnt].fontSize)
                Send("^v")
            }
        }
        ToolTip()
        return
    }

    ; ==========================================
    ; --- 2. GUI Manager (Instance) ---
    ; ==========================================
    __New(parentGui := "") {
        global g_filePath_Hotkey
        this.settingFile := g_filePath_Hotkey
        this.parentGui := parentGui
        this.localData := Map()
        loop 10 {
            num := A_Index - 1
            this.localData[num] := []
            sectionContent := IniRead(this.settingFile, "Numpad" . num, , "")
            if (sectionContent != "") {
                loop parse, sectionContent, "`n", "`r" {
                    if !A_LoopField
                        continue
                    idx := InStr(A_LoopField, "=")
                    if (idx > 0) {
                        k := Trim(SubStr(A_LoopField, 1, idx - 1))
                        v := Trim(SubStr(A_LoopField, idx + 1))
                        v := StrReplace(v, "\n", "`n")
                        this.localData[num].Push({ Title: k, Msg: v })
                    }
                }
            }
        }
        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.hGui := Gui("+AlwaysOnTop", "Quick Prompts Manager")
            gui_EnableDarkMode(this.hGui)
            this.BuildUI(this.hGui)
            this.hGui.Show("w460 h515")
        }
    }

    BuildUI(guiObj) {
        startX := this.parentGui ? 30 : 30
        startY := this.parentGui ? 120 : 20
        this.mainHwnd := guiObj.Hwnd
        if (!this.parentGui)
            guiObj.OnEvent("Close", (*) => guiObj.Destroy())

        guiObj.Add("Text", "x" . startX . " y" . startY . " w215", "① Select Slot (Win + Numpad):")

        guiObj.SetFont("cBlack")
        this.ddlNumpad := guiObj.Add("DropDownList", "x" . (startX + 220) . " y" . (startY - 5) . " w180 Choose1", [
            "Numpad 1", "Numpad 2", "Numpad 3",
            "Numpad 4", "Numpad 5", "Numpad 6", "Numpad 7", "Numpad 8", "Numpad 9", "Numpad 0"])
        guiObj.SetFont("c" . THEME_TEXT)

        guiObj.Add("Text", "x" . startX . " y" . (startY + 35) . " w200", "② Prompts in this Slot:")

        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 55) . " w320 h210")
        guiObj.SetFont("c" . THEME_TEXT)

        guiObj.Add("Text", "x" . startX . " y" . (startY + 275) . " w200", "③ Content Preview:")

        guiObj.SetFont("c444444")
        this.edtPreview := guiObj.Add("Edit", "x" . startX . " y" . (startY + 295) . " w400 h105 ReadOnly Multi BackgroundD4D4D4", "")
        guiObj.SetFont("c" . THEME_TEXT)

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 330) . " y" . (startY + 25) . " w70 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Prompts"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        btnNew := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 55) . " w70 h35", "New (+)")
        btnEdit := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 95) . " w70 h35", "Edit (✏️)")
        btnDel := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 135) . " w70 h35", "Delete (x)")
        btnUp := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 175) . " w70 h35", "Up (↑)")
        btnDown := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 215) . " w70 h35", "Down (↓)")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 330) . " y" . (startY + 410) . " w70 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.ddlNumpad.OnEvent("Change", (*) => this.RefreshList(0))
        this.lbItems.OnEvent("Change", (*) => this.UpdatePreview())
        this.lbItems.OnEvent("DoubleClick", (*) => this.EditSelectedItem())
        btnNew.OnEvent("Click", (*) => this.ShowEditPopup(false, 0))
        btnEdit.OnEvent("Click", (*) => this.EditSelectedItem())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnUp.OnEvent("Click", (*) => this.MoveItem(-1))
        btnDown.OnEvent("Click", (*) => this.MoveItem(1))

        this.RefreshList()
    }

    ShowEditPopup(isEdit := false, editIdx := 0) {
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", isEdit ? "Edit Prompt" : "Add Prompt")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))

        tVal := ""
        mVal := ""
        if (isEdit && editIdx > 0 && editIdx <= this.localData[currNum].Length) {
            item := this.localData[currNum][editIdx]
            tVal := item.Title
            mVal := item.Msg
        }

        popup.Add("Text", "x15 y15 w400 c666666", "① Prompt Title:")
        edtTitle := popup.Add("Edit", "x15 y35 w400 h25", tVal)

        popup.Add("Text", "x15 y70 w150 c666666", "② Prompt Content:")

        popup.SetFont("s9 cWhite Bold", "Segoe UI")
        btnInsertKey := popup.Add("Text", "x265 y65 w150 h24 Center +0x200 +Border Background0078D7", "Insert Key ▼")
        popup.SetFont("s10 cBlack norm", "Segoe UI")

        edtMsg := popup.Add("Edit", "x15 y95 w400 h120 Multi", mVal)

        InsertKeyTag := (ItemName, ItemPos, MyMenu) => InsertKeyToEdit(ItemName)
        InsertKeyToEdit(ItemName) {
            if (RegExMatch(ItemName, "\{[^}]+\}", &tagMatch)) {
                tag := tagMatch[0]
                edtMsg.Value := edtMsg.Value . tag
                ControlFocus(edtMsg.Hwnd)
                Send("^{End}")
            }
        }

        keyMenu := Menu()
        keyMenu.Add("{Enter}", InsertKeyTag)
        keyMenu.Add("{Tab}", InsertKeyTag)
        keyMenu.Add("{Esc}", InsertKeyTag)
        keyMenu.Add("{Backspace}", InsertKeyTag)
        keyMenu.Add("{Space}", InsertKeyTag)
        keyMenu.Add("{Delete}", InsertKeyTag)
        keyMenu.Add()
        mNav := Menu()
        mNav.Add("{Up}", InsertKeyTag)
        mNav.Add("{Down}", InsertKeyTag)
        mNav.Add("{Left}", InsertKeyTag)
        mNav.Add("{Right}", InsertKeyTag)
        mNav.Add("{Home}", InsertKeyTag)
        mNav.Add("{End}", InsertKeyTag)
        keyMenu.Add("Navigation", mNav)
        mShort := Menu()
        mShort.Add("{Ctrl+a} Select All", InsertKeyTag)
        mShort.Add("{Ctrl+c} Copy", InsertKeyTag)
        mShort.Add("{Ctrl+v} Paste", InsertKeyTag)
        mShort.Add("{Ctrl+x} Cut", InsertKeyTag)
        mShort.Add("{Ctrl+z} Undo", InsertKeyTag)
        mShort.Add("{Ctrl+l} Address Bar", InsertKeyTag)
        mShort.Add("{Ctrl+s} Save", InsertKeyTag)
        mShort.Add("{Ctrl+End} Go to End", InsertKeyTag)
        keyMenu.Add("Shortcuts", mShort)
        keyMenu.Add()
        mDelay := Menu()
        mDelay.Add("{Wait:300} 0.3s", InsertKeyTag)
        mDelay.Add("{Wait:500} 0.5s", InsertKeyTag)
        mDelay.Add("{Wait:1000} 1s", InsertKeyTag)
        mDelay.Add("{Wait:2000} 2s", InsertKeyTag)
        mDelay.Add("{Wait:3000} 3s", InsertKeyTag)
        keyMenu.Add("Delay", mDelay)

        btnInsertKey.OnEvent("Click", (*) => keyMenu.Show())

        popup.SetFont("s10 cWhite bold", "Segoe UI")
        btnConfirm := popup.Add("Text", "x225 y230 w190 h35 Center +0x200 +Border Background0078D7", isEdit ? "💾 Modify Prompt" : "➕ Add Prompt")
        popup.SetFont("s10 cBlack norm", "Segoe UI")
        btnConfirm.OnEvent("Click", (*) => OnConfirm())

        btnCancel := popup.Add("Button", "x15 y230 w190 h35", "Cancel")
        btnCancel.OnEvent("Click", (*) => CleanUpAndClose())

        OnConfirm() {
            t := Trim(edtTitle.Value)
            m := Trim(edtMsg.Value)
            if (t == "") {
                MsgBox("⚠️ Please enter a title.", "Warning", 262192)
                return
            }

            if (isEdit) {
                this.localData[currNum][editIdx].Title := t
                this.localData[currNum][editIdx].Msg := m
            } else {
                this.localData[currNum].Push({ Title: t, Msg: m })
            }

            this.RefreshList(isEdit ? editIdx : this.localData[currNum].Length)
            this.SaveSettings()
            CleanUpAndClose()
            ToolTip(isEdit ? "✅ Modified & Saved" : "✅ Added & Saved")
            SetTimer(() => ToolTip(), -2000)
        }

        popup.Show("w430 h280")
    }

    EditSelectedItem() {
        idx := this.lbItems.Value
        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))
        if (idx > 0 && idx <= this.localData[currNum].Length) {
            this.ShowEditPopup(true, idx)
        }
    }

    RefreshList(targetIdx := 0) {
        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))

        this.lbItems.Delete()
        listData := []
        for idx, item in this.localData[currNum] {
            listData.Push(item.Title)
        }
        if (listData.Length > 0)
            this.lbItems.Add(listData)

        if (targetIdx > 0 && targetIdx <= listData.Length) {
            this.lbItems.Choose(targetIdx)
        }
        this.UpdatePreview()
    }

    UpdatePreview() {
        idx := this.lbItems.Value
        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))
        if (idx > 0 && idx <= this.localData[currNum].Length) {
            this.edtPreview.Value := this.localData[currNum][idx].Msg
        } else {
            this.edtPreview.Value := ""
        }
    }

    MoveItem(dir) {
        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))
        idx := this.lbItems.Value
        if (idx == 0)
            return

        targetIdx := idx + dir
        if (targetIdx < 1 || targetIdx > this.localData[currNum].Length)
            return

        temp := this.localData[currNum][idx]
        this.localData[currNum][idx] := this.localData[currNum][targetIdx]
        this.localData[currNum][targetIdx] := temp

        this.RefreshList(targetIdx)
        this.SaveSettings()
    }

    DeleteItem() {
        currNum := Integer(SubStr(this.ddlNumpad.Text, 8))
        selIdx := this.lbItems.Value

        if (selIdx == 0)
            return

        itemTitle := this.localData[currNum][selIdx].Title
        msgRes := MsgBox("❓ Are you sure you want to delete this prompt?`n`n[" . itemTitle . "]", "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.localData[currNum].RemoveAt(selIdx)

        this.RefreshList(selIdx > this.localData[currNum].Length ? this.localData[currNum].Length : selIdx)
        this.SaveSettings()
        ToolTip("✅ Deleted & Saved")
        SetTimer(() => ToolTip(), -2000)
    }

    SaveSettings() {
        loop 10 {
            num := A_Index - 1
            content := ""
            if (this.localData[num].Length > 0) {
                for idx, item in this.localData[num] {
                    safemsg := StrReplace(item.Msg, "`n", "\n")
                    content .= item.Title . "=" . safemsg . "`n"
                }
                IniWrite(content, this.settingFile, "Numpad" . num)
            } else {
                try IniDelete(this.settingFile, "Numpad" . num)
            }
        }
    }
}

class HotstringManager {
    __New(parentGui := "") {
        global g_filePath_Hotstring
        this.settingFile := g_filePath_Hotstring
        this.parentGui := parentGui
        this.localData := Map()
        this.groupOrder := []

        if FileExist(this.settingFile) {
            sections := ""
            try sections := IniRead(this.settingFile)
            if (sections != "") {
                loop parse, sections, "`n", "`r" {
                    secName := Trim(A_LoopField)
                    if (secName == "" || secName == "Meta")
                        continue
                    if (SubStr(secName, 1, 12) != "Group_Space_" && SubStr(secName, 1, 11) != "Group_Menu_")
                        continue

                    this.localData[secName] := []
                    this.groupOrder.Push(secName)
                    content := ""
                    try content := IniRead(this.settingFile, secName, , "")
                    if (content != "") {
                        loop parse, content, "`n", "`r" {
                            if !A_LoopField
                                continue
                            idx := InStr(A_LoopField, "=")
                            if (idx > 0) {
                                k := Trim(SubStr(A_LoopField, 1, idx - 1))
                                v := Trim(SubStr(A_LoopField, idx + 1))
                                if (k == ">" && v == "=≥")
                                    k := ">=", v := "≥"
                                else if (k == "<" && v == "=≤")
                                    k := "<=", v := "≤"
                                else if (k == "!" && v == "=≠")
                                    k := "!=", v := "≠"
                                v := StrReplace(v, "\n", "`n")
                                this.localData[secName].Push({ Key: k, Val: v })
                            }
                        }
                    }
                }
            }
        }

        if (this.localData.Count == 0)
            this.localData["Group_Space_Default"] := []

        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.hsGui := Gui("+AlwaysOnTop", "HotStrings Manager")
            gui_EnableDarkMode(this.hsGui)
            this.BuildUI(this.hsGui)
            this.hsGui.Show("w430 h425")
        }
    }

    BuildUI(guiObj) {
        startX := this.parentGui ? 30 : 30
        startY := this.parentGui ? 120 : 20
        this.mainHwnd := guiObj.Hwnd
        if (!this.parentGui)
            guiObj.OnEvent("Close", (*) => guiObj.Destroy())

        ; Group Name row — clean layout with single Manage button
        guiObj.Add("Text", "x" . startX . " y" . startY . " w100", "① Select Group:")

        guiObj.SetFont("cBlack")
        this.cbGroup := guiObj.Add("ComboBox", "x" . (startX + 105) . " y" . (startY - 5) . " w210", [])
        guiObj.SetFont("c" . THEME_TEXT)

        btnManageGrp := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY - 5) . " w85 h25", "⚙️ Manage")

        this.txtDesc := guiObj.Add("Text", "x" . startX . " y" . (startY + 30) . " w400 c" . THEME_MUTED,
            "(Type abbreviation + Space/Enter to trigger expansion)")

        guiObj.Add("Text", "x" . startX . " y" . (startY + 55) . " w200", "② Abbreviation List:")

        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 75) . " w310 h345")
        guiObj.SetFont("c" . THEME_TEXT)

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 45) . " w85 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Hotstrings"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        btnAdd := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 75) . " w85 h35", "New (+)")
        btnEdit := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 115) . " w85 h35", "Edit (✏️)")
        btnDel := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 155) . " w85 h35", "Delete (x)")
        btnUp := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 300) . " w85 h35", "Up (↑)")
        btnDown := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 340) . " w85 h35", "Down (↓)")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 385) . " w85 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.cbGroup.OnEvent("Change", (*) => this.OnGroupChange())
        this.lbItems.OnEvent("DoubleClick", (*) => this.EditSelectedItem())

        btnManageGrp.OnEvent("Click", (*) => this.ShowGroupManagerPopup())
        btnAdd.OnEvent("Click", (*) => this.ShowEditPopup(false, 0))
        btnEdit.OnEvent("Click", (*) => this.EditSelectedItem())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnUp.OnEvent("Click", (*) => this.MoveItem(-1))
        btnDown.OnEvent("Click", (*) => this.MoveItem(1))

        this.UpdateGroupsDdl()
        this.RefreshList()
    }

    ; =========================================================================
    ; Group Manager Popup — Add, Rename, Delete, Reorder groups in one place
    ; =========================================================================
    ShowGroupManagerPopup() {
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", "Manage Groups")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        popup.Add("Text", "x15 y10 w300 c666666", "Add, rename, reorder, or delete hotstring groups.")
        popup.SetFont("s8 c999999", "Segoe UI")
        popup.Add("Text", "x15 y30 w300", "(Prefix with * when adding for menu-only group)")
        popup.SetFont("s10 cBlack", "Segoe UI")

        ; Group ListBox
        lbGroups := popup.Add("ListBox", "x15 y55 w260 h230")

        ; Action buttons (right side)
        btnGAdd := popup.Add("Button", "x290 y55 w120 h32", "➕ Add")
        btnGRename := popup.Add("Button", "x290 y92 w120 h32", "✏️ Rename")
        btnGDelete := popup.Add("Button", "x290 y129 w120 h32", "❌ Delete")
        btnGUp := popup.Add("Button", "x290 y210 w58 h32", "↑ Up")
        btnGDown := popup.Add("Button", "x352 y210 w58 h32", "↓ Down")

        ; Close button
        btnGClose := popup.Add("Button", "x290 y253 w120 h32", "Close")

        ; Helper: refresh the popup's group list
        RefreshGroupList(selectName := "") {
            lbGroups.Delete()
            groupNames := []
            for _, secName in this.groupOrder {
                gn := this.GetGroupName(secName)
                if (gn != "") {
                    prefix := (SubStr(secName, 1, 11) == "Group_Menu_") ? "📋 " : "⌨️ "
                    itemCount := this.localData.Has(secName) ? this.localData[secName].Length : 0
                    groupNames.Push(prefix . gn . "  (" . itemCount . ")")
                }
            }
            if (groupNames.Length > 0)
                lbGroups.Add(groupNames)

            if (selectName != "") {
                for i, secName in this.groupOrder {
                    if (this.GetGroupName(secName) == selectName) {
                        lbGroups.Choose(i)
                        break
                    }
                }
            } else if (groupNames.Length > 0) {
                lbGroups.Choose(1)
            }
        }

        ; Helper: get the selected group's index in groupOrder
        GetSelectedIdx() {
            return lbGroups.Value
        }

        ; --- Add Group ---
        btnGAdd.OnEvent("Click", (*) => OnAdd())
        OnAdd() {
            popup.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.mainHwnd)
            ib := InputBox("Enter a name for the new group:`n(Prefix with '*' for menu-only group)", "New Group", "w350 h140")
            popup.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.mainHwnd)

            if (ib.Result != "OK" || Trim(ib.Value) == "")
                return
            gInput := Trim(ib.Value)
            isMenuOnly := (SubStr(gInput, 1, 1) == "*")
            gName := isMenuOnly ? Trim(SubStr(gInput, 2)) : gInput
            gName := Trim(gName)
            if (gName == "") {
                MsgBox("⚠️ Group name cannot be empty.", "Warning", 262192)
                return
            }
            if (this.localData.Has("Group_Space_" . gName) || this.localData.Has("Group_Menu_" . gName)) {
                MsgBox("⚠️ Group '" . gName . "' already exists.", "Duplicate Group", 262160)
                return
            }
            sec := (isMenuOnly ? "Group_Menu_" : "Group_Space_") . gName
            this.localData[sec] := []
            this.groupOrder.Push(sec)
            this.SaveSettings()
            this.UpdateGroupsDdl(gName)
            this.RefreshList(0)
            RefreshGroupList(gName)
            ToolTip("✅ Group '" . gName . "' Created")
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Rename Group ---
        btnGRename.OnEvent("Click", (*) => OnRename())
        OnRename() {
            selIdx := GetSelectedIdx()
            if (selIdx == 0 || selIdx > this.groupOrder.Length)
                return
            oldSec := this.groupOrder[selIdx]
            oldName := this.GetGroupName(oldSec)
            if (oldName == "Default") {
                MsgBox("⚠️ The Default group cannot be renamed.", "Warning", 262192)
                return
            }

            popup.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.mainHwnd)
            ib := InputBox("Rename group '" . oldName . "' to:", "Rename Group", "w350 h120", oldName)
            popup.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.mainHwnd)

            if (ib.Result != "OK" || Trim(ib.Value) == "" || Trim(ib.Value) == oldName)
                return
            newName := Trim(ib.Value)
            if (this.localData.Has("Group_Space_" . newName) || this.localData.Has("Group_Menu_" . newName)) {
                MsgBox("⚠️ Group '" . newName . "' already exists.", "Duplicate Group", 262160)
                return
            }
            ; Preserve prefix type (Space or Menu)
            isMenu := (SubStr(oldSec, 1, 11) == "Group_Menu_")
            newSec := (isMenu ? "Group_Menu_" : "Group_Space_") . newName

            ; Migrate data
            if (this.localData.Has(oldSec)) {
                this.localData[newSec] := this.localData[oldSec]
                this.localData.Delete(oldSec)
            } else {
                this.localData[newSec] := []
            }
            ; Update groupOrder
            this.groupOrder[selIdx] := newSec

            this.SaveSettings()
            this.UpdateGroupsDdl(newName)
            this.RefreshList(0)
            RefreshGroupList(newName)
            ToolTip("✅ Group Renamed: " . oldName . " → " . newName)
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Delete Group ---
        btnGDelete.OnEvent("Click", (*) => OnDelete())
        OnDelete() {
            selIdx := GetSelectedIdx()
            if (selIdx == 0 || selIdx > this.groupOrder.Length)
                return
            sec := this.groupOrder[selIdx]
            gName := this.GetGroupName(sec)
            if (gName == "Default") {
                MsgBox("⚠️ The Default group cannot be deleted.", "Warning", 262192)
                return
            }
            itemCount := this.localData.Has(sec) ? this.localData[sec].Length : 0
            msgRes := MsgBox("❓ Are you sure you want to delete group '" . gName . "'?`n(" . itemCount . " hotstrings will be removed)", "Delete Group", 262436)
            if (msgRes != "Yes")
                return
            if (this.localData.Has(sec))
                this.localData.Delete(sec)
            this.groupOrder.RemoveAt(selIdx)
            this.SaveSettings()
            this.UpdateGroupsDdl()
            this.RefreshList(0)
            RefreshGroupList()
            ToolTip("✅ Group '" . gName . "' Deleted")
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Move Up ---
        btnGUp.OnEvent("Click", (*) => OnMove(-1))
        ; --- Move Down ---
        btnGDown.OnEvent("Click", (*) => OnMove(1))
        OnMove(dir) {
            selIdx := GetSelectedIdx()
            if (selIdx == 0)
                return
            targetIdx := selIdx + dir
            if (targetIdx < 1 || targetIdx > this.groupOrder.Length)
                return
            gName := this.GetGroupName(this.groupOrder[selIdx])
            temp := this.groupOrder[selIdx]
            this.groupOrder[selIdx] := this.groupOrder[targetIdx]
            this.groupOrder[targetIdx] := temp
            this.SaveSettings()
            this.UpdateGroupsDdl(gName)
            RefreshGroupList(gName)
        }

        btnGClose.OnEvent("Click", (*) => CleanUpAndClose())

        RefreshGroupList()
        popup.Show("w425 h300")
    }

    GetGroupName(secName) {
        if (SubStr(secName, 1, 12) == "Group_Space_")
            return SubStr(secName, 13)
        if (SubStr(secName, 1, 11) == "Group_Menu_")
            return SubStr(secName, 12)
        return ""
    }

    GetRawGroupName(displayName) {
        return displayName
    }

    UpdateGroupsDdl(selectGroup := "") {
        groups := []
        for _, secName in this.groupOrder {
            if (this.localData.Has(secName)) {
                gn := this.GetGroupName(secName)
                if (gn != "")
                    groups.Push(gn)
            }
        }

        this.cbGroup.Delete()
        if (groups.Length > 0)
            this.cbGroup.Add(groups)

        if (selectGroup != "") {
            this.cbGroup.Text := selectGroup
        } else if (groups.Length > 0) {
            this.cbGroup.Choose(1)
        }
    }

    OnGroupChange() {
        sec := this.GetCurrentSection()
        if (sec != "" && !this.localData.Has(sec)) {
            this.localData[sec] := []
        }
        this.RefreshList(0)
    }

    GetCurrentSection() {
        displayName := Trim(this.cbGroup.Text)
        if (displayName == "")
            displayName := "Default"
        rawName := this.GetRawGroupName(displayName)

        ; Check if it exists as Menu group first
        if (this.localData.Has("Group_Menu_" . rawName))
            return "Group_Menu_" . rawName
        return "Group_Space_" . rawName
    }

    IsDuplicateKey(keyToCheck, currentSec, currentIdx := 0) {
        for secName, items in this.localData {
            for idx, item in items {
                if (secName == currentSec && idx == currentIdx)
                    continue
                if (StrLower(item.Key) == StrLower(keyToCheck)) {
                    return this.GetGroupName(secName)
                }
            }
        }
        return ""
    }

    RefreshList(targetIdx := 0) {
        sec := this.GetCurrentSection()

        this.lbItems.Delete()
        listData := []

        if (this.localData.Has(sec)) {
            for idx, item in this.localData[sec] {
                displayVal := StrReplace(item.Val, "`n", " ↵ ")
                if (StrLen(displayVal) > 25)
                    displayVal := SubStr(displayVal, 1, 25) . "…"
                listData.Push("[ " . item.Key . " ]  ▶  " . displayVal)
            }
        }

        if (listData.Length > 0)
            this.lbItems.Add(listData)

        if (targetIdx > 0 && targetIdx <= listData.Length) {
            this.lbItems.Choose(targetIdx)
        }
    }

    EditSelectedItem() {
        idx := this.lbItems.Value
        if (idx > 0) {
            this.ShowEditPopup(true, idx)
        }
    }

    MoveItem(dir) {
        sec := this.GetCurrentSection()
        idx := this.lbItems.Value
        if (idx == 0)
            return

        targetIdx := idx + dir
        if (targetIdx < 1 || targetIdx > this.localData[sec].Length)
            return

        temp := this.localData[sec][idx]
        this.localData[sec][idx] := this.localData[sec][targetIdx]
        this.localData[sec][targetIdx] := temp

        this.RefreshList(targetIdx)
        this.SaveSettings()
    }

    ShowEditPopup(isEdit := false, editIdx := 0) {
        sec := this.GetCurrentSection()
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", isEdit ? "Edit Hotstring" : "Add Hotstring")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        ; Pre-fill values if editing
        existingKey := ""
        existingVal := ""
        if (isEdit && this.localData.Has(sec) && editIdx > 0 && editIdx <= this.localData[sec].Length) {
            existingKey := this.localData[sec][editIdx].Key
            existingVal := this.localData[sec][editIdx].Val
        }

        ; --- Abbreviation Section ---
        popup.Add("GroupBox", "x15 y10 w400 h90 cBlack", "③ Abbreviation (Trigger)")
        popup.Add("Text", "x30 y30 w370 c666666", "Type this text to trigger the expansion:")
        edtKey := popup.Add("Edit", "x30 y55 w370 h30", existingKey)

        ; --- Replacement Section ---
        popup.Add("GroupBox", "x15 y115 w400 h120 cBlack", "④ Replacement (Output)")
        popup.Add("Text", "x30 y135 w370 c666666", "The abbreviation will be replaced with this text:")
        edtVal := popup.Add("Edit", "x30 y158 w370 h60", existingVal)

        ; Action buttons
        popup.SetFont("s10 cWhite bold", "Segoe UI")
        btnConfirm := popup.Add("Text", "x215 y250 w200 h35 Center +0x200 +Border Background0078D7", isEdit ? "💾 Save Changes" : "➕ Add Hotstring")
        popup.SetFont("s10 cBlack norm", "Segoe UI")
        btnConfirm.OnEvent("Click", (*) => OnConfirm())

        btnCancel := popup.Add("Button", "x15 y250 w190 h35", "Cancel")
        btnCancel.OnEvent("Click", (*) => CleanUpAndClose())

        OnConfirm() {
            k := Trim(edtKey.Value)
            v := Trim(edtVal.Value)
            if (k == "" || v == "") {
                MsgBox("⚠️ Please enter both an abbreviation and its replacement text.", "Warning", 262192)
                return
            }

            dupGroup := this.IsDuplicateKey(k, sec, isEdit ? editIdx : 0)
            if (dupGroup != "") {
                MsgBox("⚠️ The abbreviation '" . k . "' is already registered in group: " . dupGroup . ".`nDuplicates are not allowed.", "Duplicate", 262160)
                return
            }

            if (!this.localData.Has(sec))
                this.localData[sec] := []

            if (isEdit) {
                this.localData[sec][editIdx].Key := k
                this.localData[sec][editIdx].Val := v
            } else {
                this.localData[sec].Push({ Key: k, Val: v })
            }

            this.RefreshList(isEdit ? editIdx : this.localData[sec].Length)
            this.SaveSettings()
            CleanUpAndClose()
            ToolTip(isEdit ? "✅ Modified & Saved" : "✅ Added & Saved")
            SetTimer(() => ToolTip(), -2000)
        }

        popup.Show("w430 h300")
    }

    DeleteItem() {
        sec := this.GetCurrentSection()
        selIdx := this.lbItems.Value
        if (selIdx == 0)
            return

        item := this.localData[sec][selIdx]
        friendlyItem := "[ " . item.Key . " ]  ▶  " . StrReplace(item.Val, "`n", " ↵ ")
        msgRes := MsgBox("❓ Are you sure you want to delete this hotstring?`n`n" . friendlyItem, "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.localData[sec].RemoveAt(selIdx)

        this.RefreshList(selIdx > this.localData[sec].Length ? this.localData[sec].Length : selIdx)
        this.SaveSettings()
        ToolTip("✅ Deleted & Saved")
        SetTimer(() => ToolTip(), -2000)
    }

    SaveSettings() {
        IniWrite("3", this.settingFile, "Meta", "SchemaVersion")

        sections := ""
        try sections := IniRead(this.settingFile)
        if (sections != "") {
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (secName == "" || secName == "Meta")
                    continue
                try IniDelete(this.settingFile, secName)
            }
        }

        for _, secName in this.groupOrder {
            if !this.localData.Has(secName)
                continue
            items := this.localData[secName]
            if (items.Length > 0) {
                content := ""
                for idx, item in items {
                    content .= item.Key . "=" . item.Val . "`n"
                }
                IniWrite(content, this.settingFile, secName)
            }
        }

        try IniDelete(this.settingFile, "GroupOrder")
        orderStr := ""
        for secName in this.groupOrder {
            orderStr .= secName . ","
        }
        if (orderStr != "") {
            orderStr := SubStr(orderStr, 1, -1)
            IniWrite(orderStr, this.settingFile, "GroupOrder", "Order")
        }

        LoadHotstrings()
    }
}


class KeyRemapManager {
    static settingFile := ""

    static Init(filePath) {
        this.settingFile := filePath
    }

    __New(parentGui := "") {
        global g_filePath_KeyRemap
        KeyRemapManager.Init(g_filePath_KeyRemap)
        this.parentGui := parentGui
        this.localData := []

        if FileExist(g_filePath_KeyRemap) {
            content := IniRead(g_filePath_KeyRemap, "Remaps", , "")
            if (content != "") {
                loop parse, content, "`n", "`r" {
                    if !A_LoopField
                        continue
                    idx := InStr(A_LoopField, "=")
                    if (idx > 0) {
                        src := Trim(SubStr(A_LoopField, 1, idx - 1))
                        dst := Trim(SubStr(A_LoopField, idx + 1))
                        this.localData.Push({ Src: src, Dst: dst })
                    }
                }
            }
        }

        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.rGui := Gui("+AlwaysOnTop -MaximizeBox", "Key Remap Manager")
            gui_EnableDarkMode(this.rGui)
            this.BuildUI(this.rGui)
            this.rGui.Show("AutoSize")
        }
    }

    BuildUI(guiObj) {
        startX := this.parentGui ? 35 : 25
        startY := this.parentGui ? 115 : 80
        guiObj.SetFont("s10", "Segoe UI")
        this.mainHwnd := guiObj.Hwnd

        guiObj.Add("Text", "x" . startX . " y" . startY . " w400", "① Active Key Mappings:")

        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 25) . " w310 h345")

        guiObj.SetFont("s9 c888888 norm", "Segoe UI")
        guiObj.Add("Text", "x" . startX . " y" . (startY + 375) . " w310 BackgroundTrans", "e.g.) Caps Lock → Left Click")
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY - 5) . " w85 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Key Remaps"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        btnAdd := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 25) . " w85 h35", "New (+)")
        btnEdit := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 65) . " w85 h35", "Edit (✏️)")
        btnDel := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 105) . " w85 h35", "Delete (x)")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 385) . " w85 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.RefreshList()

        this.lbItems.OnEvent("DoubleClick", (*) => this.EditSelectedItem())
        btnEdit.OnEvent("Click", (*) => this.EditSelectedItem())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnAdd.OnEvent("Click", (*) => this.ShowEditPopup(false, 0))
    }

    ParseKeyString(keyStr) {
        mods := { Ctrl: 0, Shift: 0, Win: 0, Alt: 0 }
        baseKey := keyStr
        loop {
            char := SubStr(baseKey, 1, 1)
            if (char == "^") {
                mods.Ctrl := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "+") {
                mods.Shift := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "#") {
                mods.Win := 1
                baseKey := SubStr(baseKey, 2)
            } else if (char == "!") {
                mods.Alt := 1
                baseKey := SubStr(baseKey, 2)
            } else {
                break
            }
        }
        return { Mods: mods, BaseKey: baseKey }
    }

    BuildKeyString(ctrl, shift, win, alt, baseKey) {
        prefix := ""
        if (ctrl)
            prefix .= "^"
        if (shift)
            prefix .= "+"
        if (win)
            prefix .= "#"
        if (alt)
            prefix .= "!"
        return prefix . baseKey
    }

    TranslateKeyToFriendly(keyStr) {
        parsed := this.ParseKeyString(keyStr)
        mods := []
        if (parsed.Mods.Ctrl)
            mods.Push("Ctrl")
        if (parsed.Mods.Shift)
            mods.Push("Shift")
        if (parsed.Mods.Win)
            mods.Push("Win")
        if (parsed.Mods.Alt)
            mods.Push("Alt")

        friendlyBase := parsed.BaseKey
        keyMap := Map(
            "LButton", "Left Click",
            "RButton", "Right Click",
            "MButton", "Middle Click",
            "XButton1", "Mouse Back",
            "XButton2", "Mouse Forward",
            "WheelUp", "Wheel Up",
            "WheelDown", "Wheel Down",
            "Space", "Space",
            "Enter", "Enter",
            "Backspace", "Backspace",
            "Tab", "Tab",
            "Escape", "Esc",
            "CapsLock", "Caps Lock",
            "ScrollLock", "Scroll Lock",
            "NumLock", "Num Lock",
            "PrintScreen", "Print Screen",
            "Insert", "Insert",
            "Delete", "Delete",
            "Home", "Home",
            "End", "End",
            "PgUp", "Page Up",
            "PgDn", "Page Down",
            "AppsKey", "Menu Key",
            "Volume_Up", "Volume Up",
            "Volume_Down", "Volume Down",
            "Volume_Mute", "Mute",
            "Media_Play_Pause", "Play/Pause",
            "Media_Next", "Next Track",
            "Media_Prev", "Prev Track",
            "Media_Stop", "Stop Media",
            "NumpadEnter", "Numpad Enter",
            "NumpadAdd", "Numpad +",
            "NumpadSub", "Numpad -",
            "NumpadMult", "Numpad *",
            "NumpadDiv", "Numpad /",
            "NumpadDot", "Numpad ."
        )

        lowerBase := StrLower(parsed.BaseKey)
        for k, v in keyMap {
            if (StrLower(k) == lowerBase) {
                friendlyBase := v
                break
            }
        }

        if (StrLen(friendlyBase) == 1) {
            friendlyBase := StrUpper(friendlyBase)
        }

        if (mods.Length > 0) {
            prefix := ""
            for i, mod in mods {
                prefix .= (i > 1 ? " + " : "") . mod
            }
            return prefix . " + [" . friendlyBase . "]"
        }
        return "[" . friendlyBase . "]"
    }

    RefreshList(targetIdx := 0) {
        listData := []
        for obj in this.localData {
            friendlySrc := this.TranslateKeyToFriendly(obj.Src)
            friendlyDst := this.TranslateKeyToFriendly(obj.Dst)
            listData.Push(friendlySrc . "  →  " . friendlyDst)
        }
        this.lbItems.Delete()
        if (listData.Length > 0)
            this.lbItems.Add(listData)
        if (targetIdx > 0 && targetIdx <= listData.Length) {
            this.lbItems.Choose(targetIdx)
        }
    }

    EditSelectedItem() {
        idx := this.lbItems.Value
        if (idx > 0 && idx <= this.localData.Length) {
            this.ShowEditPopup(true, idx)
        }
    }

    DeleteItem() {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        friendlySrc := this.TranslateKeyToFriendly(this.localData[idx].Src)
        friendlyDst := this.TranslateKeyToFriendly(this.localData[idx].Dst)
        friendlyItem := friendlySrc . "  →  " . friendlyDst

        msgRes := MsgBox("❓ Are you sure you want to delete this key mapping?`n`n" . friendlyItem, "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.localData.RemoveAt(idx)
        this.RefreshList(idx > this.localData.Length ? this.localData.Length : idx)
        this.SaveSettings()
        ToolTip("✅ Deleted & Saved")
        SetTimer(() => ToolTip(), -2000)
    }

    ShowEditPopup(isEdit := false, editIdx := 0) {
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", isEdit ? "Modify Key Mapping" : "Add Key Mapping")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        ; Key definitions mapping technical AHK keys to beautiful display labels
        keyDefs := [{ Key: "CapsLock", Disp: "Caps Lock" }, { Key: "ScrollLock", Disp: "Scroll Lock" }, { Key: "NumLock", Disp: "Num Lock" }, { Key: "PrintScreen", Disp: "Screen Capture" }, { Key: "Insert", Disp: "Insert" }, { Key: "Delete", Disp: "Delete" }, { Key: "AppsKey", Disp: "Context Menu" }, { Key: "Tab", Disp: "Tab" }, { Key: "Space", Disp: "Spacebar" }, { Key: "Enter", Disp: "Enter" }, { Key: "Backspace", Disp: "Backspace" }, { Key: "Escape", Disp: "Esc" }, { Key: "Home", Disp: "Home" }, { Key: "End", Disp: "End" }, { Key: "PgUp", Disp: "Page Up" }, { Key: "PgDn", Disp: "Page Down" }, { Key: "F1", Disp: "F1" }, { Key: "F2", Disp: "F2" }, { Key: "F3", Disp: "F3" }, { Key: "F4", Disp: "F4" }, { Key: "F5", Disp: "F5" }, { Key: "F6", Disp: "F6" }, { Key: "F7", Disp: "F7" }, { Key: "F8", Disp: "F8" }, { Key: "F9", Disp: "F9" }, { Key: "F10", Disp: "F10" }, { Key: "F11", Disp: "F11" }, { Key: "F12", Disp: "F12" }, { Key: "LButton", Disp: "🖱️ Mouse Left Click" }, { Key: "RButton", Disp: "🖱️ Mouse Right Click" }, { Key: "MButton", Disp: "🖱️ Mouse Wheel Click" }, { Key: "XButton1", Disp: "🖱️ Mouse Back Button" }, { Key: "XButton2", Disp: "🖱️ Mouse Forward Button" }, { Key: "WheelUp", Disp: "🖱️ Mouse Wheel Roll Up" }, { Key: "WheelDown", Disp: "🖱️ Mouse Wheel Roll Down" }, { Key: "Numpad0", Disp: "Keypad 0" }, { Key: "Numpad1", Disp: "Keypad 1" }, { Key: "Numpad2", Disp: "Keypad 2" }, { Key: "Numpad3", Disp: "Keypad 3" }, { Key: "Numpad4", Disp: "Keypad 4" }, { Key: "Numpad5", Disp: "Keypad 5" }, { Key: "Numpad6", Disp: "Keypad 6" }, { Key: "Numpad7", Disp: "Keypad 7" }, { Key: "Numpad8", Disp: "Keypad 8" }, { Key: "Numpad9", Disp: "Keypad 9" }, { Key: "NumpadEnter", Disp: "Keypad Enter" }, { Key: "NumpadAdd", Disp: "Keypad +" }, { Key: "NumpadSub", Disp: "Keypad -" }, { Key: "NumpadMult", Disp: "Keypad *" }, { Key: "NumpadDiv", Disp: "Keypad /" }, { Key: "NumpadDot", Disp: "Keypad ." }, { Key: "Media_Play_Pause", Disp: "Media Play/Pause" }, { Key: "Media_Next", Disp: "Media Next Track" }, { Key: "Media_Prev", Disp: "Media Prev Track" }, { Key: "Media_Stop", Disp: "Media Stop" }, { Key: "Volume_Up", Disp: "Volume Up" }, { Key: "Volume_Down", Disp: "Volume Down" }, { Key: "Volume_Mute", Disp: "Volume Mute" }, { Key: "a", Disp: "A" }, { Key: "b", Disp: "B" }, { Key: "c", Disp: "C" }, { Key: "d", Disp: "D" }, { Key: "e", Disp: "E" }, { Key: "f", Disp: "F" }, { Key: "g", Disp: "G" }, { Key: "h", Disp: "H" }, { Key: "i", Disp: "I" }, { Key: "j", Disp: "J" }, { Key: "k", Disp: "K" }, { Key: "l", Disp: "L" }, { Key: "m", Disp: "M" }, { Key: "n", Disp: "N" }, { Key: "o", Disp: "O" }, { Key: "p", Disp: "P" }, { Key: "q", Disp: "Q" }, { Key: "r", Disp: "R" }, { Key: "s", Disp: "S" }, { Key: "t", Disp: "T" }, { Key: "u", Disp: "U" }, { Key: "v", Disp: "V" }, { Key: "w", Disp: "W" }, { Key: "x", Disp: "X" }, { Key: "y", Disp: "Y" }, { Key: "z", Disp: "Z" }, { Key: "0", Disp: "0" }, { Key: "1", Disp: "1" }, { Key: "2", Disp: "2" }, { Key: "3", Disp: "3" }, { Key: "4", Disp: "4" }, { Key: "5", Disp: "5" }, { Key: "6", Disp: "6" }, { Key: "7", Disp: "7" }, { Key: "8", Disp: "8" }, { Key: "9", Disp: "9" }
        ]

        comboList := []
        for item in keyDefs {
            comboList.Push(item.Disp)
        }

        GetDisplayString(baseKey) {
            lowerKey := StrLower(baseKey)
            for item in keyDefs {
                if (StrLower(item.Key) == lowerKey) {
                    return item.Disp
                }
            }
            return baseKey
        }

        GetKeyFromDisp(dispStr) {
            lowerDisp := StrLower(Trim(dispStr))
            for item in keyDefs {
                if (StrLower(item.Disp) == lowerDisp || StrLower(item.Key) == lowerDisp) {
                    return item.Key
                }
            }
            return dispStr ; Fallback to custom user typing
        }

        ; Parse edit values if applicable
        srcParsed := { Mods: { Ctrl: 0, Shift: 0, Win: 0, Alt: 0 }, BaseKey: "" }
        dstParsed := { Mods: { Ctrl: 0, Shift: 0, Win: 0, Alt: 0 }, BaseKey: "" }
        if (isEdit && editIdx > 0 && editIdx <= this.localData.Length) {
            srcParsed := this.ParseKeyString(this.localData[editIdx].Src)
            dstParsed := this.ParseKeyString(this.localData[editIdx].Dst)
        }

        ; --- From Section ---
        popup.Add("GroupBox", "x15 y15 w450 h90 cBlack", "② From (Press Key)")
        popup.Add("Text", "x30 y35 w420 c666666", "Select modifier keys and a base key:")
        chkSrcCtrl := popup.Add("CheckBox", "x30 y60 w50", "Ctrl")
        chkSrcShift := popup.Add("CheckBox", "x85 y60 w55", "Shift")
        chkSrcWin := popup.Add("CheckBox", "x145 y60 w50", "Win")
        chkSrcAlt := popup.Add("CheckBox", "x200 y60 w45", "Alt")
        cbSrc := popup.Add("ComboBox", "x255 y57 w195", comboList)

        ; --- To Section ---
        popup.Add("GroupBox", "x15 y120 w450 h90 cBlack", "③ To (Remapped Action)")
        popup.Add("Text", "x30 y140 w420 c666666", "This key combination will be triggered instead:")
        chkDstCtrl := popup.Add("CheckBox", "x30 y165 w50", "Ctrl")
        chkDstShift := popup.Add("CheckBox", "x85 y165 w55", "Shift")
        chkDstWin := popup.Add("CheckBox", "x145 y165 w50", "Win")
        chkDstAlt := popup.Add("CheckBox", "x200 y165 w45", "Alt")
        cbDst := popup.Add("ComboBox", "x255 y162 w195", comboList)

        ; Set values if editing
        if (isEdit) {
            chkSrcCtrl.Value := srcParsed.Mods.Ctrl
            chkSrcShift.Value := srcParsed.Mods.Shift
            chkSrcWin.Value := srcParsed.Mods.Win
            chkSrcAlt.Value := srcParsed.Mods.Alt
            cbSrc.Text := GetDisplayString(srcParsed.BaseKey)

            chkDstCtrl.Value := dstParsed.Mods.Ctrl
            chkDstShift.Value := dstParsed.Mods.Shift
            chkDstWin.Value := dstParsed.Mods.Win
            chkDstAlt.Value := dstParsed.Mods.Alt
            cbDst.Text := GetDisplayString(dstParsed.BaseKey)
        }

        ; Action buttons
        popup.SetFont("s10 cWhite bold", "Segoe UI")
        btnConfirm := popup.Add("Text", "x240 y230 w225 h35 Center +0x200 +Border Background0078D7", isEdit ? "💾 Modify Mapping" : "➕ Add Mapping")
        popup.SetFont("s10 cBlack norm", "Segoe UI")
        btnConfirm.OnEvent("Click", (*) => OnConfirm())

        btnCancel := popup.Add("Button", "x15 y230 w215 h35", "Cancel")
        btnCancel.OnEvent("Click", (*) => CleanUpAndClose())

        OnConfirm() {
            srcDisp := Trim(cbSrc.Text)
            dstDisp := Trim(cbDst.Text)
            if (srcDisp == "" || dstDisp == "") {
                MsgBox("⚠️ Please select or type both Source and Destination keys.", "Warning", 262192)
                return
            }

            srcBase := GetKeyFromDisp(srcDisp)
            dstBase := GetKeyFromDisp(dstDisp)

            try validName := GetKeyName(srcBase)
            catch
                validName := ""
            if (validName == "") {
                MsgBox("⚠️ '" . srcBase . "' is not a valid key name.", "Invalid Key", 262160)
                return
            }

            src := this.BuildKeyString(chkSrcCtrl.Value, chkSrcShift.Value, chkSrcWin.Value, chkSrcAlt.Value, srcBase)
            dst := this.BuildKeyString(chkDstCtrl.Value, chkDstShift.Value, chkDstWin.Value, chkDstAlt.Value, dstBase)

            blacklist := ["lbutton", "rbutton", "mbutton", "escape"]
            if (HasVal(blacklist, StrLower(src))) {
                MsgBox("⚠️ The key '" . src . "' is critical and cannot be remapped.", "Remap Blocked", 262160)
                return
            }

            ; Duplicate check
            for idx, item in this.localData {
                if (isEdit && idx == editIdx)
                    continue
                if (StrLower(item.Src) == StrLower(src)) {
                    MsgBox("⚠️ A mapping for '" . src . "' already exists.", "Duplicate Mapping", 262160)
                    return
                }
            }

            if (isEdit) {
                this.localData[editIdx] := { Src: src, Dst: dst }
            } else {
                this.localData.Push({ Src: src, Dst: dst })
            }

            this.RefreshList(isEdit ? editIdx : this.localData.Length)
            this.SaveSettings()
            CleanUpAndClose()
            ToolTip(isEdit ? "✅ Modified & Saved" : "✅ Added & Saved")
            SetTimer(() => ToolTip(), -2000)
        }

        popup.Show("w480 h280")
    }

    SaveSettings() {
        try IniDelete(KeyRemapManager.settingFile, "Remaps")

        content := ""
        for item in this.localData {
            content .= item.Src . "=" . item.Dst . "`n"
        }
        if (content != "") {
            IniWrite(content, KeyRemapManager.settingFile, "Remaps")
        }

        LoadKeyRemaps()
    }
}

HasVal(arr, val) {
    for index, value in arr {
        if (value == val)
            return true
    }
    return false
}

; --- 종료 핫키 ---
#^Escape:: ExitApp

; =================================================================================
; --- 이모지 & 심볼 팝업 메뉴 (Emoji Picker) ---
; =================================================================================

BuildEmojiMenu() {
    global EmojiMenu, g_filePath_Hotstring
    EmojiMenu.Delete()

    SendEmoji(ItemName, ItemPos, MyMenu) {
        ; "  [" 패턴이 존재하면 그 앞의 내용 전체를 심볼로 사용
        idx := InStr(ItemName, "  [")
        if (idx > 0) {
            symbol := SubStr(ItemName, 1, idx - 1)
        } else {
            arr := StrSplit(ItemName, " ")
            symbol := arr[1]
        }
        SendText(symbol)
    }

    ; User Hotstring & Menu Groups
    if FileExist(g_filePath_Hotstring) {
        sections := ""
        try sections := IniRead(g_filePath_Hotstring)
        if (sections != "") {
            groupIndex := 1
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (secName == "" || secName == "Meta")
                    continue

                displayName := ""
                if (SubStr(secName, 1, 12) == "Group_Space_") {
                    displayName := SubStr(secName, 13)
                } else if (SubStr(secName, 1, 11) == "Group_Menu_") {
                    displayName := SubStr(secName, 12)
                } else {
                    continue
                }

                pairs := ""
                try pairs := IniRead(g_filePath_Hotstring, secName, , "")
                if (pairs == "")
                    continue

                mUserGroup := Menu()
                hasItems := false
                loop parse, pairs, "`n", "`r" {
                    if !A_LoopField
                        continue
                    idx := InStr(A_LoopField, "=")
                    if (idx > 0) {
                        k := Trim(SubStr(A_LoopField, 1, idx - 1))
                        v := Trim(SubStr(A_LoopField, idx + 1))
                        if (k != "" && v != "") {
                            mUserGroup.Add(v . "  [" . k . "]", SendEmoji)
                            hasItems := true
                        }
                    }
                }

                if (hasItems) {
                    EmojiMenu.Add(groupIndex . "️⃣ " . displayName, mUserGroup)
                    groupIndex++
                }
            }
        }
    }
}

; 단축키: Ctrl + Win + Space (이모지 픽커 호출)
^#Space:: {
    EmojiMenu.Show()
}

class DashboardManager {
    static instance := ""

    static Show(tabIndex := 1) {
        if (!DashboardManager.instance) {
            DashboardManager.instance := DashboardManager()
        }
        DashboardManager.instance.ShowGui(tabIndex)
    }

    __New() {
        this.hGui := Gui("+AlwaysOnTop", "SwiftDeck App Settings")
        gui_ApplyTheme(this.hGui, "SwiftDeck", "v" . g_appVersion . " | FinOps Automation & HotKey Suite")
        this.hGui.OnEvent("Close", (*) => this.hGui.Hide())

        ; Add top-right global buttons (Manual & Info)
        this.hGui.SetFont("s9 cCCCCCC norm", "Segoe UI")
        btnGlobalManual := this.hGui.Add("Text", "x310 y20 w80 h28 Center +0x200 +Border Background3A3A3D", "📘 Manual")
        btnGlobalManual.OnEvent("Click", (*) => OpenAppManual("EN", this.hGui.Hwnd))

        btnGlobalInfo := this.hGui.Add("Text", "x395 y20 w85 h28 Center +0x200 +Border Background3A3A3D", "ℹ️ App Info")
        btnGlobalInfo.OnEvent("Click", (*) => ShowAppInformation(this.hGui.Hwnd))
        this.hGui.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        ; Create Tab Control
        this.mainTab := this.hGui.Add("Tab3", "x20 y75 w460 h560", ["📁 Folders", "⌨️ Prompts", "✏️ Hotstrings", "🔀 Key Remap", "⚙️ General"])

        this.mainTab.UseTab(1)
        this.folderMgr := FolderManager(this.hGui)

        this.mainTab.UseTab(2)
        this.promptMgr := PromptManager(this.hGui)

        this.mainTab.UseTab(3)
        this.hotstringMgr := HotstringManager(this.hGui)

        this.mainTab.UseTab(4)
        this.keyRemapMgr := KeyRemapManager(this.hGui)

        this.mainTab.UseTab(5)
        this.prefMgr := PreferencesManager(this.hGui)

        this.mainTab.UseTab()
    }

    ShowGui(tabIndex) {
        this.mainTab.Choose(tabIndex)
        this.hGui.Show()
    }
}
