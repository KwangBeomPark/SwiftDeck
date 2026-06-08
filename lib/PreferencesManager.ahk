#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Theme.ahk
#Include Utils.ahk
#Include Migration.ahk

; =================================================================================
; Module: PreferencesManager
; Description: Manages application-wide settings and custom hotkey bindings.
; Author: KBPark (Financial Specialist)
; =================================================================================
class PreferencesManager {
    __New(parentGui := "") {
        this.parentGui := parentGui
        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.pGui := Gui("+AlwaysOnTop", "🔧 Preferences")
            ApplyTheme(this.pGui, "Preferences", "Configure basic app settings and hotkeys.")
            this.BuildUI(this.pGui)
            this.pGui.Show("AutoSize")
        }
    }

    BuildUI(guiObj) {
        ; Standalone window starts lower (header takes space)
        startX := this.parentGui ? 35 : 25
        startY := this.parentGui ? 115 : 80

        guiObj.SetFont("s10 c" . THEME_TEXT, "Segoe UI")

        settings := ConfigReadAppSettings()
        mainHotkey := settings.MainHotkey
        promptMod := settings.PromptModifier
        promptUseNumpad := settings.PromptUseNumpad

        migrated := MigratePromptModifier(promptMod, promptUseNumpad)
        promptMod := migrated.Mod
        promptUseNumpad := migrated.UseNumpad

        mainParsed := ParseKeyString(mainHotkey)
        promptParsed := ParseKeyString(promptMod)

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
        btnSave := guiObj.Add("Text", "x" . startX . " y" . (startY + 230) . " w410 h40 Center +0x200 +Border Background4A4F54", "💾 Save & Apply")
        btnSave.OnEvent("Click", ObjBindMethod(this, "SavePreferences"))
        guiObj.SetFont("c" . THEME_TEXT . " norm", "Segoe UI")

        ; --- Advanced Options ---
        guiObj.Add("GroupBox", "x" . startX . " y" . (startY + 295) . " w410 h75", "Advanced Options")

        guiObj.SetFont("s9 cD03A3A bold", "Segoe UI")
        btnResetAll := guiObj.Add("Text", "x" . (startX + 15) . " y" . (startY + 320) . " w380 h30 Center +0x200 +Border Background2D2D30", "⚠️ FACTORY RESET ALL SETTINGS")
        btnResetAll.OnEvent("Click", (*) => ResetToDefaults("All"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
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

        newHotkey := BuildKeyString(this.chkMainCtrl.Value, this.chkMainShift.Value, this.chkMainWin.Value, this.chkMainAlt.Value, mainBase)
        newModVal := BuildKeyString(this.chkPromptCtrl.Value, this.chkPromptShift.Value, this.chkPromptWin.Value, this.chkPromptAlt.Value, "")
        newUseNumpad := (this.ddlPromptNumpad.Value == 1) ? 1 : 0

        if (newModVal == "") {
            MsgBox("⚠️ Please select at least one Quick Prompts modifier key.`n`nExample: Win + Numpad 1", "Invalid Hotkey", 262160)
            return
        }

        ConfigWriteAppSettings(newHotkey, newModVal, newUseNumpad)

        if (!this.parentGui)
            this.pGui.Destroy()
        MsgBox("✅ Settings saved successfully! The app will now reload.", "Success", 262208)
        Reload()
    }
}
