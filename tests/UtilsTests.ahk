#Requires AutoHotkey v2.0
#Include ..\src\lib\Utils.ahk

AssertEqual(actual, expected, label) {
    if (actual != expected)
        throw Error(label . ": expected '" . expected . "', got '" . actual . "'")
}

AssertEqual(GetAddFolderHotkey("F1"), "^F1", "Default add-folder hotkey")
AssertEqual(GetAddFolderHotkey("^F1"), "^+F1", "Ctrl main hotkey")
AssertEqual(GetAddFolderHotkey("^+!#F1"), "^F1", "All-modifier fallback")
AssertEqual(ValidateHotkeyAssignments("F1", "#", 1, "^#Space", "^#Escape"), "", "Default hotkey set")

conflict := ValidateHotkeyAssignments("+#Space", "#", 1, "^#Space", "^#Escape")
if !InStr(conflict, "Prompt Popup Menu conflicts with Favorites Menu")
    throw Error("Expected Favorites/Prompt Popup conflict, got: " . conflict)

centered := CalculateCenteredWindowPosition(500, 400, 0, 0, 1920, 1040)
AssertEqual(centered.X, 710, "Primary monitor center X")
AssertEqual(centered.Y, 320, "Primary monitor center Y")

secondary := CalculateCenteredWindowPosition(500, 400, -1920, 0, 0, 1040)
AssertEqual(secondary.X, -1210, "Negative-coordinate monitor center X")
AssertEqual(secondary.Y, 320, "Negative-coordinate monitor center Y")

oversized := CalculateCenteredWindowPosition(2200, 1200, -1920, -200, 0, 840)
AssertEqual(oversized.X, -1920, "Oversized window clamps to work-area left")
AssertEqual(oversized.Y, -200, "Oversized window clamps to work-area top")

ExitApp(0)
