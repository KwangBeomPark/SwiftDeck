#Requires AutoHotkey v2.0
#Include Config.ahk
; =============================================================================
; --- Configuration Migration Utilities ---
; =============================================================================

MigratePromptModifier(modVal, useNumpadVal) {
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
    if !ConfigExists("Hotstrings")
        return

    schemaVer := "1"
    try schemaVer := ConfigReadValue("Hotstrings", "Meta", "SchemaVersion", "1")

    if (schemaVer == "4")
        return

    hotstringData := ConfigReadHotstringData()
    ConfigWriteHotstringData(hotstringData.Data, hotstringData.GroupOrder)
}

MigrateIniEncoding() {
    for fileDef in ConfigGetManagedFiles() {
        path := fileDef.Path
        if !FileExist(path)
            continue
            
        try {
            fileObj := FileOpen(path, "r")
            enc := fileObj.Encoding
            fileObj.Close()
            
            if (enc != "UTF-16") {
                content := FileRead(path, "UTF-8")
                ConfigWriteTextFileSafely(path, content, "UTF-16")
            }
        }
    }
}
