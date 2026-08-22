#Requires AutoHotkey v2.0
; =================================================================================
; --- Utility Functions ---
; =================================================================================

GetFileName(path) {
    SplitPath path, &name
    return name
}

OpenFolder(folderPath, Args*) {
    if !folderPath {
        MsgBox "Folder path is not specified.", "Error", 262192
        return
    }

    if FileExist(folderPath) && !DirExist(folderPath) {
        RunSafely('explorer.exe /select,"' folderPath '"', "Open Folder")
        return
    }

    if !DirExist(folderPath) {
        MsgBox "The specified folder does not exist.`n`n" folderPath, "Error", 262192
        return
    }

    RunSafely('explorer.exe "' folderPath '"', "Open Folder")
}

RunSafely(command, title := "Open Failed") {
    ; [Security] Block shell injection operators in command strings
    ; Characters like &, |, >, < can chain destructive OS commands
    if RegExMatch(command, "[&|><]") {
        MsgBox("⚠️ Blocked: The path contains potentially unsafe characters (&, |, >, <).`n`n" . command, "Security Warning", 262160)
        return false
    }
    try {
        Run(command)
        return true
    } catch Error as err {
        MsgBox("❌ Could not open the requested item.`n`n" . command . "`n`nError: " . err.Message, title, 262160)
        return false
    }
}

AddTrailingBackslash(path) {
    if !RegExMatch(path, "[\\/]$")
        path .= "\"
    return path
}

