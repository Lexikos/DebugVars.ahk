/*
TODO:
  enable editing of value
    a) swap positions of columns 1 and 2 and add -ReadOnly
       - put image in column 2 via LVS_EX_SUBITEMIMAGES and LVM_SETITEM
    b) use LVM_GETSUBITEMRECT to position an edit control
       - handle F2, dbl/click, scroll (to hide edit)
  indent child items via LVITEM.iIndent
  look into LV_SortArrow
  hide Data column and prevent showing it (use HDN_BEGINTRACK notification)
  disable redraw while deleting items

*/

test_names=
(
A_ScriptDir
A_ScriptName
A_ScriptFullPath
A_ScriptHwnd
A_Args
)
A_Args := [[42]]

global DATA_COLUMN := 3
Gui Add, ListView, vLV gLV AltSubmit w500 h300, Name|Value|Data

il := DllCall("comctl32.dll\ImageList_Create", "int", 11, "int", 11
    , "uint", 0x21, "int", 2, "int", 5, "ptr")
IL_Add(il, "empty.png")
IL_Add(il, "plus.png")
IL_Add(il, "minus.png")
LV_SetImageList(il)

global LV_Data := []
LVx_Add(value, args*) {
    r := LV_Add(args*)
    LV_Data[r] := {value: value}
    return r
}
LVx_Insert(r, value, args*) {
    LV_Data.Insert(r, {value: value})
    return LV_Insert(r, args*)
}
LVx_Delete(r) {
    LV_Data.Remove(r)
    return LV_Delete(r)
}

Loop Parse, test_names, `n
{
    InsertProp(A_Index, A_LoopField, %A_LoopField%)
}
LV_ModifyCol()

InsertProp(r, name, value) {
    opt := IsObject(value) ? "Icon2" : ""
    valueText := IsObject(value) ? "(object)" : value
    data := {value: value}, ObjAddRef(&data)
    LV_Insert(r, opt, name, valueText, &data)
}
DeleteProp(r) {
    ObjRelease(&(item := LV_Data(r)))
    LV_Delete(r)
    Loop % item.numChildren
        DeleteProp(r)
    return data
}

InsertObj(r, obj) {
    n := 0
    for k,v in obj  {
        InsertProp(r+(n++), k, v)
    }
    return n
}

LV() {
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick")
        return
    static LVM_SUBITEMHITTEST := 0x1039, LVHT_ONITEMICON := 2
    GuiControlGet hwnd, Hwnd, LV
    VarSetCapacity(hti, 24, 0)
    DllCall("GetCursorPos", "ptr", &hti)
    DllCall("ScreenToClient", "ptr", hwnd, "ptr", &hti)
    SendMessage LVM_SUBITEMHITTEST, 0, &hti,, ahk_id %hwnd%
    if NumGet(hti, 8, "int") = LVHT_ONITEMICON {
        r0 := NumGet(hti, 12, "int")
        if r0 >= 0
            ExpandContract(r0+1)
    }
}

LV_Data(r) {
    if LV_GetText(data, r, DATA_COLUMN)
        return Object(data)
}

ExpandContract(r) {
    if !IsObject((item := LV_Data(r)).value)
        return
    item.expanded := !item.expanded
    LV_Modify(r, "Icon" (2+item.expanded))
    if item.expanded {
        item.numChildren := InsertObj(r+1, item.value)
    } else {
        Loop % item.numChildren {
            child := DeleteProp(r+1)
        }
            
    }
}

Gui Show

GuiClose() {
    ExitApp
}