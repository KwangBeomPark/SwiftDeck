#Requires AutoHotkey v2.0
; =============================================================================
; --- Clipboard Utilities (HTML & Plain Text) ---
; =============================================================================

SetStyledClipboard(text, color, sizePt) {
    htmlText := HtmlEncodeWithBr(text)  ; HTML-safe encoding + newlines → <br>
    frag :=
        '<div style="font-family:Segoe UI, Arial, sans-serif; white-space:pre-wrap;">'
        . '<span style="color:' color '; font-size:' sizePt 'pt;">'
        . htmlText
        . '</span>'
        . '</div>'
    SetClipboardHtml(frag, text)
}

HtmlEncodeWithBr(s) {
    s := StrReplace(s, "&", "&amp;")
    s := StrReplace(s, "<", "&lt;")
    s := StrReplace(s, ">", "&gt;")
    s := StrReplace(s, '"', "&quot;")
    s := StrReplace(s, "'", "&#39;")
    ; Convert newlines to <br>
    s := StrReplace(s, "`r`n", "<br>")
    s := StrReplace(s, "`n", "<br>")
    s := StrReplace(s, "`r", "<br>")
    return s
}

; Set clipboard in CF_HTML format
;  - Registers both HTML and UNICODETEXT simultaneously
SetClipboardHtml(htmlFragment, plainText, sourceURL := "") {
    docStart := '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>'
    docEnd := '</body></html>'
    mStart := '<!--StartFragment-->'
    mEnd := '<!--EndFragment-->'
    htmlDoc := docStart . mStart . htmlFragment . mEnd . docEnd

    ; Header template (offsets filled later)
    hdr :=
    (
        "Version:0.9`r`n"
        "StartHTML:##########`r`n"
        "EndHTML:##########`r`n"
        "StartFragment:##########`r`n"
        "EndFragment:##########`r`n"
    )
    if (sourceURL != "")
        hdr .= "SourceURL:" . sourceURL . "`r`n"

    ; Helper: calculate UTF-8 byte length
    StrToUtf8Buffer(s) {
        buf := Buffer(StrPut(s, "UTF-8"))
        StrPut(s, buf, "UTF-8")
        return buf
    }

    hdrBuf := StrToUtf8Buffer(hdr), hdrBytes := hdrBuf.Size - 1
    docBuf := StrToUtf8Buffer(htmlDoc), docBytes := docBuf.Size - 1

    ; Fragment position (character index → UTF-8 byte offset)
    idxStart := InStr(htmlDoc, mStart)
    idxEnd := InStr(htmlDoc, mEnd)
    preStart := SubStr(htmlDoc, 1, idxStart - 1)
    preEnd := SubStr(htmlDoc, 1, idxEnd - 1)
    preStartBytes := StrToUtf8Buffer(preStart).Size - 1
    preEndBytes := StrToUtf8Buffer(preEnd).Size - 1
    mStartBytes := StrToUtf8Buffer(mStart).Size - 1

    StartHTML := hdrBytes
    EndHTML := hdrBytes + docBytes
    StartFragment := StartHTML + preStartBytes + mStartBytes
    EndFragment := StartHTML + preEndBytes

    fill10(x) => Format("{:010}", x)
    hdrFinal := RegExReplace(hdr, "StartHTML:\K##########", fill10(StartHTML))
    hdrFinal := RegExReplace(hdrFinal, "EndHTML:\K##########", fill10(EndHTML))
    hdrFinal := RegExReplace(hdrFinal, "StartFragment:\K##########", fill10(StartFragment))
    hdrFinal := RegExReplace(hdrFinal, "EndFragment:\K##########", fill10(EndFragment))

    fullFinal := hdrFinal . htmlDoc

    ; Final UTF-8 binary
    bin := StrToUtf8Buffer(fullFinal), dataSize := bin.Size - 1

    ; PlainText (compatibility) - UTF-16
    plain := plainText  ; Keep original text as-is
    ; UTF-16 requires charCount * 2 bytes
    reqW := StrPut(plain, "UTF-16") * 2
    plainBuf := Buffer(reqW), StrPut(plain, plainBuf, "UTF-16")

    ; Set clipboard data
    hHTML := DllCall("RegisterClipboardFormat", "str", "HTML Format", "uint")
    CF_UNICODETEXT := 13
    opened := false
    loop 5 {
        if DllCall("OpenClipboard", "ptr", 0, "int") {
            opened := true
            break
        }
        Sleep(30)
    }
    if !opened
        throw Error("OpenClipboard failed")

    try {
        DllCall("EmptyClipboard")

        GMEM_MOVEABLE := 0x0002, GMEM_ZEROINIT := 0x0040, GHND := GMEM_MOVEABLE | GMEM_ZEROINIT

        ; --- HTML data ---
        hMem := DllCall("GlobalAlloc", "uint", GHND, "uptr", dataSize + 1, "ptr")
        pMem := DllCall("GlobalLock", "ptr", hMem, "ptr")
        DllCall("RtlMoveMemory", "ptr", pMem, "ptr", bin.Ptr, "uptr", dataSize + 1)
        DllCall("GlobalUnlock", "ptr", hMem)
        if !DllCall("SetClipboardData", "uint", hHTML, "ptr", hMem, "ptr")
            throw Error("SetClipboardData(HTML) failed")

        ; --- UNICODETEXT ---
        hTxt := DllCall("GlobalAlloc", "uint", GHND, "uptr", plainBuf.Size, "ptr")
        pTxt := DllCall("GlobalLock", "ptr", hTxt, "ptr")
        DllCall("RtlMoveMemory", "ptr", pTxt, "ptr", plainBuf.Ptr, "uptr", plainBuf.Size)
        DllCall("GlobalUnlock", "ptr", hTxt)
        if !DllCall("SetClipboardData", "uint", CF_UNICODETEXT, "ptr", hTxt, "ptr")
            throw Error("SetClipboardData(TEXT) failed")
    } finally {
        DllCall("CloseClipboard")
    }
}
