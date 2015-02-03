/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Include <LV_EX>

test_names=
(
A_ScriptDir
A_ScriptName
A_ScriptFullPath
A_ScriptHwnd
A_Args
)
A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

global COL_NAME := 1, COL_VALUE := 2, COL_DATA := 3, ICON_SIZE := 16
global OBJECT_STRING := "(object)"

global hLV, hGui, hLVEdit
Gui Add, Edit, vLVEdit hwndhLVEdit Hidden
Gui Add, ListView, xp yp vLV gLV hwndhLV AltSubmit w500 h300
    ; LV styles: +LV0x10000 doublebuffer, -LV0x10 headerdragdrop
    +0x4000000 +LV0x10000 -LV0x10 -Multi NoSortHdr, Name|Value|Data
Gui -DPIScale +hwndhGui

il := DllCall("comctl32.dll\ImageList_Create", "int", ICON_SIZE, "int", ICON_SIZE
    , "uint", 0x21, "int", 2, "int", 5, "ptr")
IL_Add(il, "empty.png")
IL_Add(il, "plus.png")
IL_Add(il, "minus.png")
LV_SetImageList(il)

Loop Parse, test_names, `n
{
    InsertProp(A_Index, {name: A_LoopField, value: %A_LoopField%, level: 0})
}

LV_ModifyCol()
LV_ModifyCol(COL_DATA, 0)
AutoSizeValueColumn()

AutoSizeValueColumn(min_width:=0) {
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", hLV, "ptr", &rect)
    value_width := NumGet(rect,8,"int") - LV_EX_GetColumnWidth(hLV, COL_NAME)
    if (value_width < min_width)
        value_width := min_width
    LV_ModifyCol(COL_VALUE, value_width)
}

OnMessage(0x100, "OnKeyDown")
OnMessage(0x111, "OnWmCommand")
OnMessage(0x201, "OnLButtonDown")
OnMessage(0x203, "OnLButtonDown") ; DBLCLK
OnMessage(0x4E, "OnWmNotify")

Gui Show
return

GuiEscape:
GuiClose:
ExitApp

InsertProp(r, item) {
    opt := IsObject(item.value) ? "Icon" (item.expanded ? 3 : 2) : ""
    valueText := IsObject(item.value) ? OBJECT_STRING : item.value
    ObjAddRef(&item)
    LV_Insert(r, opt, item.name, valueText, &item)
    if item.level
        LV_EX_SetItemIndent(hLV, r, item.level)
    if item.expanded
        InsertChildren(r+1, item)
}
RemoveProp(r) {
    ObjRelease(&(item := LV_Data(r)))
    LV_Delete(r)
    RemoveChildren(r, item)
    return item
}
InsertChildren(r, item) {
    for _,child in item.children {
        InsertProp(r, child)
        r += 1 + Round(child.children.MaxIndex())
    }
}
RemoveChildren(r, item) {
    Loop % item.children.MaxIndex()
        RemoveProp(r)
}

LV:
LV()
return
LV() {
    if (A_GuiEvent = "s") ; S (start scroll) or s (stop scroll)
        if IsEditing()
            SaveEdit()
}
OnLButtonDown(wParam, lParam, msg, hwnd) {
    if (hwnd != hLV)
        return
    static LVM_SUBITEMHITTEST := 0x1039
    static LVHT_ONITEMICON := 2
    static LVHT_ONITEMLABEL := 4
    VarSetCapacity(hti, 24, 0)
    NumPut(lParam & 0xFFFF, hti, 0, "short")
    NumPut(lParam >> 16, hti, 4, "short")
    SendMessage LVM_SUBITEMHITTEST, 0, &hti,, ahk_id %hLV%
    where := NumGet(hti, 8, "int")
    r := NumGet(hti, 12, "int") + 1
    if (!r)
        return
    c := NumGet(hti, 16, "int") + 1
    if (where = LVHT_ONITEMICON) {
        GuiControl Focus, LV
        ExpandContract(r)
        return true
    }
    if (where = LVHT_ONITEMLABEL && c == COL_VALUE
        && LV_GetNext(r-1) == r) { ; Was already selected.
        ; && selection == r && (A_TickCount - selectedAt) > 100) {
        BeginEdit(r)
        return true
    }
}

LV_Data(r) {
    if LV_GetText(data, r, COL_DATA)
        return Object(data)
    throw Exception("Bad row", -1, r)
}

ExpandContract(r) {
    if !IsObject((item := LV_Data(r)).value)
        return
    GuiControl -Redraw, LV
    if item.expanded := !item.expanded {
        if !item.children {
            items := item.children := []
            level := item.level + 1
            for k,v in item.value
                items.Insert({name: k, value: v, level: level})
        }
        InsertChildren(r+1, item)
    } else {
        RemoveChildren(r+1, item)
    }
    LV_Modify(r, "Focus Icon" (2+item.expanded))
    GuiControl +Redraw, LV
}

global EditRow
BeginEdit(r) {
    EditRow := r
    item := LV_Data(r)
    static LVIR_LABEL := 2
    static LVM_GETSUBITEMRECT := 0x1038
    VarSetCapacity(rect, 16, 0)
    NumPut(LVIR_LABEL, rect, 0, "int")
    NumPut(COL_VALUE-1, rect, 4, "int")
    SendMessage LVM_GETSUBITEMRECT, r-1, &rect,, ahk_id %hLV%
    if !ErrorLevel
        return
    ; Scroll whole field into view if needed
    rL := NumGet(rect, 0, "int"), rR := NumGet(rect, 8, "int")
    VarSetCapacity(client_rect, 16, 0)
    DllCall("GetClientRect", "ptr", hLV, "ptr", &client_rect)
    client_width := NumGet(client_rect, 8, "int")
    if (rR > client_width) {
        delta := rR - client_width
        if (delta > rL)
            delta := rL
        static LVM_SCROLL := 0x1014
        SendMessage LVM_SCROLL, delta, 0,, ahk_id %hLV%
        NumPut(rL - delta, rect, 0, "int")
        NumPut(rR - delta, rect, 8, "int")
        Sleep 100
    }
    ; Convert coordinates
    DllCall("MapWindowPoints", "ptr", hLV, "ptr", hGui, "ptr", &rect, "uint", 2)
    rL := NumGet(rect, 0, "int"), rT := NumGet(rect, 4, "int")
    rR := NumGet(rect, 8, "int"), rB := NumGet(rect, 12, "int")
    rW := rR - rL - 2, rH := rB - rT, rL += 3, rR += 3
    ; Limit width to visible area when value column is very wide
    if (rW > client_width)
        rW := client_width
    ; Move the edit control into position and show it
    GuiControl,, LVEdit, % IsObject(item.value) ? OBJECT_STRING : item.value
    GuiControl Move, LVEdit, x%rL% y%rT% w%rW% h%rH%
    GuiControl Show, LVEdit
    GuiControl Focus, LVEdit
    static EM_SETSEL := 0xB1
    SendMessage EM_SETSEL, 0, -1,, ahk_id %hLVEdit%
}
CancelEdit() {
    EditRow := ""
    GuiControl Hide, LVEdit
}
SaveEdit() {
    if !EditRow
        throw Exception("Not editing", -1)
    r := EditRow
    GuiControlGet value,, LVEdit
    item := LV_Data(r)
    if IsObject(item.value) && value == OBJECT_STRING
        return CancelEdit()
    GuiControl -Redraw, LV
    EditRow := ""
    GuiControl Hide, LVEdit
    item.value := value
    RemoveProp(r)
    InsertProp(r, item)
    GuiControl +Redraw, LV
}
IsEditing() {
    return DllCall("IsWindowVisible", "ptr", hLVEdit)
    ; return (EditRow != "")
}

OnKeyDown(wParam, lParam) {
    if (A_GuiControl = "LVEdit") {
        static VK_RETURN := 0x0D
        if (wParam = VK_RETURN) {
            SaveEdit()
            return true
        }
        static VK_ESCAPE := 0x1B
        if (wParam = VK_ESCAPE) {
            CancelEdit()
            return true
        }
    }
    if (A_GuiControl = "LV") {
        static VK_F2 := 0x71
        if (wParam = VK_F2) {
            if r := LV_GetNext(0, "F")
                BeginEdit(r)
            return true
        }
    }
}

OnWmCommand(wParam, lParam) {
    static EN_KILLFOCUS := 0x200
    if (lParam = hLVEdit && (wParam >> 16) = EN_KILLFOCUS) {
        if IsEditing()
            SaveEdit()
        ;else: focus was killed as a result of cancelling.
    }
}

OnWmNotify(wParam, lParam) {
    Critical
    code := NumGet(lParam + A_PtrSize*2, "int")
    if (code = -306 || code = -326) { ; HDN_BEGINTRACK A|W
        item := NumGet(lParam + A_PtrSize*3, "int") + 1
        if (item = COL_NAME) {
            LV_ModifyCol(COL_VALUE) ; See below.
            return false
        }
        return true ; Prevent tracking.
    }
    if (code = -306 || code = -327) { ; HDN_ENDTRACK A|W
        ; This must be the Name column, since otherwise tracking was prevented.
        ; Auto-size the Value column so that it fills the available space, but
        ; don't shrink it smaller than the size set when tracking began above;
        ; i.e. the size of the widest value.  It was set when tracking began
        ; to avoid the effect of the scroll bar shrinking when tracking ends.
        AutoSizeValueColumn(LV_EX_GetColumnWidth(hLV, COL_VALUE))
        return true
    }
}

/*
; Not using this code for now since it requires Vista, and basically
; the only advantage is that the cursor doesn't change to <-> when you
; mouse over the column divider.
LV_ModifyCol(COL_DATA, 1)  ; Must be non-zero.
LVM_SETCOLUMN := 0x1000 + (A_IsUnicode ? 96 : 26)
LVCF_FMT := 1
LVCFMT_FIXED_WIDTH := 0x100
VarSetCapacity(lvcol, 40+A_PtrSize*2, 0)
NumPut(LVCF_FMT, lvcol, 0, "uint")
NumPut(LVCFMT_FIXED_WIDTH, lvcol, 4, "int")
SendMessage LVM_SETCOLUMN, COL_DATA-1, &lvcol,, ahk_id %hLV%
*/
