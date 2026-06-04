#Requires AutoHotkey v2.0
;@disable-check undeclared
; =============================================================================
; --- Configuration Migration Utilities ---
; =============================================================================

MigratePromptModifier(modVal, useNumpadVal) {
    global g_filePath_Folder

    migrated := false

    if (modVal == "1") {
        modVal := "#"
        migrated := true
    } else if (modVal == "2") {
        modVal := "^"
        migrated := true
    } else if (modVal == "3") {
        modVal := "!"
        migrated := true
    } else if (modVal == "4") {
        modVal := "+#"
        migrated := true
    } else if (modVal == "5") {
        modVal := "+^"
        migrated := true
    } else if (modVal == "6") {
        modVal := "+!"
        migrated := true
    } else if (modVal == "7") {
        modVal := "^#"
        migrated := true
    } else if (modVal == "8") {
        modVal := "!#"
        migrated := true
    } else if (modVal == "9") {
        modVal := "^!"
        migrated := true
    } else if (modVal == "WinNumpad") {
        modVal := "#"
        useNumpadVal := 1
        migrated := true
    }

    if (migrated) {
        ConfigWriteValue("Settings", "Settings", "PromptModifier", modVal)
        ConfigWriteValue("Settings", "Settings", "PromptUseNumpad", useNumpadVal)
    }

    return { Mod: modVal, UseNumpad: useNumpadVal }
}

MigrateHotstringIni() {
    global g_filePath_Hotstring
    if !FileExist(g_filePath_Hotstring)
        return

    schemaVer := "1"
    try schemaVer := ConfigReadValue("Hotstrings", "Meta", "SchemaVersion", "1")

    if (schemaVer == "3")
        return

    ; v1 → v2: Migrate Group_* to Group_Auto_*
    if (schemaVer == "1") {
        sections := ""
        try sections := ConfigReadSections("Hotstrings")
        if (sections != "") {
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (secName == "" || secName == "Meta")
                    continue

                if (SubStr(secName, 1, 6) == "Group_") {
                    if (SubStr(secName, 1, 11) == "Group_Auto_" || SubStr(secName, 1, 12) == "Group_Space_" || SubStr(secName, 1, 11) == "Group_Menu_") {
                        continue
                    }

                    groupName := SubStr(secName, 7)
                    newSecName := "Group_Auto_" . groupName

                    content := ""
                    try content := ConfigReadSection("Hotstrings", secName, "")
                    if (content != "") {
                        ConfigWriteSection("Hotstrings", newSecName, content)
                    }
                    ConfigDeleteSection("Hotstrings", secName)
                }
            }
        }
        ConfigWriteValue("Hotstrings", "Meta", "SchemaVersion", "2")
        schemaVer := "2"

        autoContent := ""
        try autoContent := ConfigReadSection("Hotstrings", "Group_Auto_Default", "")
        merged := ""
        if (autoContent != "")
            merged .= autoContent

        if (merged != "")
            ConfigWriteSection("Hotstrings", "Group_Space_Default", merged)
        return
    }

    ; v2 → v3: Merge Group_Auto_* into Group_Space_*
    if (schemaVer == "2") {
        sections := ""
        try sections := ConfigReadSections("Hotstrings")
        if (sections != "") {
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (SubStr(secName, 1, 11) != "Group_Auto_")
                    continue

                groupName := SubStr(secName, 12)
                spaceSec := "Group_Space_" . groupName

                autoContent := ""
                try autoContent := ConfigReadSection("Hotstrings", secName, "")
                if (autoContent != "") {
                    existingSpace := ""
                    try existingSpace := ConfigReadSection("Hotstrings", spaceSec, "")
                    merged := ""
                    if (existingSpace != "")
                        merged := existingSpace . "`n"
                    merged .= autoContent
                    ConfigWriteSection("Hotstrings", spaceSec, Trim(merged, "`n"))
                }
                ConfigDeleteSection("Hotstrings", secName)
            }
        }
        ConfigWriteValue("Hotstrings", "Meta", "SchemaVersion", "3")
    }
}
