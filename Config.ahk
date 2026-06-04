#Requires AutoHotkey v2.0
;@disable-check undeclared
; =============================================================================
; --- Config File Initialization & Management ---
; =============================================================================

InitializeConfig(fileName, defaultText) {
    global g_targetFolder

    ; Create target folder if it doesn't exist
    if !DirExist(g_targetFolder) {
        DirCreate(g_targetFolder)
    }

    targetFile := g_targetFolder . fileName

    ; [Step 1] Check if config file already exists locally
    if (FileExist(targetFile)) {
        return ; File exists, nothing to do
    }

    ; [Step 2] Create file from built-in default template
    try {
        ; UTF-8-RAW: Save without BOM (BOM breaks Windows INI API for first section)
        FileAppend(defaultText, targetFile, "UTF-8-RAW")
    } catch {
        MsgBox("⚠️ Cannot create file in the target drive.`n`nPath: " . targetFile, "Error", 262160)
    }
}

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
            MsgBox("✅ Settings have been backed up successfully.", "Backup Complete", 262208)
    } catch {
        if (showMsg)
            MsgBox("❌ An error occurred during backup.", "Error", 262160)
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

; =============================================================================
; SECTION: Central Config Gateway
; =============================================================================
GetConfigPath(configName) {
    global g_filePath_Folder, g_filePath_Hotkey, g_filePath_Hotstring, g_filePath_KeyRemap

    switch configName {
        case "Settings", "Folders", "Favorites":
            return g_filePath_Folder
        case "Prompts", "Hotkeys":
            return g_filePath_Hotkey
        case "Hotstrings":
            return g_filePath_Hotstring
        case "KeyRemaps", "Key Remaps":
            return g_filePath_KeyRemap
        default:
            throw Error("Unknown config file: " . configName)
    }
}

ConfigExists(configName) {
    return FileExist(GetConfigPath(configName))
}

ConfigReadValue(configName, section, key, defaultValue := "") {
    try {
        return IniRead(GetConfigPath(configName), section, key, defaultValue)
    } catch {
        return defaultValue
    }
}

ConfigWriteValue(configName, section, key, value) {
    IniWrite(value, GetConfigPath(configName), section, key)
}

ConfigReadSection(configName, section, defaultValue := "") {
    try {
        return IniRead(GetConfigPath(configName), section, , defaultValue)
    } catch {
        return defaultValue
    }
}

ConfigWriteSection(configName, section, content) {
    if (content != "") {
        IniWrite(content, GetConfigPath(configName), section)
    } else {
        try IniDelete(GetConfigPath(configName), section)
    }
}

ConfigDeleteSection(configName, section) {
    try IniDelete(GetConfigPath(configName), section)
}

ConfigReadSections(configName) {
    try {
        return IniRead(GetConfigPath(configName))
    } catch {
        return ""
    }
}

ConfigReadAppSettings() {
    return {
        MainHotkey: ConfigReadValue("Settings", "Settings", "MainHotkey", "F1"),
        PromptModifier: ConfigReadValue("Settings", "Settings", "PromptModifier", "#"),
        PromptUseNumpad: Integer(ConfigReadValue("Settings", "Settings", "PromptUseNumpad", "1")),
        EmojiHotkey: ConfigReadValue("Settings", "Settings", "EmojiHotkey", "^#Space"),
        ExitHotkey: ConfigReadValue("Settings", "Settings", "ExitHotkey", "^#Escape")
    }
}

ConfigWriteAppSettings(mainHotkey, promptModifier, promptUseNumpad) {
    ConfigWriteValue("Settings", "Settings", "MainHotkey", mainHotkey)
    ConfigWriteValue("Settings", "Settings", "PromptModifier", promptModifier)
    ConfigWriteValue("Settings", "Settings", "PromptUseNumpad", promptUseNumpad)
}

ConfigReadFolderItems() {
    items := []
    content := ConfigReadSection("Folders", "FolderMenu", "")

    if (content != "") {
        loop parse, content, "`n", "`r" {
            pair := ParseIniKeyValuePairs(A_LoopField)
            if (pair.Key != "")
                items.Push({ Name: pair.Key, Path: pair.Val })
        }
    }

    return items
}

ConfigWriteFolderItems(items) {
    content := ""
    for item in items {
        content .= item.Name . "=" . item.Path . "`n"
    }
    ConfigWriteSection("Folders", "FolderMenu", content)
}

ConfigReadPromptData() {
    promptData := Map()
    loop 10 {
        num := A_Index - 1
        promptData[num] := []
        content := ConfigReadSection("Prompts", "Numpad" . num, "")

        if (content != "") {
            loop parse, content, "`n", "`r" {
                pair := ParseIniKeyValuePairs(A_LoopField)
                if (pair.Key != "") {
                    promptData[num].Push({ Title: pair.Key, Msg: StrReplace(pair.Val, "\n", "`n") })
                }
            }
        }
    }
    return promptData
}

ConfigReadPromptItems(groupNum) {
    items := []
    content := ConfigReadSection("Prompts", "Numpad" . groupNum, "")

    if (content != "") {
        loop parse, content, "`n", "`r" {
            pair := ParseIniKeyValuePairs(A_LoopField)
            if (pair.Key != "") {
                items.Push({
                    fontSize: 11,
                    fontColor: "black",
                    label: pair.Key,
                    msg: StrReplace(pair.Val, "\n", "`n")
                })
            }
        }
    }

    return items
}

ConfigWritePromptData(promptData) {
    loop 10 {
        num := A_Index - 1
        content := ""
        if (promptData[num].Length > 0) {
            for item in promptData[num] {
                content .= item.Title . "=" . StrReplace(item.Msg, "`n", "\n") . "`n"
            }
        }
        ConfigWriteSection("Prompts", "Numpad" . num, content)
    }
}

ConfigReadHotstringData() {
    localData := Map()
    groupOrder := []
    discoveredOrder := []
    sections := ConfigReadSections("Hotstrings")

    if (sections != "") {
        loop parse, sections, "`n", "`r" {
            secName := Trim(A_LoopField)
            if (secName == "" || secName == "Meta" || secName == "GroupOrder")
                continue
            if (SubStr(secName, 1, 12) != "Group_Space_" && SubStr(secName, 1, 11) != "Group_Menu_")
                continue

            localData[secName] := []
            discoveredOrder.Push(secName)

            content := ConfigReadSection("Hotstrings", secName, "")
            if (content != "") {
                loop parse, content, "`n", "`r" {
                    pair := ParseIniKeyValuePairs(A_LoopField)
                    if (pair.Key != "") {
                        fixed := FixIniSpecialChars(pair.Key, pair.Val)
                        localData[secName].Push({ Key: fixed.Key, Val: StrReplace(fixed.Val, "\n", "`n") })
                    }
                }
            }
        }
    }

    savedOrder := ConfigReadValue("Hotstrings", "GroupOrder", "Order", "")
    if (savedOrder != "") {
        loop parse, savedOrder, "," {
            secName := Trim(A_LoopField)
            if (secName != "" && localData.Has(secName))
                groupOrder.Push(secName)
        }
    }

    for secName in discoveredOrder {
        if !ConfigArrayHasValue(groupOrder, secName)
            groupOrder.Push(secName)
    }

    if (localData.Count == 0) {
        localData["Group_Space_Default"] := []
        groupOrder.Push("Group_Space_Default")
    }

    return { Data: localData, GroupOrder: groupOrder }
}

ConfigWriteHotstringData(localData, groupOrder) {
    ConfigWriteValue("Hotstrings", "Meta", "SchemaVersion", "3")

    sections := ConfigReadSections("Hotstrings")
    if (sections != "") {
        loop parse, sections, "`n", "`r" {
            secName := Trim(A_LoopField)
            if (secName != "" && secName != "Meta")
                ConfigDeleteSection("Hotstrings", secName)
        }
    }

    for secName in groupOrder {
        if !localData.Has(secName)
            continue

        content := ""
        for item in localData[secName] {
            content .= item.Key . "=" . item.Val . "`n"
        }
        if (content == "")
            content := "; Empty group`n"
        ConfigWriteSection("Hotstrings", secName, content)
    }

    orderStr := ""
    for secName in groupOrder {
        orderStr .= secName . ","
    }
    if (orderStr != "") {
        orderStr := SubStr(orderStr, 1, -1)
        ConfigWriteValue("Hotstrings", "GroupOrder", "Order", orderStr)
    }
}

ConfigReadKeyRemaps() {
    remaps := []
    content := ConfigReadSection("KeyRemaps", "Remaps", "")

    if (content != "") {
        loop parse, content, "`n", "`r" {
            pair := ParseIniKeyValuePairs(A_LoopField)
            if (pair.Key != "")
                remaps.Push({ Src: pair.Key, Dst: pair.Val })
        }
    }

    return remaps
}

ConfigWriteKeyRemaps(remaps) {
    content := ""
    for item in remaps {
        content .= item.Src . "=" . item.Dst . "`n"
    }
    ConfigWriteSection("KeyRemaps", "Remaps", content)
}

ConfigCountPairs(configName, section) {
    count := 0
    content := ConfigReadSection(configName, section, "")
    loop parse, content, "`n", "`r" {
        if (ParseIniKeyValuePairs(A_LoopField).Key != "")
            count++
    }
    return count
}

ConfigArrayHasValue(arr, val) {
    for item in arr {
        if (item == val)
            return true
    }
    return false
}

; =============================================================================
; SECTION: Default Config Data Templates
; =============================================================================
GetDefaultFolderData() {
    return "[Settings]`n"
    . "MainHotkey=F1`n"
    . "PromptModifier=#`n"
    . "PromptUseNumpad=1`n`n"
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
    . "_asap=as soon as possible"
}

GetDefaultKeyRemapData() {
    return "[Remaps]`n"
    . "; Format: SourceKey=DestinationKey`n"
    . "; Example: CapsLock=LButton`n"
    . "; Example: ScrollLock=Tab"
}