GetLastFolderName(path) {
    trimmedPath := RTrim(path, "\/")
    partList := StrSplit(trimmedPath, "\")

    if (partList.Length) {
        return partList[partList.Length]
    } else {
        return path
    }
}

GetFoldersList(folderPath, attributes := "") {
    folderList := []
    loop files folderPath, attributes {
        if InStr(A_LoopFileAttrib, "H")
            continue
        folderList.Push(A_LoopFileFullPath)
    }
    return folderList
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
    return { Mods: mods, Key: baseKey, BaseKey: baseKey }
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

NormalizeHotkey(hotkeyText) {
    parsed := ParseKeyString(hotkeyText)
    return StrLower(BuildKeyString(
        parsed.Mods.Ctrl,
        parsed.Mods.Shift,
        parsed.Mods.Win,
        parsed.Mods.Alt,
        parsed.BaseKey
    ))
}

GetAddFolderHotkey(mainHotkey) {
    parsed := ParseKeyString(mainHotkey)
    mods := parsed.Mods

    ; Add the first unused modifier so the Explorer action never collides with
    ; the Favorites Menu. The default remains F1 -> Ctrl+F1.
    if (!mods.Ctrl)
        mods.Ctrl := 1
    else if (!mods.Shift)
        mods.Shift := 1
    else if (!mods.Alt)
        mods.Alt := 1
    else if (!mods.Win)
        mods.Win := 1
    else
        ; No unused modifier remains. Keep a predictable, usable fallback
        ; (Ctrl + the same base key); central validation still checks it
        ; against every other registered shortcut.
        return "^" . parsed.BaseKey

    return BuildKeyString(mods.Ctrl, mods.Shift, mods.Win, mods.Alt, parsed.BaseKey)
}

GetPromptMenuHotkey() {
    return "+#Space"
}

ValidateHotkeyAssignments(mainHotkey, promptModifier, promptUseNumpad, emojiHotkey, exitHotkey, promptMenuHotkey := "") {
    if (promptMenuHotkey == "")
        promptMenuHotkey := GetPromptMenuHotkey()
    assignments := [
        { Name: "Favorites Menu", Hotkey: mainHotkey },
        { Name: "Add Current Explorer Folder", Hotkey: GetAddFolderHotkey(mainHotkey) },
        { Name: "Prompt Popup Menu", Hotkey: promptMenuHotkey },
        { Name: "Emoji & Symbols", Hotkey: emojiHotkey },
        { Name: "Exit App", Hotkey: exitHotkey }
    ]

    if (promptModifier != "") {
        loop 10 {
            num := A_Index - 1
            baseKey := promptUseNumpad ? "Numpad" . num : num
            assignments.Push({ Name: "Quick Prompt " . num, Hotkey: promptModifier . baseKey })
        }
    }

    seen := Map()
    for assignment in assignments {
        normalized := NormalizeHotkey(assignment.Hotkey)
        if (normalized == "")
            continue
        if (seen.Has(normalized)) {
            return assignment.Name . " conflicts with " . seen[normalized]
                . " (" . FormatHotkeyDisplay(assignment.Hotkey) . ")."
        }
        seen[normalized] := assignment.Name
    }
    return ""
}

FormatHotkeyDisplay(hotkeyLabel) {
    formattedHK := hotkeyLabel
    ; Replace "+" (Shift) first so the "+" introduced by later replacements
    ; (e.g. "Ctrl+") is not mistaken for a Shift modifier.
    formattedHK := StrReplace(formattedHK, "+", "Shift+")
    formattedHK := StrReplace(formattedHK, "^", "Ctrl+")
    formattedHK := StrReplace(formattedHK, "#", "Win+")
    formattedHK := StrReplace(formattedHK, "!", "Alt+")
    return formattedHK
}

ParseIniKeyValuePairs(lineStr) {
    if !lineStr
        return { Key: "", Val: "" }
    idx := InStr(lineStr, "=")
    if (idx > 0) {
        k := Trim(SubStr(lineStr, 1, idx - 1))
        v := Trim(SubStr(lineStr, idx + 1))
        return { Key: k, Val: v }
    }
    return { Key: "", Val: "" }
}

IsPlainIniKeySafe(text) {
    return !InStr(text, "=") && !InStr(text, "`r") && !InStr(text, "`n")
}

FixIniSpecialChars(k, v) {
    if (k == ">" && v == "=≥")
        return { Key: ">=", Val: "≥" }
    if (k == "<" && v == "=≤")
        return { Key: "<=", Val: "≤" }
    if (k == "!" && v == "=≠")
        return { Key: "!=", Val: "≠" }
    return { Key: k, Val: v }
}

; =================================================================================
; --- Translation Helpers ---
; =================================================================================

UriEncode(uri) {
    buf := Buffer(StrPut(uri, "UTF-8"))
    StrPut(uri, buf, "UTF-8")
    res := ""
    loop buf.Size - 1 {
        code := NumGet(buf, A_Index - 1, "UChar")
        if (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) || InStr("-._~", Chr(code))
            res .= Chr(code)
        else
            res .= Format("%{:02X}", code)
    }
    return res
}

GoogleTranslate(text, targetLang := "ko") {
    if (Trim(text) == "")
        return ""
    
    url := "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" . targetLang . "&dt=t"
    body := "q=" . UriEncode(text)
    
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("POST", url, true)
        req.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
        req.Send(body)
        req.WaitForResponse()
        res := req.ResponseText
        
        outText := ""
        
        ; Google JSON format for GTX starts with [[[
        if (SubStr(res, 1, 3) != "[[[")
            return text
            
        pos := 3
        len := StrLen(res)
        
        loop {
            if (SubStr(res, pos, 2) != '["')
                break
                
            textStart := pos + 2
            textEnd := _FindClosingQuote(res, textStart)
            if (!textEnd)
                break
                
            translatedPart := SubStr(res, textStart, textEnd - textStart)
            
            translatedPart := StrReplace(translatedPart, '\"', '"')
            translatedPart := StrReplace(translatedPart, '\\', '\')
            translatedPart := StrReplace(translatedPart, "\n", "`n")
            translatedPart := StrReplace(translatedPart, "\r", "`r")
            translatedPart := StrReplace(translatedPart, "\t", "`t")
            
            outText .= translatedPart
            
            ; State machine to safely skip the rest of this segment array
            bracketCount := 1
            scanPos := textEnd + 1
            
            while (scanPos <= len && bracketCount > 0) {
                ch := SubStr(res, scanPos, 1)
                
                if (ch == '"') {
                    scanPos := _FindClosingQuote(res, scanPos + 1)
                    if (!scanPos)
                        break 2
                    scanPos++
                    continue
                }
                
                if (ch == "[")
                    bracketCount++
                else if (ch == "]")
                    bracketCount--
                
                scanPos++
            }
            
            if (bracketCount > 0)
                break
                
            ; scanPos is at the character after the segment's closing bracket
            if (SubStr(res, scanPos, 2) == ",[") {
                pos := scanPos + 1
            } else {
                break
            }
        }
        
        return (outText != "") ? outText : text
    } catch {
        return text
    }
}

_FindClosingQuote(str, startPos) {
    pos := startPos
    len := StrLen(str)
    while (pos <= len) {
        ch := SubStr(str, pos, 1)
        if (ch == '\') {
            pos += 2  ; skip escaped character
            continue
        }
        if (ch == Chr(34))
            return pos
        pos++
    }
    return 0
}

; =================================================================================
; --- Window / UI Helpers ---
; =================================================================================

ShowCenteredOnMouse(guiObj, options := "") {
    guiObj.Show("Hide " . options)
    guiObj.GetPos(,, &gW, &gH)
    
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    
    monitorCount := MonitorGetCount()
    idx := MonitorGetPrimary()
    loop monitorCount {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (mX >= L && mX < R && mY >= T && mY < B) {
            idx := A_Index
            break
        }
    }
    
    ; Use WorkArea to avoid taskbar overlap
    MonitorGetWorkArea(idx, &WL, &WT, &WR, &WB)
    centeredPos := CalculateCenteredWindowPosition(gW, gH, WL, WT, WR, WB)
    
    ; WinMove uses physical screen coordinates regardless of DPIScale
    WinMove(centeredPos.X, centeredPos.Y, , , guiObj.Hwnd)
    guiObj.Show(options)
}

CalculateCenteredWindowPosition(guiWidth, guiHeight, workLeft, workTop, workRight, workBottom) {
    workWidth := Max(0, workRight - workLeft)
    workHeight := Max(0, workBottom - workTop)
    x := guiWidth >= workWidth ? workLeft : workLeft + (workWidth - guiWidth) // 2
    y := guiHeight >= workHeight ? workTop : workTop + (workHeight - guiHeight) // 2
    return { X: x, Y: y }
}

UpdateSaveButtonState(buttonCtrl, isDirty) {
    buttonCtrl.Text := isDirty
        ? "● Save && Apply (Unsaved)"
        : "💾 Save && Apply"
}
