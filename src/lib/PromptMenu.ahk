#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Utils.ahk

; =================================================================================
; Module: PromptMenu
; Description: Shows registered Quick Prompts as a popup menu at mouse cursor.
;              Activated via Shift+Win+Space. Reuses EmojiPicker menu pattern.
; Author: KBPark
; =================================================================================

global g_promptMenu := Menu()

BuildPromptMenu() {
    global g_promptMenu
    g_promptMenu.Delete()

    SafePromptLabel(text, fallback := "Item") {
        label := StrReplace(text, "`r`n", " ")
        label := StrReplace(label, "`r", " ")
        label := StrReplace(label, "`n", " ")
        label := Trim(label)
        if (label == "")
            label := fallback
        if (StrLen(label) > 60)
            label := SubStr(label, 1, 60) . "..."
        return label
    }

    if !ConfigExists("Prompts")
        return

    ; Read the user's configured prompt hotkey so each group shows its actual
    ; shortcut (e.g. "Win+Num1") instead of a generic "Slot 1".
    settings := ConfigReadAppSettings()
    modDisplay := FormatHotkeyDisplay(settings.PromptModifier)

    ; Build the group label from the real hotkey. Falls back to "Slot N" when
    ; the prompt modifier is empty (hotkeys disabled), since no shortcut applies.
    PromptGroupLabel(num) {
        if (settings.PromptModifier == "")
            return "⌨️ Slot " . num
        keyPart := (settings.PromptUseNumpad ? "Num" : "") . num
        return "⌨️ " . modDisplay . keyPart
    }

    promptData := ConfigReadPromptData()

    ; First pass: is any slot populated at all?
    hasAnyItems := false
    loop 10 {
        n := A_Index - 1
        if (promptData.Has(n) && promptData[n].Length > 0) {
            hasAnyItems := true
            break
        }
    }

    ; Nothing configured anywhere — show a single hint and stop.
    if (!hasAnyItems) {
        g_promptMenu.Add("(No prompts registered)", (*) => 0)
        g_promptMenu.Disable("(No prompts registered)")
        return
    }

    ; Second pass: one entry per slot. Populated slots get a submenu; empty slots
    ; are shown disabled so the full hotkey map stays discoverable at a glance.
    loop 10 {
        num := A_Index - 1
        groupLabel := PromptGroupLabel(num)

        if (promptData.Has(num) && promptData[num].Length > 0) {
            subMenu := Menu()
            for idx, item in promptData[num] {
                ; Prefix the tap-order number so the menu matches the tap-to-cycle sequence.
                itemLabel := idx . ". " . SafePromptLabel(item.Title, "Prompt")
                boundNum := num
                boundIdx := idx
                subMenu.Add(itemLabel, ((n, i, *) => _ExecutePromptFromMenu(n, i)).Bind(boundNum, boundIdx))
            }
            g_promptMenu.Add(groupLabel, subMenu)
        } else if (settings.PromptModifier != "") {
            emptyLabel := groupLabel . "  —  (empty)"
            g_promptMenu.Add(emptyLabel, (*) => 0)
            g_promptMenu.Disable(emptyLabel)
        }
    }
}

ShowPromptMenu(*) {
    BuildPromptMenu()
    g_promptMenu.Show()
}

_ExecutePromptFromMenu(groupNum, itemIdx, *) {
    promptData := ConfigReadPromptData()
    if !promptData.Has(groupNum)
        return
    if (itemIdx < 1 || itemIdx > promptData[groupNum].Length)
        return

    item := promptData[groupNum][itemIdx]
    msg := item.Msg

    if (msg == "")
        return

    if (HasSpecialKeys(msg)) {
        ExecutePromptSequence(msg)
    } else {
        SetStyledClipboard(msg, "black", 11)
        Send("^v")
    }
}
