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

    failedCount := 0
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

            ; B0 keeps AutoHotkey from deleting text automatically; the handler
            ; selects the trigger itself because slow editors can miss fast deletes.
            hotstringSpec := ":*B0:" . triggerText
            try {
                Hotstring(hotstringSpec, ReplaceHotstringText.Bind(triggerText, replacementText))
                Hotstring(hotstringSpec, , "On")
                g_registeredHotstrings.Push(hotstringSpec)
            } catch {
                failedCount++
            }
        }
    }

    if (failedCount > 0) {
        ToolTip("⚠️ Some hotstrings could not be registered: " . failedCount)
        SetTimer(() => ToolTip(), -3000)
    }
}

ReplaceHotstringText(triggerText, replacementText, thisHotkey := "") {
    static isReplacing := false

    waitCount := 0
    while (isReplacing && waitCount < 20) {
        Sleep(25)
        waitCount++
    }
    if (isReplacing)
        return

    isReplacing := true
    savedClipboard := ""
    hasSavedClipboard := false
    try {
        savedClipboard := ClipboardAll()
        hasSavedClipboard := true
    }

    try {
        SelectTypedHotstringTrigger(StrLen(triggerText))

        ; Clipboard paste is more reliable than simulated typing for Unicode symbols.
        if HotstringSetClipboardTextWithRetry(replacementText) {
            SendEvent("^v")
            Sleep(500)
        } else {
            SendText(replacementText)
            Sleep(80)
        }
    } finally {
        try SendEvent("{Shift up}")
        Sleep(250)
        if (hasSavedClipboard)
            try A_Clipboard := savedClipboard
        isReplacing := false
    }
}

SelectTypedHotstringTrigger(triggerLength) {
    Sleep(90)
    SendEvent("{Shift down}")
    loop triggerLength {
        SendEvent("{Left}")
        Sleep(12)
    }
    SendEvent("{Shift up}")
    Sleep(30)
}

HotstringSetClipboardTextWithRetry(text, attempts := 5) {
    loop attempts {
        try {
            A_Clipboard := text
            if ClipWait(0.5)
                return true
        }
        Sleep(80)
    }
    return false
}
