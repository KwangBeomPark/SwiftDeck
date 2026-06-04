#Requires AutoHotkey v2.0
;@disable-check undeclared
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
        Run('explorer.exe /select,"' folderPath '"')
        return
    }

    if !DirExist(folderPath) {
        MsgBox "The specified folder does not exist.`n`n" folderPath, "Error", 262192
        return
    }

    Run('explorer.exe "' folderPath '"')
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

FormatHotkeyDisplay(hotkeyLabel) {
    formattedHK := hotkeyLabel
    formattedHK := StrReplace(formattedHK, "^", "Ctrl+")
    formattedHK := StrReplace(formattedHK, "+", "Shift+")
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

FixIniSpecialChars(k, v) {
    if (k == ">" && v == "=≥")
        return { Key: ">=", Val: "≥" }
    if (k == "<" && v == "=≤")
        return { Key: "<=", Val: "≤" }
    if (k == "!" && v == "=≠")
        return { Key: "!=", Val: "≠" }
    return { Key: k, Val: v }
}

