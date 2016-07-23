
class DebugVars_Base
{
    __Call(name) {
        throw Exception("Unknown method", -1, name)
    }
}

/*
    DebugVars
    
    Public interface:
        dv := new DebugVars(RootNode)
        dv.Show()
        dv.Hide()
        dv.Reset()
        dv.EnableRedraw(enable)
        dv.OnContextMenu := Func(dv, node, isRightClick, x, y)
        dv.ScrollPos
        dv.FocusedItem
*/
class DebugVars extends DebugVars_Base
{
    static COL_NAME := 1, COL_VALUE := 2, ICON_SIZE := 16
    
    static Instances  ; Hwnd:Object map of visible instances.
    
    InitClass() {
        if this.Instances
            return
        this.Instances := {}
        
        il := DllCall("comctl32.dll\ImageList_Create"
            , "int", this.ICON_SIZE, "int", this.ICON_SIZE
            , "uint", 0x21, "int", 2, "int", 5, "ptr")
        IL_Add(il, A_LineFile "\..\empty.png")
        IL_Add(il, A_LineFile "\..\plus.png")
        IL_Add(il, A_LineFile "\..\minus.png")
        this.ImageList := il
        
        OnMessage(0x100, this.OnKeyDown.Bind(this))
        OnMessage(0x111, this.OnWmCommand.Bind(this))
        OnMessage(0x201, lbd := this.OnLButtonDown.Bind(this))
        OnMessage(0x203, lbd) ; DBLCLK
        OnMessage(0x4E, this.OnWmNotify.Bind(this))
    }
    
    __New(RootNode) {
        DebugVars.InitClass()
        this.root := RootNode
        
        restore_gui_on_return := new this.GuiScope()
        
        Gui New, hwndhGui LabelDebugVars_Gui +Resize
        Gui Margin, 0, 0
        Gui Add, Edit, hwndhLVEdit Hidden
        Gui Add, ListView, xp yp hwndhLV AltSubmit w500 h300
            ; LV styles: +LV0x10000 doublebuffer, -LV0x10 headerdragdrop
            +0x4000000 +LV0x10000 -LV0x10 -Multi NoSortHdr, Name|Value
        Gui -DPIScale
        
        this.hLV     := hLV
        this.hLVEdit := hLVEdit
        this.hGui    := hGui
        
        ; Copy the ImageList, otherwise it is destroyed with the first DebugVars GUI.
        ; LVS_SHAREIMAGELIST would let controls share the ImageList, but it's still
        ; destroyed when the last ListView is destroyed.
        LV_SetImageList(DllCall("comctl32.dll\ImageList_Duplicate", "ptr", DebugVars.ImageList, "ptr"))
        
        this.Populate()
        
        LV_ModifyCol(this.COL_NAME, 150)
        this.AutoSizeValueColumn()
    }
    
    Populate() {
        r := 1
        for i, node in this.root.children {
            node.level := 0
            r := this.InsertProp(r, node)
        }
    }
    
    Reset() {
        Gui % this.hGui ":Default"
        while LV_GetCount()
            this.RemoveProp(1)
        this.Populate()
    }
    
    Show(options:="", title:="") {
        DebugVars.Instances[this.hGui] := this
        Gui % this.hGui ":Show", % options, % title
    }
    
    Hide() {
        Gui % this.hGui ":Hide"
        DebugVars.RevokeHwnd(this.hGui)
    }
    
    RevokeHwnd(hwnd) {
        this.Instances.Delete(hwnd)
    }
    
    __Delete() {
        Gui % this.hGui ":Destroy"
    }
    
    AutoSizeValueColumn(min_width:=0) {
        VarSetCapacity(rect, 16, 0)
        DllCall("GetClientRect", "ptr", this.hLV, "ptr", &rect)
        value_width := NumGet(rect,8,"int") - this.LV_GetColumnWidth(this.COL_NAME)
        if (value_width < min_width)
            value_width := min_width
        LV_ModifyCol(this.COL_VALUE, value_width)
    }

