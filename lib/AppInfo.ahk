#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Theme.ahk
#Include FolderManager.ahk
; Runtime global g_appVersion is initialized in SwiftDeck.ahk before this module is included.

; =================================================================================
; Module: AppInfo
; Description: Displays system diagnostic information and maintenance tools.
; Author: KBPark (Financial Specialist)
; =================================================================================
ShowAppInformation(parentHwnd := 0) {
    global g_appVersion

    bmcBtnPath := A_ScriptDir . "\bmc_button.png"
    if !FileExist(bmcBtnPath) {
        try {
            Download("https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png", bmcBtnPath)
        }
    }
    settingsFolder := ConfigGetSettingsFolder()
    favoriteConfigPath := GetConfigPath("Folders")
    promptConfigPath := GetConfigPath("Prompts")
    hotstringConfigPath := GetConfigPath("Hotstrings")

    if (parentHwnd) {
        WinSetEnabled(0, parentHwnd)
    }

    infoGui := Gui("+AlwaysOnTop +Owner" . parentHwnd . " -MinimizeBox -MaximizeBox", "ℹ️ App Information & Support")
    ApplyTheme(infoGui, "", "") ; No header text from Theme

    ; Developer Info Title
    infoGui.SetFont("s10 bold c" . THEME_TEXT, "Segoe UI")
    infoGui.Add("Text", "x20 y15 w350 h25 BackgroundTrans", "👤 Developer: Kwang Beom Park (Financial Manager)")

    ; Developer Description
    infoGui.SetFont("s9 norm c" . THEME_MUTED, "Segoe UI")
    infoGui.Add("Text", "x20 y40 w350 h60 BackgroundTrans", "A finance professional passionate about office automation and daily productivity.`n👉 Click the GitHub icon on the right to view other office apps!")

    if FileExist(A_ScriptDir . "\github_icon.png") {
        picGithub := infoGui.Add("Picture", "x380 y15 w80 h80 BackgroundTrans", A_ScriptDir . "\github_icon.png")
        picGithub.OnEvent("Click", (*) => RunSafely("https://github.com/KwangBeomPark", "Open GitHub"))
    }
    infoGui.SetFont("s10 norm c" . THEME_TEXT, "Segoe UI")

    CleanUpAndClose() {
        if (parentHwnd) {
            WinSetEnabled(1, parentHwnd)
            WinActivate("ahk_id " . parentHwnd)
        }
        infoGui.Destroy()
    }
    infoGui.OnEvent("Close", (*) => CleanUpAndClose())

    ; Gather statistics
    folderCount := FolderManager.ReadFolderItems().Length
    hsSpaceCount := 0
    hsMenuCount := 0
    if ConfigExists("Hotstrings") {
        hsCounts := ConfigCountHotstrings()
        hsSpaceCount := hsCounts.Space
        hsMenuCount := hsCounts.Menu
    }
    hsTotal := hsSpaceCount + hsMenuCount

    promptCount := 0
    if ConfigExists("Prompts") {
        loop 10 {
            promptCount += ConfigCountPairs("Prompts", "Numpad" . (A_Index - 1))
        }
    }

    remapCount := 0
    if ConfigExists("KeyRemaps")
        remapCount := ConfigCountPairs("KeyRemaps", "Remaps")

    ; 1. Stats Panel (Left)
    infoGui.Add("GroupBox", "x20 y110 w210 h190 c" . THEME_ACCENT, "📊 System Statistics")
    infoGui.Add("Text", "x35 y135 w180", "📁 Favorites: " . folderCount . " registered")
    infoGui.Add("Text", "x35 y155 w180", "⌨️ Prompts: " . promptCount . " total")
    infoGui.Add("Text", "x35 y175 w180", "✏️ Hotstrings: " . hsTotal . " total")
    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x45 y195 w170", "(Auto: " . hsSpaceCount . " / Menu: " . hsMenuCount . ")")
    infoGui.SetFont("s10 c" . THEME_TEXT)
    infoGui.Add("Text", "x35 y245 w180", "🔀 Key Remaps: " . remapCount . " total")

    ; 2. Maintenance Tools (Right)
    infoGui.Add("GroupBox", "x245 y110 w215 h190 c" . THEME_ACCENT, "🛠️ Maintenance Tools")

    btnAppFolder := infoGui.Add("Button", "x260 y145 w185 h30", "📂 Open App Folder")
    btnAppFolder.OnEvent("Click", (*) => RunSafely("explorer.exe `"" . settingsFolder . "`"", "Open App Folder"))

    btnBackup := infoGui.Add("Button", "x260 y190 w90 h30", "📥 Backup")
    btnBackup.OnEvent("Click", (*) => BackupConfigs(true))

    btnRestore := infoGui.Add("Button", "x355 y190 w90 h30", "🔄 Restore")
    btnRestore.OnEvent("Click", (*) => RestoreConfigs())

    isStartupEnabled := FileExist(A_Startup . "\SwiftDeck.lnk") || FileExist(A_Startup . "\FolderHotKey.lnk")
    chkStartup := infoGui.Add("CheckBox", "x260 y240 w185 h35 Checked" . (isStartupEnabled ? 1 : 0), "🚀 Run app when Windows starts")
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
                MsgBox("🚀 Auto-Start has been successfully enabled!`nApp will now run automatically on Windows boot.", "Startup Registration", 262208)
            } else {
                throw Error("Shortcut creation verified but file is missing.")
            }
        } catch Error as err {
            MsgBox("❌ Failed to enable Auto-Start.`n`nError: " . err.Message, "Startup Error", 262160)
        }
    }

    UnregisterStartup() {
        if FileExist(A_Startup . "\FolderHotKey.lnk")
            try FileDelete(A_Startup . "\FolderHotKey.lnk")

        startupLnk := A_Startup . "\SwiftDeck.lnk"
        try {
            if FileExist(startupLnk) {
                FileDelete(startupLnk)
                MsgBox("🗑️ Auto-Start has been successfully disabled.`nShortcut removed from Startup folder.", "Startup Unregistration", 262208)
            } else {
                MsgBox("ℹ️ Auto-Start is already disabled.`nNo shortcut found in the Startup folder.", "Startup Status", 262192)
            }
        } catch Error as err {
            MsgBox("❌ Failed to disable Auto-Start.`n`nError: " . err.Message, "Startup Error", 262160)
        }
    }

    ; 3. File Paths Section (Bottom)
    infoGui.Add("GroupBox", "x20 y310 w440 h155 c" . THEME_ACCENT, "📂 Configuration File Paths")

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y335 w410", "Favorites Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y353 w345 h22 ReadOnly Background2D2D30 -Border", favoriteConfigPath)
    btnOpenFavFile := infoGui.Add("Button", "x390 y351 w55 h24", "Open")
    btnOpenFavFile.OnEvent("Click", (*) => RunSafely("notepad.exe `"" . favoriteConfigPath . "`"", "Open Config File"))

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y378 w410", "Quick Prompts Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y396 w345 h22 ReadOnly Background2D2D30 -Border", promptConfigPath)
    btnOpenPrFile := infoGui.Add("Button", "x390 y394 w55 h24", "Open")
    btnOpenPrFile.OnEvent("Click", (*) => RunSafely("notepad.exe `"" . promptConfigPath . "`"", "Open Config File"))

    infoGui.SetFont("s9 c" . THEME_MUTED)
    infoGui.Add("Text", "x35 y421 w410", "Hotstrings Config:")
    infoGui.SetFont("s9 c" . THEME_TEXT)
    infoGui.Add("Edit", "x35 y439 w345 h22 ReadOnly Background2D2D30 -Border", hotstringConfigPath)
    btnOpenHsFile := infoGui.Add("Button", "x390 y437 w55 h24", "Open")
    btnOpenHsFile.OnEvent("Click", (*) => RunSafely("notepad.exe `"" . hotstringConfigPath . "`"", "Open Config File"))
    infoGui.SetFont("s10 c" . THEME_TEXT)

    ; 4. Support Developer Section (Very Bottom)
    infoGui.Add("GroupBox", "x20 y475 w440 h115 c" . THEME_ACCENT, "☕ Support the Developer")
    infoGui.Add("Text", "x35 y497 w410", "If this tool helps your daily workflow, consider buying a coffee!")

    if FileExist(bmcBtnPath) {
        picCoffee := infoGui.Add("Picture", "x130 y520 w217 h60 BackgroundTrans", bmcBtnPath)
        picCoffee.OnEvent("Click", (*) => RunSafely("https://www.buymeacoffee.com/KBPark_Bob", "Open Support Page"))
    } else {
        infoGui.SetFont("s11 cBlack bold", "Segoe UI")
        btnCoffee := infoGui.Add("Text", "x130 y525 w220 h45 Center +0x200 +Border BackgroundFF813F", "☕ Buy Me a Coffee")
        btnCoffee.OnEvent("Click", (*) => RunSafely("https://www.buymeacoffee.com/KBPark_Bob", "Open Support Page"))
        infoGui.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
    }

    btnClose := infoGui.Add("Button", "x180 y605 w120 h35 Default", "Close")
    btnClose.OnEvent("Click", (*) => CleanUpAndClose())

    infoGui.Show("w480 h655")
}
