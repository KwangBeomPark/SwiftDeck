#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Theme.ahk
#Include Utils.ahk

; =================================================================================
; Module: FolderManager
; Description: Handles the UI and logic for managing Favorite Folders.
; Author: KBPark (Financial Specialist)
; =================================================================================
class FolderManager {
    static ReadFolderItems() {
        return ConfigReadFolderItems()
    }

    static WriteFolderItems(items) {
        ConfigWriteFolderItems(items)
    }

    __New(parentGui := "") {
        this.orderedItems := FolderManager.ReadFolderItems()
        this.parentGui := parentGui
        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.rGui := Gui("+AlwaysOnTop -MaximizeBox", "Folder Manager")
            EnableDarkMode(this.rGui)
            this.BuildUI(this.rGui)
            this.rGui.Show("AutoSize")
        }
    }

    BuildUI(guiObj) {
        this.mainHwnd := guiObj.Hwnd
        startX := this.parentGui ? 35 : 25
        startY := this.parentGui ? 115 : 80
        guiObj.SetFont("s10", "Segoe UI")

        guiObj.Add("Text", "x" . startX . " y" . startY . " w400", "Saved Folders:")

        ; Set ListBox text color to black (for readability on white background)
        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 25) . " w310 h345")
        guiObj.SetFont("c" . THEME_TEXT)

        btnAddDir := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 25) . " w85 h35", "➕ New")
        btnEdit := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 65) . " w85 h35", "✏️ Edit")
        btnSep := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 105) . " w85 h35", "➖ Separator")
        btnDel := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 145) . " w85 h35", "❌ Delete")

        guiObj.SetFont("s9 cWhite norm", "Segoe UI")
        btnUp := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 290) . " w85 h35 Center +0x200 +Border Background000000", "▲ Up")
        btnDown := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 330) . " w85 h35 Center +0x200 +Border Background000000", "▼ Down")
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY - 5) . " w85 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Favorites"))

        guiObj.SetFont("s10 cWhite bold", "Segoe UI")
        btnSave := guiObj.Add("Text", "x" . startX . " y" . (startY + 385) . " w405 h40 Center +0x200 +Border Background4A4F54", "💾 Save & Apply")
        guiObj.SetFont("c" . THEME_TEXT . " norm", "Segoe UI")

        guiObj.Add("Text", "x" . startX . " y" . (startY + 435) . " w405 c" . THEME_MUTED . " Center", "💡 Press the Folder Menu Hotkey (default: F1) anywhere to open this menu.")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 465) . " w85 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.RefreshList()

        this.lbItems.OnEvent("DoubleClick", (*) => this.EditFolder())
        btnAddDir.OnEvent("Click", (*) => this.AddFolder())
        btnEdit.OnEvent("Click", (*) => this.EditFolder())
        btnSep.OnEvent("Click", (*) => this.AddSeparator())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnUp.OnEvent("Click", (*) => this.MoveItem(-1))
        btnDown.OnEvent("Click", (*) => this.MoveItem(1))
        btnSave.OnEvent("Click", (*) => this.SaveAndClose(guiObj))
    }

    RefreshList(targetIdx := 0) {
        listData := []
        sepCnt := 0
        for obj in this.orderedItems {
            if (obj.Name == "-") {
                sepCnt++
                listData.Push("── Separator #" . sepCnt . " ──")
            } else {
                listData.Push(obj.Name)
            }
        }
        this.lbItems.Delete()
        if (listData.Length > 0)
            this.lbItems.Add(listData)
        if (targetIdx > 0 && targetIdx <= listData.Length)
            this.lbItems.Choose(targetIdx)
    }

    MoveItem(dir) {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        targetIdx := idx + dir
        if (targetIdx < 1 || targetIdx > this.orderedItems.Length)
            return

        temp := this.orderedItems[idx]
        this.orderedItems[idx] := this.orderedItems[targetIdx]
        this.orderedItems[targetIdx] := temp

        this.RefreshList(targetIdx)
    }

    DeleteItem() {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        item := this.orderedItems[idx]
        friendlyItem := (item.Name == "-") ? "Separator" : "[" . item.Name . "]`nPath: " . item.Path
        msgRes := MsgBox("❓ Are you sure you want to delete this favorite folder?`n`n" . friendlyItem, "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.orderedItems.RemoveAt(idx)
        this.RefreshList(idx > this.orderedItems.Length ? this.orderedItems.Length : idx)
    }

    AddSeparator() {
        this.orderedItems.Push({ Name: "-", Path: "-" })
        this.RefreshList(this.orderedItems.Length)
    }

    AddFolderItem(folderName, folderPath) {
        folderName := Trim(folderName)
        if (!IsPlainIniKeySafe(folderName)) {
            MsgBox("⚠️ Folder name cannot contain '=' or line breaks.`nPlease use a simpler nickname.", "Invalid Folder Name", 262192)
            return false
        }
        this.orderedItems.Push({ Name: folderName, Path: folderPath })
        this.RefreshList(this.orderedItems.Length)
        return true
    }

    EditFolder() {
        idx := this.lbItems.Value
        if (idx == 0)
            return

        item := this.orderedItems[idx]
        if (item.Name == "-") {
            MsgBox("⚠️ Separator cannot be edited.", "Info", 262208)
            return
        }

        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", "Edit Folder")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        popup.Add("GroupBox", "x15 y10 w400 h80 cBlack", "Folder Name (Nickname)")
        edtName := popup.Add("Edit", "x30 y35 w370 h30", item.Name)

        popup.Add("GroupBox", "x15 y100 w400 h80 cBlack", "Folder Path")
        edtPath := popup.Add("Edit", "x30 y125 w300 h30", item.Path)
        btnBrowse := popup.Add("Button", "x340 y124 w60 h32", "Browse")

        btnBrowse.OnEvent("Click", (*) => OnBrowse())
        OnBrowse() {
            popup.Opt("-AlwaysOnTop")
            selectedDir := DirSelect("*" . edtPath.Value, 3, "Select a folder")
            popup.Opt("+AlwaysOnTop")
            if (selectedDir != "")
                edtPath.Value := selectedDir
        }

        popup.SetFont("s10 cWhite bold", "Segoe UI")
        btnConfirm := popup.Add("Text", "x215 y200 w200 h35 Center +0x200 +Border Background0078D7", "💾 Save Changes")
        popup.SetFont("s10 cBlack norm", "Segoe UI")
        btnConfirm.OnEvent("Click", (*) => OnConfirm())

        btnCancel := popup.Add("Button", "x15 y200 w190 h35", "Cancel")
        btnCancel.OnEvent("Click", (*) => CleanUpAndClose())

        OnConfirm() {
            n := Trim(edtName.Value)
            p := Trim(edtPath.Value)
            if (n == "" || p == "") {
                MsgBox("⚠️ Please enter both folder name and path.", "Warning", 262192)
                return
            }
            if (!IsPlainIniKeySafe(n)) {
                MsgBox("⚠️ Folder name cannot contain '=' or line breaks.`nPlease use a simpler nickname.", "Invalid Folder Name", 262192)
                return
            }

            this.orderedItems[idx].Name := n
            this.orderedItems[idx].Path := p

            this.RefreshList(idx)
            CleanUpAndClose()
            ToolTip("✅ Modified. Click Save & Apply.")
            SetTimer(() => ToolTip(), -2000)
        }

        popup.Show("w430 h250")
    }

    AddFolder() {
        ; Temporarily disable AlwaysOnTop of parentGui / main window
        if (this.parentGui) {
            this.parentGui.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.mainHwnd)
        } else if (this.rGui) {
            this.rGui.Opt("-AlwaysOnTop")
            WinSetAlwaysOnTop(0, this.rGui.Hwnd)
        }

        ; 3 = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE
        selectedDir := DirSelect("*" . A_MyDocuments, 3, "Select a folder to add to Favorites")

        if (selectedDir == "") {
            ; Restore AlwaysOnTop before returning
            if (this.parentGui) {
                this.parentGui.Opt("+AlwaysOnTop")
                WinSetAlwaysOnTop(1, this.mainHwnd)
            } else if (this.rGui) {
                this.rGui.Opt("+AlwaysOnTop")
                WinSetAlwaysOnTop(1, this.rGui.Hwnd)
            }
            return
        }

        defaultName := GetFileName(selectedDir)
        if (defaultName == "")
            defaultName := selectedDir

        ib := InputBox("Enter a nickname for this folder:`nPath: " . selectedDir,
            "Add Folder", "w350 h150", defaultName)

        ; Restore AlwaysOnTop
        if (this.parentGui) {
            this.parentGui.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.mainHwnd)
        } else if (this.rGui) {
            this.rGui.Opt("+AlwaysOnTop")
            WinSetAlwaysOnTop(1, this.rGui.Hwnd)
        }

        if (ib.Result != "OK" || Trim(ib.Value) == "")
            return

        this.AddFolderItem(ib.Value, selectedDir)
    }

    SaveAndClose(guiObj) {
        FolderManager.WriteFolderItems(this.orderedItems)
        if (!this.parentGui)
            guiObj.Destroy()
        ToolTip("✅ Saved successfully")
        SetTimer(() => ToolTip(), -2000)
    }
}
