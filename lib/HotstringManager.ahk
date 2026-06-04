#Requires AutoHotkey v2.0
;@disable-check undeclared

; =================================================================================
; Module: HotstringManager
; Description: Provides a GUI for managing dynamic hotstrings (auto-text expansions).
; Author: KBPark (Financial Specialist)
; =================================================================================
class HotstringManager {
    __New(parentGui := "") {
        this.parentGui := parentGui
        hotstringData := ConfigReadHotstringData()
        this.localData := hotstringData.Data
        this.groupOrder := hotstringData.GroupOrder

        if (parentGui)
            this.BuildUI(parentGui)
    }

    Show() {
        if (!this.parentGui) {
            this.hsGui := Gui("+AlwaysOnTop", "HotStrings Manager")
            EnableDarkMode(this.hsGui)
            this.BuildUI(this.hsGui)
            this.hsGui.Show("w430 h520")
        }
    }

    BuildUI(guiObj) {
        startX := this.parentGui ? 30 : 30
        startY := this.parentGui ? 120 : 20
        this.mainHwnd := guiObj.Hwnd
        if (!this.parentGui)
            guiObj.OnEvent("Close", (*) => guiObj.Destroy())

        ; Group Name row — clean layout with single Manage button
        guiObj.Add("Text", "x" . startX . " y" . startY . " w100", "① Select Group:")

        guiObj.SetFont("cBlack")
        this.cbGroup := guiObj.Add("ComboBox", "x" . (startX + 105) . " y" . (startY - 5) . " w210", [])
        guiObj.SetFont("c" . THEME_TEXT)

        btnManageGrp := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY - 5) . " w85 h25", "⚙️ Groups")

        this.txtDesc := guiObj.Add("Text", "x" . startX . " y" . (startY + 30) . " w400 c" . THEME_MUTED,
            "(Type abbreviation + Space/Enter to trigger expansion)")

        guiObj.Add("Text", "x" . startX . " y" . (startY + 55) . " w200", "② Abbreviation List:")

        guiObj.SetFont("cBlack")
        this.lbItems := guiObj.Add("ListBox", "x" . startX . " y" . (startY + 75) . " w310 h345")
        guiObj.SetFont("c" . THEME_TEXT)

        guiObj.SetFont("s9 cD03A3A norm", "Segoe UI")
        btnReset := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 45) . " w85 h25 Center +0x200 +Border Background2D2D30", "⚠️ Reset")
        btnReset.OnEvent("Click", (*) => ResetToDefaults("Hotstrings"))
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        btnAdd := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 75) . " w85 h35", "➕ New")
        btnEdit := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 115) . " w85 h35", "✏️ Edit")
        btnDel := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 155) . " w85 h35", "❌ Delete")
        guiObj.SetFont("s9 cWhite norm", "Segoe UI")
        btnUp := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 300) . " w85 h35 Center +0x200 +Border Background000000", "▲ Up")
        btnDown := guiObj.Add("Text", "x" . (startX + 320) . " y" . (startY + 340) . " w85 h35 Center +0x200 +Border Background000000", "▼ Down")
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        if (!this.parentGui) {
            btnClose := guiObj.Add("Button", "x" . (startX + 320) . " y" . (startY + 475) . " w85 h35", "Close")
            btnClose.OnEvent("Click", (*) => guiObj.Destroy())
        }

        this.cbGroup.OnEvent("Change", (*) => this.OnGroupChange())
        this.lbItems.OnEvent("DoubleClick", (*) => this.EditSelectedItem())

        btnManageGrp.OnEvent("Click", (*) => this.ShowGroupManagerPopup())
        btnAdd.OnEvent("Click", (*) => this.ShowEditPopup(false, 0))
        btnEdit.OnEvent("Click", (*) => this.EditSelectedItem())
        btnDel.OnEvent("Click", (*) => this.DeleteItem())
        btnUp.OnEvent("Click", (*) => this.MoveItem(-1))
        btnDown.OnEvent("Click", (*) => this.MoveItem(1))

        guiObj.SetFont("s10 cWhite bold", "Segoe UI")
        btnSave := guiObj.Add("Text", "x" . startX . " y" . (startY + 430) . " w405 h35 Center +0x200 +Border Background4A4F54", "💾 Save & Apply")
        btnSave.OnEvent("Click", (*) => this.SaveSettings())
        guiObj.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        this.UpdateGroupsDdl()
        this.RefreshList()
    }

    ; =========================================================================
    ; Group Manager Popup — Add, Rename, Delete, Reorder groups in one place
    ; =========================================================================
    ShowGroupManagerPopup() {
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", "Manage Groups")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        popup.Add("Text", "x15 y10 w300 c666666", "Add, rename, reorder, or delete hotstring groups.")
        popup.SetFont("s8 c999999", "Segoe UI")
        popup.Add("Text", "x15 y30 w300", "(Prefix with * when adding for menu-only group)")
        popup.SetFont("s10 cBlack", "Segoe UI")

        ; Group ListBox
        lbGroups := popup.Add("ListBox", "x15 y55 w260 h230")

        ; Action buttons (right side)
        btnGAdd := popup.Add("Button", "x290 y55 w120 h32", "➕ New")
        btnGRename := popup.Add("Button", "x290 y92 w120 h32", "✏️ Rename")
        btnGDelete := popup.Add("Button", "x290 y129 w120 h32", "❌ Delete")
        popup.SetFont("s9 cWhite norm", "Segoe UI")
        btnGUp := popup.Add("Text", "x290 y210 w58 h32 Center +0x200 +Border Background000000", "▲ Up")
        btnGDown := popup.Add("Text", "x352 y210 w58 h32 Center +0x200 +Border Background000000", "▼ Down")
        popup.SetFont("s10 c" . THEME_TEXT . " norm", "Segoe UI")

        ; Close button
        btnGClose := popup.Add("Button", "x290 y253 w120 h32", "Close")

        ; Helper: refresh the popup's group list
        RefreshGroupList(selectName := "") {
            lbGroups.Delete()
            groupNames := []
            for _, secName in this.groupOrder {
                gn := this.GetGroupName(secName)
                if (gn != "") {
                    prefix := (SubStr(secName, 1, 11) == "Group_Menu_") ? "📋 " : "⌨️ "
                    itemCount := this.localData.Has(secName) ? this.localData[secName].Length : 0
                    groupNames.Push(prefix . gn . "  (" . itemCount . ")")
                }
            }
            if (groupNames.Length > 0)
                lbGroups.Add(groupNames)

            if (selectName != "") {
                for i, secName in this.groupOrder {
                    if (this.GetGroupName(secName) == selectName) {
                        lbGroups.Choose(i)
                        break
                    }
                }
            } else if (groupNames.Length > 0) {
                lbGroups.Choose(1)
            }
        }

        ; Helper: get the selected group's index in groupOrder
        GetSelectedIdx() {
            return lbGroups.Value
        }

        ; --- Add Group ---
        btnGAdd.OnEvent("Click", (*) => OnAdd())
        OnAdd() {
            popup.Opt("+OwnDialogs")
            ib := InputBox("Enter a name for the new group:`n(Prefix with '*' for menu-only group)", "New Group", "w350 h140")

            if (ib.Result != "OK" || Trim(ib.Value) == "")
                return
            gInput := Trim(ib.Value)
            isMenuOnly := (SubStr(gInput, 1, 1) == "*")
            gName := isMenuOnly ? Trim(SubStr(gInput, 2)) : gInput
            gName := Trim(gName)
            if (gName == "") {
                MsgBox("⚠️ Group name cannot be empty.", "Warning", 262192)
                return
            }
            if (this.localData.Has("Group_Space_" . gName) || this.localData.Has("Group_Menu_" . gName)) {
                MsgBox("⚠️ Group '" . gName . "' already exists.", "Duplicate Group", 262160)
                return
            }
            sec := (isMenuOnly ? "Group_Menu_" : "Group_Space_") . gName
            this.localData[sec] := []
            this.groupOrder.Push(sec)
            this.UpdateGroupsDdl(gName)
            this.RefreshList(0)
            RefreshGroupList(gName)
            ToolTip("✅ Group '" . gName . "' Created. Click Save & Apply.")
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Rename Group ---
        btnGRename.OnEvent("Click", (*) => OnRename())
        OnRename() {
            selIdx := GetSelectedIdx()
            if (selIdx == 0 || selIdx > this.groupOrder.Length)
                return
            oldSec := this.groupOrder[selIdx]
            oldName := this.GetGroupName(oldSec)
            if (oldName == "Default") {
                MsgBox("⚠️ The Default group cannot be renamed.", "Warning", 262192)
                return
            }

            popup.Opt("+OwnDialogs")
            ib := InputBox("Rename group '" . oldName . "' to:", "Rename Group", "w350 h120", oldName)

            if (ib.Result != "OK" || Trim(ib.Value) == "" || Trim(ib.Value) == oldName)
                return
            newName := Trim(ib.Value)
            if (this.localData.Has("Group_Space_" . newName) || this.localData.Has("Group_Menu_" . newName)) {
                MsgBox("⚠️ Group '" . newName . "' already exists.", "Duplicate Group", 262160)
                return
            }
            ; Preserve prefix type (Space or Menu)
            isMenu := (SubStr(oldSec, 1, 11) == "Group_Menu_")
            newSec := (isMenu ? "Group_Menu_" : "Group_Space_") . newName

            ; Migrate data
            if (this.localData.Has(oldSec)) {
                this.localData[newSec] := this.localData[oldSec]
                this.localData.Delete(oldSec)
            } else {
                this.localData[newSec] := []
            }
            ; Update groupOrder
            this.groupOrder[selIdx] := newSec

            this.UpdateGroupsDdl(newName)
            this.RefreshList(0)
            RefreshGroupList(newName)
            ToolTip("✅ Group Renamed. Click Save & Apply.")
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Delete Group ---
        btnGDelete.OnEvent("Click", (*) => OnDelete())
        OnDelete() {
            selIdx := GetSelectedIdx()
            if (selIdx == 0 || selIdx > this.groupOrder.Length)
                return
            sec := this.groupOrder[selIdx]
            gName := this.GetGroupName(sec)
            if (gName == "Default") {
                MsgBox("⚠️ The Default group cannot be deleted.", "Warning", 262192)
                return
            }
            itemCount := this.localData.Has(sec) ? this.localData[sec].Length : 0
            msgRes := MsgBox("❓ Are you sure you want to delete group '" . gName . "'?`n(" . itemCount . " hotstrings will be removed)", "Delete Group", 262436)
            if (msgRes != "Yes")
                return
            if (this.localData.Has(sec))
                this.localData.Delete(sec)
            this.groupOrder.RemoveAt(selIdx)
            this.UpdateGroupsDdl()
            this.RefreshList(0)
            RefreshGroupList()
            ToolTip("✅ Group '" . gName . "' Deleted. Click Save & Apply.")
            SetTimer(() => ToolTip(), -2000)
        }

        ; --- Move Up ---
        btnGUp.OnEvent("Click", (*) => OnMove(-1))
        ; --- Move Down ---
        btnGDown.OnEvent("Click", (*) => OnMove(1))
        OnMove(dir) {
            selIdx := GetSelectedIdx()
            if (selIdx == 0)
                return
            targetIdx := selIdx + dir
            if (targetIdx < 1 || targetIdx > this.groupOrder.Length)
                return
            gName := this.GetGroupName(this.groupOrder[selIdx])
            temp := this.groupOrder[selIdx]
            this.groupOrder[selIdx] := this.groupOrder[targetIdx]
            this.groupOrder[targetIdx] := temp
            this.UpdateGroupsDdl(gName)
            RefreshGroupList(gName)
        }

        btnGClose.OnEvent("Click", (*) => CleanUpAndClose())

        RefreshGroupList()
        popup.Show("w425 h300")
    }

    GetGroupName(secName) {
        if (SubStr(secName, 1, 12) == "Group_Space_")
            return SubStr(secName, 13)
        if (SubStr(secName, 1, 11) == "Group_Menu_")
            return SubStr(secName, 12)
        return ""
    }

    GetRawGroupName(displayName) {
        return displayName
    }

    UpdateGroupsDdl(selectGroup := "") {
        groups := []
        for _, secName in this.groupOrder {
            if (this.localData.Has(secName)) {
                gn := this.GetGroupName(secName)
                if (gn != "")
                    groups.Push(gn)
            }
        }

        this.cbGroup.Delete()
        if (groups.Length > 0)
            this.cbGroup.Add(groups)

        if (selectGroup != "") {
            this.cbGroup.Text := selectGroup
        } else if (groups.Length > 0) {
            this.cbGroup.Choose(1)
        }
    }

    OnGroupChange() {
        sec := this.GetCurrentSection()
        if (sec != "" && !this.localData.Has(sec)) {
            this.localData[sec] := []
        }
        this.RefreshList(0)
    }

    GetCurrentSection() {
        displayName := Trim(this.cbGroup.Text)
        if (displayName == "")
            displayName := "Default"
        rawName := this.GetRawGroupName(displayName)

        ; Check if it exists as Menu group first
        if (this.localData.Has("Group_Menu_" . rawName))
            return "Group_Menu_" . rawName
        return "Group_Space_" . rawName
    }

    IsDuplicateKey(keyToCheck, currentSec, currentIdx := 0) {
        for secName, items in this.localData {
            for idx, item in items {
                if (secName == currentSec && idx == currentIdx)
                    continue
                if (StrLower(item.Key) == StrLower(keyToCheck)) {
                    return this.GetGroupName(secName)
                }
            }
        }
        return ""
    }

    RefreshList(targetIdx := 0) {
        sec := this.GetCurrentSection()

        this.lbItems.Delete()
        listData := []

        if (this.localData.Has(sec)) {
            for idx, item in this.localData[sec] {
                displayVal := StrReplace(item.Val, "`n", " ↵ ")
                if (StrLen(displayVal) > 25)
                    displayVal := SubStr(displayVal, 1, 25) . "…"
                listData.Push("[ " . item.Key . " ]  ▶  " . displayVal)
            }
        }

        if (listData.Length > 0)
            this.lbItems.Add(listData)

        if (targetIdx > 0 && targetIdx <= listData.Length) {
            this.lbItems.Choose(targetIdx)
        }
    }

    EditSelectedItem() {
        idx := this.lbItems.Value
        if (idx > 0) {
            this.ShowEditPopup(true, idx)
        }
    }

    MoveItem(dir) {
        sec := this.GetCurrentSection()
        idx := this.lbItems.Value
        if (idx == 0)
            return

        targetIdx := idx + dir
        if (targetIdx < 1 || targetIdx > this.localData[sec].Length)
            return

        temp := this.localData[sec][idx]
        this.localData[sec][idx] := this.localData[sec][targetIdx]
        this.localData[sec][targetIdx] := temp

        this.RefreshList(targetIdx)
    }

    ShowEditPopup(isEdit := false, editIdx := 0) {
        sec := this.GetCurrentSection()
        WinSetEnabled(0, this.mainHwnd)
        popup := Gui("+AlwaysOnTop +Owner" . this.mainHwnd . " -MinimizeBox -MaximizeBox", isEdit ? "Edit Hotstring" : "Add Hotstring")

        CleanUpAndClose() {
            WinSetEnabled(1, this.mainHwnd)
            WinActivate(this.mainHwnd)
            popup.Destroy()
        }
        popup.OnEvent("Close", (*) => CleanUpAndClose())
        popup.BackColor := "FFFFFF"
        popup.SetFont("s10 cBlack", "Segoe UI")

        ; Pre-fill values if editing
        existingKey := ""
        existingVal := ""
        if (isEdit && this.localData.Has(sec) && editIdx > 0 && editIdx <= this.localData[sec].Length) {
            existingKey := this.localData[sec][editIdx].Key
            existingVal := this.localData[sec][editIdx].Val
        }

        ; --- Abbreviation Section ---
        popup.Add("GroupBox", "x15 y10 w400 h90 cBlack", "③ Abbreviation (Trigger)")
        popup.Add("Text", "x30 y30 w370 c666666", "Type this text to trigger the expansion:")
        edtKey := popup.Add("Edit", "x30 y55 w370 h30", existingKey)

        ; --- Replacement Section ---
        popup.Add("GroupBox", "x15 y115 w400 h120 cBlack", "④ Replacement (Output)")
        popup.Add("Text", "x30 y135 w370 c666666", "The abbreviation will be replaced with this text:")
        edtVal := popup.Add("Edit", "x30 y158 w370 h60", existingVal)

        ; Action buttons
        popup.SetFont("s10 cWhite bold", "Segoe UI")
        btnConfirm := popup.Add("Text", "x215 y250 w200 h35 Center +0x200 +Border Background0078D7", isEdit ? "💾 Save Changes" : "➕ Add Hotstring")
        popup.SetFont("s10 cBlack norm", "Segoe UI")
        btnConfirm.OnEvent("Click", (*) => OnConfirm())

        btnCancel := popup.Add("Button", "x15 y250 w190 h35", "Cancel")
        btnCancel.OnEvent("Click", (*) => CleanUpAndClose())

        OnConfirm() {
            k := Trim(edtKey.Value)
            v := Trim(edtVal.Value)
            if (k == "" || v == "") {
                MsgBox("⚠️ Please enter both an abbreviation and its replacement text.", "Warning", 262192)
                return
            }

            dupGroup := this.IsDuplicateKey(k, sec, isEdit ? editIdx : 0)
            if (dupGroup != "") {
                MsgBox("⚠️ The abbreviation '" . k . "' is already registered in group: " . dupGroup . ".`nDuplicates are not allowed.", "Duplicate", 262160)
                return
            }

            if (!this.localData.Has(sec))
                this.localData[sec] := []

            if (isEdit) {
                this.localData[sec][editIdx].Key := k
                this.localData[sec][editIdx].Val := v
            } else {
                this.localData[sec].Push({ Key: k, Val: v })
            }

            this.RefreshList(isEdit ? editIdx : this.localData[sec].Length)
            CleanUpAndClose()
            ToolTip(isEdit ? "✅ Modified. Click Save & Apply." : "✅ Added. Click Save & Apply.")
            SetTimer(() => ToolTip(), -2000)
        }

        popup.Show("w430 h300")
    }

    DeleteItem() {
        sec := this.GetCurrentSection()
        selIdx := this.lbItems.Value
        if (selIdx == 0)
            return

        item := this.localData[sec][selIdx]
        friendlyItem := "[ " . item.Key . " ]  ▶  " . StrReplace(item.Val, "`n", " ↵ ")
        msgRes := MsgBox("❓ Are you sure you want to delete this hotstring?`n`n" . friendlyItem, "Confirm Delete", 262436)
        if (msgRes != "Yes")
            return

        this.localData[sec].RemoveAt(selIdx)

        this.RefreshList(selIdx > this.localData[sec].Length ? this.localData[sec].Length : selIdx)
        ToolTip("✅ Deleted. Click Save & Apply.")
        SetTimer(() => ToolTip(), -2000)
    }

    SaveSettings() {
        ConfigWriteHotstringData(this.localData, this.groupOrder)
        LoadHotstrings()
        BuildEmojiMenu()
        ToolTip("✅ Saved & Applied")
        SetTimer(() => ToolTip(), -2000)
    }
}

LoadHotstrings() {
    global g_filePath_Hotstring, g_registeredHotstrings

    ; Deactivate all previously registered hotstrings
    for hsKey in g_registeredHotstrings {
        try Hotstring(hsKey, , "Off")
    }
    g_registeredHotstrings := []

    if !ConfigExists("Hotstrings")
        return

    sections := ""
    try sections := ConfigReadSections("Hotstrings")
    if (sections == "")
        return

    loop parse, sections, "`n", "`r" {
        secName := Trim(A_LoopField)
        if (secName == "" || secName == "Meta")
            continue
        if (SubStr(secName, 1, 12) != "Group_Space_")
            continue

        pairs := ""
        try pairs := ConfigReadSection("Hotstrings", secName, "")
        if (pairs == "")
            continue

        loop parse, pairs, "`n", "`r" {
            pair := ParseIniKeyValuePairs(A_LoopField)
            if (pair.Key != "") {
                fixed := FixIniSpecialChars(pair.Key, pair.Val)
                hsKey := ":*:" . fixed.Key
                Hotstring(hsKey, fixed.Val)
                Hotstring(hsKey, , "On")
                g_registeredHotstrings.Push(hsKey)
            }
        }
    }
}
