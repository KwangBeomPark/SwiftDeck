#Requires AutoHotkey v2.0
#Include Theme.ahk
#Include FolderManager.ahk
#Include PromptManager.ahk
#Include HotstringManager.ahk
#Include KeyRemapManager.ahk
#Include PreferencesManager.ahk
#Include AppInfo.ahk
#Include Manual.ahk
; Runtime global g_appVersion is initialized in SwiftDeck.ahk before this module is included.

; =================================================================================
; Module: DashboardManager
; Description: The main unified settings window hosting all feature configuration tabs.
; Author: KBPark
; =================================================================================
class DashboardManager {
    static instance := ""

    static Show(tabIndex := 1) {
        if (!DashboardManager.instance) {
            DashboardManager.instance := DashboardManager()
        }
        DashboardManager.instance.ShowGui(tabIndex)
    }

    __New() {
        this.hGui := Gui("+AlwaysOnTop +OwnDialogs", "SwiftDeck App Settings")
        ApplyTheme(this.hGui, "SwiftDeck", "v" . g_appVersion . " | FinOps Automation && HotKey Suite")
        this.hGui.OnEvent("Close", ObjBindMethod(this, "HandleClose"))

        ; Add top-right global buttons (Manual & Info)
        this.hGui.SetFont("s9 cCCCCCC norm", "Segoe UI")
        btnGlobalManual := this.hGui.Add("Button", "x310 y20 w80 h28", "📘 Manual")
        btnGlobalManual.OnEvent("Click", (*) => OpenAppManual("EN", this.hGui.Hwnd))

        btnGlobalInfo := this.hGui.Add("Button", "x395 y20 w85 h28", "ℹ️ App Info")
        btnGlobalInfo.OnEvent("Click", (*) => ShowAppInformation(this.hGui.Hwnd))
        this.hGui.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        ; Create Tab Control
        this.mainTab := this.hGui.Add("Tab3", "x20 y75 w460 h465", ["📁 Folders", "⌨️ Prompts", "✏️ Hotstrings", "🔀 Key Remap", "⚙️ General"])

        this.mainTab.UseTab(1)
        this.folderMgr := FolderManager(this.hGui)
        this.folderMgr.dashboardResetHandler := ObjBindMethod(this, "RequestResetToDefaults")

        this.mainTab.UseTab(2)
        this.promptMgr := PromptManager(this.hGui)
        this.promptMgr.dashboardResetHandler := ObjBindMethod(this, "RequestResetToDefaults")

        this.mainTab.UseTab(3)
        this.hotstringMgr := HotstringManager(this.hGui)
        this.hotstringMgr.dashboardResetHandler := ObjBindMethod(this, "RequestResetToDefaults")

        this.mainTab.UseTab(4)
        this.keyRemapMgr := KeyRemapManager(this.hGui)
        this.keyRemapMgr.dashboardResetHandler := ObjBindMethod(this, "RequestResetToDefaults")

        this.mainTab.UseTab(5)
        this.prefMgr := PreferencesManager(this.hGui)

        this.mainTab.UseTab()
        this.mainTab.OnEvent("Change", (*) => this.OnTabChange())
    }

    OnTabChange() {
        tabIndex := this.mainTab.Value
        if (tabIndex == 1) {
            this.folderMgr.RefreshList()
        } else if (tabIndex == 2) {
            this.promptMgr.RefreshList()
        } else if (tabIndex == 3) {
            this.hotstringMgr.RefreshList()
        } else if (tabIndex == 4) {
            this.keyRemapMgr.RefreshList()
        }
    }

    ShowGui(tabIndex) {
        this.mainTab.Choose(tabIndex)
        ShowCenteredOnMouse(this.hGui)
    }

    HasUnsavedChanges() {
        return this.folderMgr.IsDirty()
            || this.promptMgr.IsDirty()
            || this.hotstringMgr.IsDirty()
            || this.keyRemapMgr.IsDirty()
            || this.prefMgr.IsDirty()
    }

    SaveAllChanges(reloadForGeneral := true, showFeedback := true) {
        generalWasDirty := this.prefMgr.IsDirty()
        try {
            if (generalWasDirty && !this.prefMgr.TrySavePreferences(false, false))
                return false
            if (this.folderMgr.IsDirty())
                this.folderMgr.SaveSettings(false)
            if (this.promptMgr.IsDirty())
                this.promptMgr.SaveSettings(false)
            if (this.hotstringMgr.IsDirty())
                this.hotstringMgr.SaveSettings(false)
            if (this.keyRemapMgr.IsDirty())
                this.keyRemapMgr.SaveSettings(false)
        } catch Error as err {
            MsgBox("❌ Could not save all settings.`n`nError: " . err.Message, "Save Failed", 262160)
            return false
        }

        if (generalWasDirty && reloadForGeneral) {
            MsgBox("✅ All changes were saved. The app will now reload to apply the new hotkeys.", "Saved", 262208)
            Reload()
            return true
        }

        if (showFeedback) {
            ToolTip("✅ All changes saved")
            SetTimer(() => ToolTip(), -2000)
        }
        return true
    }

    DiscardChanges() {
        this.hGui.Destroy()
        DashboardManager.instance := ""
    }

    RequestResetToDefaults(target) {
        if this.HasUnsavedChanges() {
            targetLabel := target == "All" ? "all settings" : target
            msg := "⚠️ You have unsaved dashboard changes.`n`n"
                . "Resetting " . targetLabel . " will discard them if you confirm the reset in the next step.`n"
                . "Choose No to return and save first.`n`nContinue to Reset?"
            if (MsgBox(msg, "Unsaved Changes", 262452) != "Yes")
                return false
        }
        ResetToDefaults(target)
        return true
    }

    ConfirmUnsavedChanges(actionName := "close") {
        if !this.HasUnsavedChanges()
            return true

        msg := "You have unsaved changes.`n`n"
            . "Yes  = Save All`n"
            . "No   = Discard changes`n"
            . "Cancel = Keep editing"
        result := MsgBox(msg, "Unsaved Changes", 262195)

        if (result == "Yes")
            return this.SaveAllChanges(actionName == "close", actionName != "exit")
        if (result == "No") {
            this.DiscardChanges()
            return true
        }
        return false
    }

    HandleClose(*) {
        if !this.HasUnsavedChanges() {
            this.hGui.Hide()
            return true
        }

        if !this.ConfirmUnsavedChanges("close")
            return true
        if (DashboardManager.instance)
            this.hGui.Hide()
        return true
    }
}
