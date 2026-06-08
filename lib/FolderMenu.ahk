#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Utils.ahk
#Include FolderManager.ahk
#Include DashboardManager.ahk
; g_FolderMenuCache is owned by this module.

; =================================================================================
; Module: FolderMenu
; Description: Core logic for displaying and managing the popup Favorites menu.
; Author: KBPark (Financial Specialist)
; =================================================================================
; =================================================================================
; --- Folder Menu System ---
; =================================================================================

; Global cache store (for top-level and 1st-level folder menus)
global g_FolderMenuCache := Map()

ShowFavoritesMenu() {
    if !ConfigExists("Folders") {
        MsgBox("⚠️ Cannot find the setting file.", "Error", 262160)
        return
    }

    folderItems := FolderManager.ReadFolderItems()

    ; --- Loading indicator while scanning folders (hidden instantly on cache hit) ---
    loadGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    loadGui.SetFont("s12", "Segoe UI")
    loadGui.Add("Text", "w280 Center", "📂 Loading folders...")
    loadGui.Show("xCenter yCenter NoActivate")

    mainContextMenu := Menu()
    for idx, obj in folderItems {
        rootFolderPath := obj.Path
        rootFolderName := obj.Name
        if rootFolderPath == "A_Startup"
            rootFolderPath := A_Startup

        if rootFolderName == "-" {
            mainContextMenu.Add()
            continue
        }
        mainContextMenu.Add(rootFolderName, BuildFolderSubmenu(rootFolderPath, rootFolderName))
    }

    loadGui.Destroy()  ; Scan complete → remove loading indicator

    mainContextMenu.Add()

    ; Add current folder and settings entry
    mainHotkeyStr := ConfigReadAppSettings().MainHotkey
    
    friendlyMainHotkey := FormatHotkeyDisplay(mainHotkeyStr)
    addFolderMenuText := "⭐ Add Current Folder  [Ctrl+" . friendlyMainHotkey . "]"

    mainContextMenu.Add(addFolderMenuText, (*) => AddCurrentExplorerFolder())
    if (GetActiveExplorerPath() == "") {
        mainContextMenu.Disable(addFolderMenuText)
    }
    mainContextMenu.Add("⚙️ App Settings", (*) => DashboardManager.Show(1))

    mainContextMenu.Show()
    return
}

AddCurrentExplorerFolder() {
    explorerPath := GetActiveExplorerPath()
    if (explorerPath == "") {
        MsgBox("⚠️ No Explorer window found. Please open Explorer and try again.", "Info", 262208)
        return
    }

    if (DashboardManager.instance)
        DashboardManager.instance.hGui.Opt("+OwnDialogs")
    ib := InputBox("Enter a nickname for this folder:`nPath: " . explorerPath, "Add Folder", "w350 h150", GetFileName(explorerPath))
    if (ib.Result != "OK" || Trim(ib.Value) == "")
        return

    DashboardManager.Show(1)
    if DashboardManager.instance.folderMgr.AddFolderItem(ib.Value, explorerPath) {
        ToolTip("✅ Added. Click Save & Apply.")
        SetTimer(() => ToolTip(), -2000)
    }
}

GetActiveExplorerPath() {
    hwnd := WinExist("A")
    if (!hwnd)
        return ""

    try {
        winClass := WinGetClass(hwnd)
    } catch {
        return ""
    }

    if !(winClass ~= "(Progman|WorkerW|CabinetWClass|ExploreWClass)")
        return ""

    for window in ComObject("Shell.Application").Windows {
        if (window.HWND != hwnd)
            continue
        try {
            path := window.Document.Folder.Self.Path
            return path
        }
    }
    return ""
}

GetFolderTreeHash(rootPath) {
    hashStr := ""
    try {
        hashStr := FileGetTime(rootPath, "M")
    } catch {
        return "ERROR"
    }
    
    loop files AddTrailingBackslash(rootPath) . "*", "D" {
        if InStr(A_LoopFileAttrib, "H")
            continue
        try hashStr .= "|" . A_LoopFileTimeModified
    }
    return hashStr
}

BuildFolderSubmenu(rootPath, rootLabel) {
    global g_FolderMenuCache
    maxLv1 := 30  ; Max Level-1 subfolders to display
    maxLv2 := 20  ; Max Level-2 subfolders to display

    ; Show warning menu item if folder doesn't exist or drive is disconnected
    if !FileExist(rootPath) || !InStr(FileExist(rootPath), "D") {
        MenuLv0 := Menu()
        MenuLv0.Add("No Folder Exist: " . rootPath, ShowFolderWarningMsg.Bind())
        return MenuLv0
    }

    ; [Cache Logic Start]
    ; Extract modification time hash (very fast — reads only 1 level even on network drives)
    currentHash := GetFolderTreeHash(rootPath)
    
    ; Cache check
    if (g_FolderMenuCache.Has(rootPath)) {
        cacheObj := g_FolderMenuCache[rootPath]
        if (cacheObj.Hash == currentHash) {
            return cacheObj.Menu
        }
    }
    ; [Cache Logic End]

    menuLv1 := Menu()
    menuLv1.Add("Open " . rootLabel, OpenFolder.Bind(rootPath))
    menuLv1.Add()

    cntLv1 := 0
    for childPath in GetFoldersList(AddTrailingBackslash(rootPath) . "*", "D") {
        cntLv1++
        if (cntLv1 > maxLv1) {
            menuLv1.Add("... (" . (cntLv1 - 1) . "+ more folders)", OpenFolder.Bind(rootPath))
            break
        }
        childLabel := GetLastFolderName(childPath)
        if !childLabel
            continue

        menuLv2 := Menu()
        menuLv2.Add("Open " . childLabel, OpenFolder.Bind(childPath))
        menuLv2.Add()

        cntLv2 := 0
        for grandchildPath in GetFoldersList(AddTrailingBackslash(childPath) . "*", "D") {
            cntLv2++
            if (cntLv2 > maxLv2) {
                menuLv2.Add("... (" . (cntLv2 - 1) . "+ more folders)", OpenFolder.Bind(childPath))
                break
            }
            grandchildLabel := GetLastFolderName(grandchildPath)
            if !grandchildLabel
                continue
            menuLv2.Add(grandchildLabel, OpenFolder.Bind(grandchildPath))
        }

        if (cntLv2 == 0) {
            menuLv1.Add(childLabel, OpenFolder.Bind(childPath))
        } else {
            menuLv1.Add(childLabel, menuLv2)
        }
    }

    ; Update Cache
    g_FolderMenuCache[rootPath] := { Hash: currentHash, Menu: menuLv1 }

    return menuLv1
}

ShowFolderWarningMsg() {
    MsgBox("The specified folder could not be found. The network drive may be disconnected or inaccessible.", "Folder Not Found!", 262144)
}
