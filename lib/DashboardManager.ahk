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
; Author: KBPark (Financial Specialist)
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
        this.hGui := Gui("+AlwaysOnTop", "SwiftDeck App Settings")
        ApplyTheme(this.hGui, "SwiftDeck", "v" . g_appVersion . " | FinOps Automation & HotKey Suite")
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
        this.hGui.Show()
    }
}
