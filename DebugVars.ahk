/*
TODO:
  enable editing of value
    a) swap positions of columns 1 and 2 and add -ReadOnly
       - put image in column 2 via LVS_EX_SUBITEMIMAGES and LVM_SETITEM
    b) use LVM_GETSUBITEMRECT to position an edit control
       - handle F2, dbl/click, scroll (to hide edit)
  look into LV_SortArrow
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

global DATA_COLUMN := 3, ICON_SIZE := 16
global hLV
Gui Add, ListView, vLV gLV hwndhLV AltSubmit w500 h300, Name|Value|Data

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

Gui Show
return

GuiClose:
GuiEscape:
ExitApp

InsertProp(r, name, value, level:=0) {
    opt := IsObject(value) ? "Icon2" : ""
    valueText := IsObject(value) ? "(object)" : value
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
    if (A_GuiEvent != "Normal" && A_GuiEvent != "DoubleClick")
        return
    static LVM_SUBITEMHITTEST := 0x1039, LVHT_ONITEMICON := 2
    VarSetCapacity(hti, 24, 0)
    DllCall("GetCursorPos", "ptr", &hti)
    DllCall("ScreenToClient", "ptr", hLV, "ptr", &hti)
    SendMessage LVM_SUBITEMHITTEST, 0, &hti,, ahk_id %hLV%
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
    static WM_SETREDRAW := 0x000B
    SendMessage WM_SETREDRAW, false,,, ahk_id %hLV%
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
    SendMessage WM_SETREDRAW, true,,, ahk_id %hLV%
}
