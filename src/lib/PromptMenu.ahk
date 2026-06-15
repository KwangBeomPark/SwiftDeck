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

    promptData := ConfigReadPromptData()
    hasAnyItems := false

    loop 10 {
        num := A_Index - 1
        if !promptData.Has(num)
            continue
        if (promptData[num].Length == 0)
            continue

        ; Create a submenu for each numpad group
        subMenu := Menu()
        for idx, item in promptData[num] {
            itemLabel := SafePromptLabel(item.Title, "Prompt")
            boundNum := num
            boundIdx := idx
            subMenu.Add(itemLabel, ((n, i, *) => _ExecutePromptFromMenu(n, i)).Bind(boundNum, boundIdx))
        }

        groupLabel := "⌨️ Slot " . num
        g_promptMenu.Add(groupLabel, subMenu)
        hasAnyItems := true
    }

    if (!hasAnyItems) {
        g_promptMenu.Add("(No prompts registered)", (*) => 0)
        g_promptMenu.Disable("(No prompts registered)")
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
