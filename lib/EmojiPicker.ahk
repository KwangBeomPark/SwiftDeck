#Requires AutoHotkey v2.0
#Include Config.ahk
#Include Utils.ahk
; =================================================================================
; --- Emoji & Symbol Popup Menu (Emoji Picker) ---
; =================================================================================

global g_emojiMenu := Menu()

BuildEmojiMenu() {
    global g_emojiMenu
    g_emojiMenu.Delete()

    SendMenuText(text, ItemName, ItemPos, MyMenu) {
        SendText(text)
    }

    SafeMenuLabel(text, fallback := "Item") {
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

    ; User Hotstring & Menu Groups
    if ConfigExists("Hotstrings") {
        hotstringData := ConfigReadHotstringData()
        groupIndex := 1
        for secName in hotstringData.GroupOrder {
            if !hotstringData.Data.Has(secName)
                continue

            displayName := SafeMenuLabel(HotstringGetRuntimeGroupName(secName), "Unnamed Group")
            mUserGroup := Menu()
            hasItems := false
            for item in hotstringData.Data[secName] {
                if (item.Key != "" && item.Val != "") {
                    itemLabel := SafeMenuLabel(item.Val, "Text") . "  [" . SafeMenuLabel(item.Key, "Trigger") . "]"
                    try {
                        mUserGroup.Add(itemLabel, SendMenuText.Bind(item.Val))
                        hasItems := true
                    }
                }
            }

            if (hasItems) {
                try {
                    g_emojiMenu.Add(groupIndex . "️⃣ " . displayName, mUserGroup)
                    groupIndex++
                }
            }
        }
    }
}
