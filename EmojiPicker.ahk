#Requires AutoHotkey v2.0
;@disable-check undeclared
; =================================================================================
; --- Emoji & Symbol Popup Menu (Emoji Picker) ---
; =================================================================================

global g_emojiMenu := Menu()

BuildEmojiMenu() {
    global g_emojiMenu
    g_emojiMenu.Delete()

    SendEmoji(ItemName, ItemPos, MyMenu) {
        ; If "  [" pattern exists, use everything before it as the symbol
        idx := InStr(ItemName, "  [")
        if (idx > 0) {
            symbol := SubStr(ItemName, 1, idx - 1)
        } else {
            arr := StrSplit(ItemName, " ")
            symbol := arr[1]
        }
        SendText(symbol)
    }

    ; User Hotstring & Menu Groups
    if ConfigExists("Hotstrings") {
        sections := ""
        try sections := ConfigReadSections("Hotstrings")
        if (sections != "") {
            groupIndex := 1
            loop parse, sections, "`n", "`r" {
                secName := Trim(A_LoopField)
                if (secName == "" || secName == "Meta")
                    continue

                displayName := ""
                if (SubStr(secName, 1, 12) == "Group_Space_") {
                    displayName := SubStr(secName, 13)
                } else if (SubStr(secName, 1, 11) == "Group_Menu_") {
                    displayName := SubStr(secName, 12)
                } else {
                    continue
                }

                pairs := ""
                try pairs := ConfigReadSection("Hotstrings", secName, "")
                if (pairs == "")
                    continue

                mUserGroup := Menu()
                hasItems := false
                loop parse, pairs, "`n", "`r" {
                    pair := ParseIniKeyValuePairs(A_LoopField)
                    if (pair.Key != "" && pair.Val != "") {
                        fixed := FixIniSpecialChars(pair.Key, pair.Val)
                        mUserGroup.Add(fixed.Val . "  [" . fixed.Key . "]", SendEmoji)
                        hasItems := true
                    }
                }

                if (hasItems) {
                    g_emojiMenu.Add(groupIndex . "️⃣ " . displayName, mUserGroup)
                    groupIndex++
                }
            }
        }
    }
}