    InsertProp(r, item) {
        opt := item.expandable ? "Icon" (item.expanded ? 3 : 2) : ""
        valueText := item.GetValueString()
        ObjAddRef(&item)
        LV_Insert(r, opt, item.name, valueText)
        this.LV_SetItemParam(r, &item)
        if item.level
            this.LV_SetItemIndent(r, item.level)
        ++r
        if item.expanded
            r := this.InsertChildren(r, item)
        return r ; The row after the inserted items.
    }
    RemoveProp(r) {
        ObjRelease(&(item := this.LV_Data(r)))
        LV_Delete(r)
        if item.expanded
            this.RemoveChildren(r, item)
        return item
    }
    InsertChildren(r, item) {
        level := item.level + 1
        for _, child in item.children {
            child.level := level
            r := this.InsertProp(r, child)
        }
        return r
    }
    RemoveChildren(r, item) {
        Loop % item.children.Length()
            this.RemoveProp(r)
    }
    
    OnLButtonDown(wParam, lParam, msg, hwnd) {
        if !(this := this.Instances[A_Gui+0])
            return
        if (hwnd != this.hLV)
            return
        static LVM_SUBITEMHITTEST := 0x1039
        static LVHT_ONITEMICON := 2
        static LVHT_ONITEMLABEL := 4
        VarSetCapacity(hti, 24, 0)
        NumPut(lParam & 0xFFFF, hti, 0, "short")
        NumPut(lParam >> 16, hti, 4, "short")
        SendMessage % LVM_SUBITEMHITTEST, 0, % &hti,, % "ahk_id " this.hLV
        where := NumGet(hti, 8, "int")
        r := NumGet(hti, 12, "int") + 1
        if (!r)
            return
        c := NumGet(hti, 16, "int") + 1
        if (where = LVHT_ONITEMICON) {
            GuiControl Focus, % this.hLV
            this.ExpandContract(r)
            return true
        }
        if (where = LVHT_ONITEMLABEL && c == this.COL_VALUE
            && LV_GetNext(r-1) == r) { ; Was already selected.
            this.BeginEdit(r)
            return true
        }
        if (where = LVHT_ONITEMLABEL && msg = 0x203 && this.OnDoubleClick) {
            if node := this.LV_Data(r)
                this.OnDoubleClick(node)
        }
    }

    LV_Data(r) {
        if data := this.LV_GetItemParam(r)
            return Object(data)
        throw Exception("Bad row", -1, r)
    }
    LV_FindData(obj) {
        return this.LV_FindItemParam(&obj)
    }

    ExpandContract(r) {
        item := this.LV_Data(r)
        if !item.expandable
            return
        GuiControl -Redraw, % this.hLV
        if item.expanded := !item.expanded
            this.InsertChildren(r+1, item)
        else
            this.RemoveChildren(r+1, item)
        LV_Modify(r, "Select Focus Icon" (2+item.expanded))
        GuiControl +Redraw, % this.hLV
        ; Adjust value column in case a vertical scrollbar was just added/removed.
        ; This only works after redraw.
        this.AutoSizeValueColumn()
    }

