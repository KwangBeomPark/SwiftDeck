#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName SwiftDeck
;@Ahk2Exe-SetVersion 1.1.1.0
;@Ahk2Exe-SetDescription SwiftDeck - FinOps Automation & HotKey Suite
;@Ahk2Exe-SetMainIcon ..\assets\SwiftDeck.ico

; =============================================================================
; SECTION: Global Configuration
; =============================================================================

; [Global] Display version shown in the app UI
global g_appVersion := "1.1.1"

; [Global] Path configuration (migrate legacy folder name)
if (DirExist(A_AppData . "\AHK_FolderHotKey") && !DirExist(A_AppData . "\SwiftDeck")) {
    try DirMove(A_AppData . "\AHK_FolderHotKey", A_AppData . "\SwiftDeck", 1)
}
global g_targetFolder := A_AppData . "\SwiftDeck\"

; [Global] Config file names
global g_fileName_Folder := "App02_01FavFolderSetting_v2_DoNotDelete.ini"
global g_fileName_Hotkey := "App02_02HotkeySetting_v2_DoNotDelete.ini"
global g_fileName_Hotstring := "App02_03HotstringSetting_DoNotDelete.ini"
global g_fileName_KeyRemap := "App02_04KeyRemap_DoNotDelete.ini"

; [Global] Full config file paths
global g_filePath_Folder := g_targetFolder . g_fileName_Folder
global g_filePath_Hotkey := g_targetFolder . g_fileName_Hotkey
global g_filePath_Hotstring := g_targetFolder . g_fileName_Hotstring
global g_filePath_KeyRemap := g_targetFolder . g_fileName_KeyRemap

; [Global] Runtime state
global g_registeredHotstrings := []
global g_registeredKeyRemaps := Map()

GetAppAssetPath(fileName) {
    candidates := [
        A_ScriptDir . "\assets\" . fileName,
        A_ScriptDir . "\..\assets\" . fileName,
        A_ScriptDir . "\" . fileName
    ]

    for candidate in candidates {
        if FileExist(candidate)
            return candidate
    }
    return A_ScriptDir . "\assets\" . fileName
}

; =============================================================================
; SECTION: Tray Icon
; =============================================================================
appIconPath := GetAppAssetPath("SwiftDeck.ico")
if FileExist(appIconPath) {
    TraySetIcon(appIconPath)
}

; =============================================================================
; SECTION: Script Configuration (Includes & Global Variables)
; =============================================================================

#Include lib\Theme.ahk
#Include lib\Utils.ahk
#Include lib\Clipboard.ahk
#Include lib\Config.ahk
#Include lib\Migration.ahk
#Include lib\FolderMenu.ahk
#Include lib\FolderManager.ahk
#Include lib\PreferencesManager.ahk
#Include lib\PromptManager.ahk
#Include lib\PromptMenu.ahk
#Include lib\HotstringManager.ahk
#Include lib\KeyRemapManager.ahk
#Include lib\EmojiPicker.ahk
#Include lib\DashboardManager.ahk
#Include lib\AppInfo.ahk
#Include lib\Manual.ahk

; =============================================================================
; SECTION: Application Startup
; =============================================================================
OnStartup() ; Invoked immediately on script start

OnStartup() {
    isFirstRun := ConfigIsFirstRun()

    InitializeAllConfigs()

    ; Run config migrations
    MigrateIniEncoding()
    MigrateHotstringIni()

    ; Normalize old hotkey settings such as "WinNumpad"
    settings := ConfigReadAppSettings()
    migratedPrompt := MigratePromptModifier(settings.PromptModifier, settings.PromptUseNumpad)
    settings.PromptModifier := migratedPrompt.Mod
    settings.PromptUseNumpad := migratedPrompt.UseNumpad

    ; Auto-backup existing config files (.bak)
    BackupConfigs()

    ; Load runtime input automation features
    LoadHotstrings()
    BuildEmojiMenu()
    LoadKeyRemaps()
    OnExit(CleanupKeyRemaps)

    ; Register dynamic hotkey (main menu)
    try {
        Hotkey(settings.MainHotkey, (*) => ShowFavoritesMenu())
    } catch {
        settings.MainHotkey := "F1"
        Hotkey("F1", (*) => ShowFavoritesMenu())
    }

    ; Register dynamic prompt hotkeys
    if (settings.PromptModifier != "") {
        loop 10 {
            num := A_Index - 1
            baseKey := settings.PromptUseNumpad ? "Numpad" . num : num
            hk := settings.PromptModifier . baseKey
            try Hotkey(hk, BindPrompt(num))
        }
    }

    ; Register Emoji Picker, Prompt Menu, and Exit hotkeys
    try Hotkey(settings.EmojiHotkey, (*) => g_emojiMenu.Show())
    try Hotkey("+#Space", (*) => ShowPromptMenu())  ; Shift+Win+Space → Prompt Popup Menu
    try Hotkey(settings.ExitHotkey, (*) => ExitApp())

    ; Register dynamic "Add Current Explorer Folder" hotkey (Ctrl + mainHotkey)
    addFolderHotkey := "^" . settings.MainHotkey
    HotIf((*) => GetActiveExplorerPath() != "")
    try {
        Hotkey(addFolderHotkey, (*) => AddCurrentExplorerFolder())
    } catch {
        Hotkey("^F1", (*) => AddCurrentExplorerFolder())
    }
    HotIf() ; Reset context to default (global)

    ; Setup custom tray menu
    SetupTrayMenu(settings.MainHotkey)

    ; Show welcome screen (manual) on first run
    if (isFirstRun) {
        SetTimer(() => OpenAppManual("EN"), -1000) ; Show manual after 1 second
    }

    ; Show startup notification (TrayTip)
    formattedHK := FormatHotkeyDisplay(settings.MainHotkey)
    TrayTip("App is running in the background.`nPress [" . formattedHK . "] anytime to open the menu!",
        "✅ SwiftDeck Ready",
        "Iconi")
    SetTimer(() => TrayTip(), -4000) ; Hide notification after 4 seconds
}

BindPrompt(num) {
    return (*) => PromptManager.ProcessQuickPrompt(num)
}

SetupTrayMenu(hotkeyLabel := "F1") {
    A_TrayMenu.Delete() ; Remove default AHK tray items (Open, Pause, Exit, etc.)

    formattedHK := FormatHotkeyDisplay(hotkeyLabel)

    A_TrayMenu.Add("📂 Open Folders Menu (" . formattedHK . ")", (*) => ShowFavoritesMenu())
    A_TrayMenu.Add()
    A_TrayMenu.Add("⚙️ App Settings", (*) => DashboardManager.Show(1))
    A_TrayMenu.Add("📁 Open Settings Folder", (*) => RunSafely("explorer.exe `"" . ConfigGetSettingsFolder() . "`"", "Open Settings Folder"))
    A_TrayMenu.Add("📘 Open App Manual", (*) => OpenAppManual("EN"))
    A_TrayMenu.Add("ℹ️ App Information", (*) => ShowAppInformation())
    A_TrayMenu.Add()
    A_TrayMenu.Add("🔄 Reload App", (*) => Reload())
    A_TrayMenu.Add("❌ Exit App", (*) => ExitApp())

    ; Double-click tray icon to open favorites menu
    A_TrayMenu.Default := "📂 Open Folders Menu (" . formattedHK . ")"
}
