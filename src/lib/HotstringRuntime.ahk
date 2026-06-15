#Requires AutoHotkey v2.0
#Include Config.ahk

; Runtime globals such as g_registeredHotstrings are initialized in SwiftDeck.ahk.

LoadHotstrings() {
    global g_registeredHotstrings

    for hotstringSpec in g_registeredHotstrings {
        try Hotstring(hotstringSpec, , "Off")
    }
    g_registeredHotstrings := []

    if !ConfigExists("Hotstrings")
        return

    failedItems := []
    hotstringData := ConfigReadHotstringData()

    for groupSection in hotstringData.GroupOrder {
        if !hotstringData.Data.Has(groupSection)
            continue
        if (HotstringGetRuntimeGroupType(groupSection) != "Space")
            continue

        for item in hotstringData.Data[groupSection] {
            triggerText := Trim(item.Key)
            replacementText := Trim(item.Val)
            if (triggerText == "" || replacementText == "")
                continue

            ; No * option: AutoHotkey checks the trigger only after an ending character.
            hotstringSpec := ":T:" . triggerText
            try {
                Hotstring(hotstringSpec, replacementText)
                Hotstring(hotstringSpec, , "On")
                g_registeredHotstrings.Push(hotstringSpec)
            } catch {
                failedItems.Push(triggerText)
            }
        }
    }

    if (failedItems.Length > 0) {
        failedList := ""
        maxShow := Min(failedItems.Length, 5)  ; Show up to 5 failed triggers
        loop maxShow {
            failedList .= failedItems[A_Index] . ", "
        }
        failedList := RTrim(failedList, ", ")
        if (failedItems.Length > 5)
            failedList .= " ... +" . (failedItems.Length - 5) . " more"
        ToolTip("⚠️ Failed hotstrings (" . failedItems.Length . "): " . failedList)
        SetTimer(() => ToolTip(), -5000)
    }
}