    BeginEdit(r) {
        this.EditRow := r
        item := this.LV_Data(r)
        static LVIR_LABEL := 2
        static LVM_GETSUBITEMRECT := 0x1038
        VarSetCapacity(rect, 16, 0)
        NumPut(LVIR_LABEL, rect, 0, "int")
        NumPut(this.COL_VALUE-1, rect, 4, "int")
        SendMessage % LVM_GETSUBITEMRECT, % r-1, % &rect,, % "ahk_id " this.hLV
        if !ErrorLevel
            return
        ; Scroll whole field into view if needed
        rL := NumGet(rect, 0, "int"), rR := NumGet(rect, 8, "int")
        VarSetCapacity(client_rect, 16, 0)
        DllCall("GetClientRect", "ptr", this.hLV, "ptr", &client_rect)
        client_width := NumGet(client_rect, 8, "int")
        if (rR > client_width) {
            delta := rR - client_width
            if (delta > rL)
                delta := rL
            static LVM_SCROLL := 0x1014
            SendMessage % LVM_SCROLL, % delta, 0,, % "ahk_id " this.hLV
            NumPut(rL - delta, rect, 0, "int")
            NumPut(rR - delta, rect, 8, "int")
            Sleep 100
        }
        ; Convert coordinates
        DllCall("MapWindowPoints", "ptr", this.hLV, "ptr", this.hGui, "ptr", &rect, "uint", 2)
        rL := NumGet(rect, 0, "int"), rT := NumGet(rect, 4, "int")
        rR := NumGet(rect, 8, "int"), rB := NumGet(rect, 12, "int")
        rW := rR - rL - 2, rH := rB - rT, rL += 3, rR += 3
        ; Limit width to visible area when value column is very wide
        if (rW > client_width)
            rW := client_width
        ; Move the edit control into position and show it
        this.EditText := item.expandable
            ? (LV_GetText(value, r, this.COL_VALUE) ? value : "")
            : item.value
        GuiControl,, % this.hLVEdit, % this.EditText
        GuiControl Move, % this.hLVEdit, x%rL% y%rT% w%rW% h%rH%
        GuiControl Show, % this.hLVEdit
        GuiControl Focus, % this.hLVEdit
        static EM_SETSEL := 0xB1
        SendMessage % EM_SETSEL, 0, -1,, % "ahk_id " this.hLVEdit
    }
    CancelEdit() {
        this.EditRow := ""
        GuiControl Hide, % this.hLVEdit
    }
    SaveEdit() {
        if !r := this.EditRow
            throw Exception("Not editing", -1)
        GuiControlGet value,, % this.hLVEdit
        node := this.LV_Data(r)
        if this.EditText == "" value  ; Avoid erasing objects.
            return this.CancelEdit()
        GuiControl -Redraw, % this.hLV
        this.EditRow := ""
        GuiControl Hide, % this.hLVEdit
        if node.SetValue(value) != 0
        {
            this.RemoveProp(r)
            node.children := ""     ; Clear any cached children.
            node.expanded := false  ; Since value is a string, node can't be expanded.
            this.InsertProp(r, node)
        }
        GuiControl +Redraw, % this.hLV
    }
    IsEditing() {
        return DllCall("IsWindowVisible", "ptr", this.hLVEdit)
    }

    OnKeyDown(wParam, lParam, msg, hwnd) {
        if !(this := this.Instances[A_Gui+0])
            return
        key := GetKeyName(vksc := Format("vk{:x}sc{:x}", wParam, (lParam >> 16) & 0x1FF))
        if (hwnd = this.hLV) {
            ctrl := "LV"
            if !(r := LV_GetNext(0, "F")) {
                if (key = "Tab") {
                    LV_Modify(1, "Select Focus")
                    return true
                }
                return
            }
            node := this.LV_Data(r)
        }
        else if (hwnd = this.hLVEdit) {
            ctrl := "LVEdit"
        }
        if IsFunc(this[ctrl "_" key])
            return this[ctrl "_" key](r, node)
    }
    LVEdit_Enter() {
        return this.LVEdit_Tab()
    }
    LVEdit_Tab() {
        r := this.EditRow
        this.SaveEdit()
        if !(GetKeyState("Shift") || r=LV_GetCount())
            r += 1
        LV_Modify(r, "Select Focus")
        return true
    }
    LVEdit_Escape() {
        this.CancelEdit()
        return true
    }
    LV_Tab(r, node) {
        if GetKeyState("Shift") {
            if (r = 1)
                return
            LV_Modify(--r, "Select Focus")
            if !this.LV_Data(r).expandable
                this.BeginEdit(r)
            return true
        }
        return this.LV_Enter(r, node)
    }
    LV_Enter(r, node) {
        if !node.expandable {
            this.BeginEdit(r)
            return true
        }
        if !node.expanded
            this.ExpandContract(r)
        LV_Modify(r+1, "Select Focus")
        return true
    }
    LV_Left(r, node) {
        if node.expanded {
            this.ExpandContract(r)
            return true
        }
        loop
            r -= 1
        until r < 1 || this.LV_Data(r).level < node.level
        if r
            LV_Modify(r, "Select Focus")
        return true
    }
    LV_Right(r, node) {
        if node.expandable
            if node.expanded
                LV_Modify(r+1, "Select Focus")
            else
                this.ExpandContract(r)
        return true
    }

