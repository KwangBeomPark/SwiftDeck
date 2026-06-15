#Requires AutoHotkey v2.0

; =================================================================================
; Module: Theme
; Description: Application-wide UI styling constants and Dark Mode enablers.
; Author: KBPark
; =================================================================================
; =================================================================================
; --- GUI Utilities and Theme ---
; =================================================================================

; --- Theme Constants ---
global THEME_BG := "1E1E1E"
global THEME_PANEL := "2D2D30"
global THEME_ACCENT := "007ACC"
global THEME_TEXT := "FFFFFF"
global THEME_MUTED := "A0A0A0"

EnableDarkMode(hGui) {
    attr := 19
    if (VerCompare(A_OSVersion, "10.0.22000") >= 0)
        attr := 20
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hGui.Hwnd, "int", attr, "int*", 1, "int", 4)
}

ApplyTheme(guiObj, headerTitle := "", headerDesc := "") {
    EnableDarkMode(guiObj)
    guiObj.BackColor := THEME_BG
    
    if (headerTitle != "") {
        guiObj.SetFont("s14 c" . THEME_TEXT . " bold", "Segoe UI")
        guiObj.Add("Text", "x20 y15 w420 h25 BackgroundTrans", headerTitle)
        
        if (headerDesc != "") {
            guiObj.SetFont("s9 c" . THEME_MUTED . " norm", "Segoe UI")
            guiObj.Add("Text", "x20 y40 w420 h20 BackgroundTrans", headerDesc)
        }
    }
    
    guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")
}
