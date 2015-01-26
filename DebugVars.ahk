/*
TODO:
  hide Data column and prevent showing it (use HDN_BEGINTRACK notification)

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
A_Args := [["A","B"],["C",["D"],"E"]]

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
    InsertProp(A_Index, A_LoopField, %A_LoopField%)
}
LV_ModifyCol()

OnMessage(0x100, "OnKeyDown")
OnMessage(0x111, "OnWmCommand")
OnMessage(0x201, "OnLButtonDown")
OnMessage(0x203, "OnLButtonDown") ; DBLCLK

Gui Show
return

GuiEscape:
GuiClose:
ExitApp

InsertProp(r, name, value, level:=0) {
    opt := IsObject(value) ? "Icon2" : ""
    valueText := IsObject(value) ? OBJECT_STRING : value
    data := {value: value, level: level}
    ObjAddRef(&data)
    LV_Insert(r, opt, name, valueText, &data)
    if level
        LV_EX_SetItemIndent(hLV, r, level)
}
DeleteProp(r) {
    ObjRelease(&(item := LV_Data(r)))
    LV_Delete(r)
    Loop % item.numChildren
        DeleteProp(r)
    return data
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
    GuiControl, -Redraw, LV
    if item.expanded := !item.expanded {
        n := 0, level := item.level + 1
        for k,v in item.value
            InsertProp(r+(++n), k, v, level)
        item.numChildren := n
    } else {
        Loop % item.numChildren
            child := DeleteProp(r+1)
        item.numChildren := 0
    }
    LV_Modify(r, "Icon" (2+item.expanded))
    GuiControl, +Redraw, LV
}

global EditRow
BeginEdit(r) {
    EditRow := r
    item := LV_Data(r)
    static LVIR_LABEL := 2
    static LVM_GETSUBITEMRECT := 0x1038
    VarSetCapacity(RECT, 16, 0)
    NumPut(LVIR_LABEL, RECT, 0, "int")
    NumPut(COL_VALUE-1, RECT, 4, "int")
    SendMessage LVM_GETSUBITEMRECT, r-1, &RECT,, ahk_id %hLV%
    if !ErrorLevel
        return
    DllCall("MapWindowPoints", "ptr", hLV, "ptr", hGui, "ptr", &RECT, "uint", 2)
    rL := NumGet(RECT, 0, "int"), rT := NumGet(RECT, 4, "int")
    rR := NumGet(RECT, 8, "int"), rB := NumGet(RECT, 12, "int")
    rW := rR - rL, rH := rB - rT, rL++, rR++
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
    GuiControl, -Redraw, LV
    EditRow := ""
    GuiControl Hide, LVEdit
    item.value := value
    LV_GetText(name, r, COL_NAME)
    DeleteProp(r)
    InsertProp(r, name, item.value, item.level)
    GuiControl, +Redraw, LV
}
IsEditing() {
    ; return DllCall("IsWindowVisible", "ptr", hLVEdit)
    return (EditRow != "")
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