    OnWmCommand(wParam, lParam) {
        if !(this := this.Instances[A_Gui+0])
            return
        static EN_KILLFOCUS := 0x200
        if (lParam = this.hLVEdit && (wParam >> 16) = EN_KILLFOCUS) {
            if this.IsEditing()
                this.SaveEdit()
            ;else: focus was killed as a result of cancelling.
        }
    }

    OnWmNotify(wParam, lParam) {
        Critical
        if !(this := this.Instances[A_Gui+0])
            return
        code := NumGet(lParam + A_PtrSize*2, "int")
        if (code = -180 || code = -181) { ; LVN_BEGINSCROLL || LVN_ENDSCROLL
            if this.IsEditing()
                this.SaveEdit()
            return
        }
        if (code = -306 || code = -326) { ; HDN_BEGINTRACK A|W
            column := NumGet(lParam + A_PtrSize*3, "int") + 1
            if (column = this.COL_NAME) {
                LV_ModifyCol(this.COL_VALUE) ; See below.
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
            this.AutoSizeValueColumn(this.LV_GetColumnWidth(this.COL_VALUE))
            return true
        }
    }
    
    ContextMenu(ctrlHwnd, eventInfo, isRightClick, x, y) {
        if (ctrlHwnd != this.hLV || !this.OnContextMenu)
            return
        node := eventInfo ? this.LV_Data(eventInfo) : ""
        this.OnContextMenu(node, isRightClick, x, y)
    }
    
    EnableRedraw(enable) {
        GuiControl % (enable ? "+" : "-") "Redraw", % this.hLV
    }
    
    ; Based on LV_EX - http://ahkscript.org/boards/viewtopic.php?f=6&t=1256
    LV_GetColumnWidth(column) {
        static LVM_GETCOLUMNWIDTH := 0x101D
        SendMessage % LVM_GETCOLUMNWIDTH, % column-1, 0,, % "ahk_id " this.hLV
        return ErrorLevel
    }
    LV_SetItemIndent(row, numIcons) {
        ; LVM_SETITEMA = 0x1006 -> http://msdn.microsoft.com/en-us/library/bb761186(v=vs.85).aspx
        static OffIndent := 24 + (A_PtrSize * 3)
        this.LV_LVITEM(LVITEM, 0x00000010, row) ; LVIF_INDENT
        NumPut(numIcons, LVITEM, OffIndent, "Int")
        SendMessage, 0x1006, 0, % &LVITEM, , % "ahk_id " this.hLV
        return ErrorLevel
    }
    LV_GetItemParam(row) {
        ; LVM_GETITEM -> http://msdn.microsoft.com/en-us/library/bb774953(v=vs.85).aspx
        static LVM_GETITEM := A_IsUnicode ? 0x104B : 0x1005 ; LVM_GETITEMW : LVM_GETITEMA
        static OffParam := 24 + (A_PtrSize * 2)
        this.LV_LVITEM(LVITEM, 0x00000004, row) ; LVIF_PARAM
        SendMessage, % LVM_GETITEM, 0, % &LVITEM, , % "ahk_id " this.hLV
        return NumGet(LVITEM, OffParam, "UPtr")
    }
    LV_SetItemParam(row, value) {
        ; LVM_SETITEMA = 0x1006 -> http://msdn.microsoft.com/en-us/library/bb761186(v=vs.85).aspx
        static OffParam := 24 + (A_PtrSize * 2)
        this.LV_LVITEM(LVITEM, 0x00000004, row) ; LVIF_PARAM
        NumPut(value, LVITEM, OffParam, "UPtr")
        SendMessage, 0x1006, 0, % &LVITEM, , % "ahk_id " this.hLV
        return ErrorLevel
    }
    LV_LVITEM(ByRef LVITEM, mask := 0, row := 1, col := 1) {
        static LVITEMSize := 48 + (A_PtrSize * 3)
        VarSetCapacity(LVITEM, LVITEMSize, 0)
        NumPut(mask, LVITEM, 0, "UInt"), NumPut(row - 1, LVITEM, 4, "Int"), NumPut(col - 1, LVITEM, 8, "Int")
    }
    LV_FindItemParam(param, start := 0) { ; Based on LV_EX_FindString
        ; LVM_FINDITEMA = 0x100D -> http://msdn.microsoft.com/en-us/library/bb774903
        static LVFISize := 40
        VarSetCapacity(LVFI, LVFISize, 0) ; LVFINDINFO
        NumPut(0x1, LVFI, 0, "UInt") ; LVFI_PARAM
        NumPut(param, LVFI, A_PtrSize * 2, "Ptr") ; lParam
        SendMessage, 0x100D, % (start - 1), % &LVFI, , % "ahk_id " this.hLV
        return (ErrorLevel > 0x7FFFFFFF ? 0 : ErrorLevel + 1)
    }
    
    class GuiScope {
        __New() {
            this.last_found := WinExist()
            Gui +LastFoundExist  ; Limitation: Setting default Gui name without creating Gui won't work.
            this.last_gui := WinExist()
        }
        __Delete() {
            if (last_gui := this.last_gui) && DllCall("IsWindow", "ptr", last_gui)
                Gui %last_gui%: Default
            else
                Gui 1: Default  ; Just a guess; better than leaving our Gui as default.
            if last_found := this.last_found
                WinExist("ahk_id " last_found)
        }
    }
    
    ScrollPos {
        get {
            return DllCall("GetScrollPos", "ptr", this.hLV, "int", 1)
        }
        set {
            static LVM_GETITEMPOSITION := 0x1010, LVM_SCROLL := 0x1014
            VarSetCapacity(pt, 8, 0)
            SendMessage % LVM_GETITEMPOSITION, % this.ScrollPos, % &pt,, % "ahk_id " this.hLV
            oldPixelY := NumGet(pt, 4, "int")
            SendMessage % LVM_GETITEMPOSITION, % value, % &pt,, % "ahk_id " this.hLV
            newPixelY := NumGet(pt, 4, "int")
            if (ErrorLevel = 1)
                SendMessage % LVM_SCROLL, 0, % newPixelY - oldPixelY,, % "ahk_id " this.hLV
            return value
        }
    }
    
    FocusedItem {
        get {
            restore_gui_on_return := new this.GuiScope()
            Gui % this.hGui ":Default"
            return (r := LV_GetNext(,"F")) ? this.LV_Data(r) : ""
        }
        set {
            restore_gui_on_return := new this.GuiScope()
            Gui % this.hGui ":Default"
            if !(r := this.LV_FindData(value))
                return ""
            LV_Modify(r, "Focus Select")
            return value
        }
    }
}

DebugVars_GuiClose(hwnd) {
    DebugVars.RevokeHwnd(hwnd)
}

DebugVars_GuiEscape(hwnd) {
    DebugVars.Instances[hwnd].Hide()
}

DebugVars_GuiSize(hwnd, e, w, h) {
    GuiControl Move, SysListView321, w%w% h%h%
    DebugVars.Instances[hwnd].AutoSizeValueColumn()
}

DebugVars_GuiContextMenu(hwnd, prms*) {
    DebugVars.Instances[hwnd].ContextMenu(prms*)
}
