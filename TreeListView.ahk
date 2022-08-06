
class TreeListView
{
    static ICON_SIZE := 16
    
    static FromHwnd := ""  ; Hwnd:Object map of controls/instances
    
    ; MinEditColumn := 0 ; Disabled
    ; MaxEditColumn := 0
    
    static Prototype.EditRow := ""
    
    static InitClass() {
        if this.FromHwnd
            return
        this.FromHwnd := Map()
        this.FromHwnd.Default := ""
        
        il := DllCall("comctl32.dll\ImageList_Create"
            , "int", this.ICON_SIZE, "int", this.ICON_SIZE
            , "uint", 0x21, "int", 2, "int", 5, "ptr")
        IL_Add(il, A_LineFile "\..\empty.png")
        IL_Add(il, A_LineFile "\..\plus.png")
        IL_Add(il, A_LineFile "\..\minus.png")
        this.ImageList := il
        
        OnMessage(0x2, this.OnWmDestroy.Bind(this))
        OnMessage(0x100, this.OnWmKeyDown.Bind(this))
        OnMessage(0x111, this.OnWmCommand.Bind(this))
        OnMessage(0x201, lbd := this.OnWmLButtonDown.Bind(this))
        OnMessage(0x203, lbd) ; DBLCLK
        OnMessage(0x4E, this.OnWmNotify.Bind(this))
    }
    
    __New(Gui, RootNode, Options:="", Headers:=[" "," "]) {
        TreeListView.InitClass()
        
        this.root := RootNode
        RootNode.expanded := true
        
        this.hGui := Gui.Hwnd
        ; The requirements for the old ListView content to NOT appear momentarily
        ; when we hide the Edit control seem to be: 1) Edit is created first; and
        ; 2) ListView has WS_CLIPSIBLINGS (+0x4000000).
        this.Edit := Gui.AddEdit("Hidden "
            . (DllCall("GetWindow", "ptr", Gui.Hwnd, "uint", 5, "ptr")
                ? "xp yp wp yp" : "xm y0 w0 h0")) ; Preserve point of origin for LV
        this.LV := Gui.AddListView("NoSortHdr +0x4000000 " Options, Headers)
        this.hLV := this.LV.Hwnd
        this.hEdit := this.Edit.Hwnd
        
        static LVM_GETHEADER := 0x101F
        this.hLVH := SendMessage(LVM_GETHEADER,,,, this.hLV)
        
        this.CtrlName := Map(), this.CtrlName.CaseSense := "off"
        this.CtrlName[this.hLV] := "LV"
        this.CtrlName[this.hEdit] := "Edit"
        
        this.RegisterHwnd()
        
        ; Copy the ImageList, otherwise it gets destroyed the first time a ListView
        ; is destroyed.  LVS_SHAREIMAGELIST would let controls share the ImageList,
        ; but it's still destroyed when the last ListView is destroyed.
        this.LV.SetImageList(DllCall("comctl32.dll\ImageList_Duplicate", "ptr", TreeListView.ImageList, "ptr"))
        
        this.Populate()
    }
    
    ;{ Life Cycle
    
    RegisterHwnd() {
        TreeListView.FromHwnd[this.hLV] := this
        TreeListView.FromHwnd[this.hEdit] := this
        TreeListView.FromHwnd[this.hLVH] := this
    }
    
    UnregisterHwnd() {
        TreeListView.FromHwnd.Delete(this.hLV)
        TreeListView.FromHwnd.Delete(this.hEdit)
        TreeListView.FromHwnd.Delete(this.hLVH)
    }
    
    OnDestroy() {
        this.UnregisterHwnd()
    }
    
    ;}
    
    Populate() {
        r := 1
        for i, node in this.root.children {
            node.level := 0
            r := this.InsertRow(r, node)
        }
        this.AfterPopulate()
    }
    
    AfterPopulate() {
        this.LV.ModifyCol()
    }
    
    Reset() {
        this.LV.Delete()
        this.Populate()
    }
    
    ;{ Row Management
    
    InsertRow(r, node) {
        opt := node.expandable ? "Icon" (node.expanded ? 3 : 2) : ""
        this.LV.Insert(r, opt, node.values*)
        this.LV_SetItemParam(r, ObjPtr(node))
        if node.level
            this.LV_SetItemIndent(r, node.level)
        ++r
        if node.expanded
            r := this.InsertChildren(r, node)
        return r ; The row after the inserted items.
    }
    RemoveRow(r) {
        node := this.NodeFromRow(r)
        this.LV.Delete(r)
        if node.expanded
            this.RemoveChildren(r, node)
        return node
    }
    InsertChildren(r, node) {
        level := node.level + 1
        for _, child in node.children {
            child.level := level
            r := this.InsertRow(r, child)
        }
        return r
    }
    RemoveChildren(r, node) {
        Loop node.children.Length
            this.RemoveRow(r)
    }
    
    ExpandContract(r) {
        node := this.NodeFromRow(r)
        if !node.expandable
            return
        this.LV.opt("-Redraw")
        if node.expanded := !node.expanded
            this.InsertChildren(r+1, node)
        else
            this.RemoveChildren(r+1, node)
        this.LV.Modify(0, "-Select")
        this.LV.Modify(r, "Select Focus Icon" (2+node.expanded))
        this.LV.opt("+Redraw")
    }

    NodeFromRow(r) {
        if data := this.LV_GetItemParam(r)
            return ObjFromPtrAddRef(data)
        throw Error("Bad row", -1, r)
    }
    RowFromNode(obj) {
        return this.LV_FindItemParam(ObjPtr(obj))
    }
    
    ;}
    
    ;{ Tree Management
    
    InsertChild(parent, i, child) {
        if !IsObject(child)
            throw Error("Invalid child", -1, child)
        if i < parent.children.Length {
            ; Insert before this node
            r := this.RowFromNode(parent.children[i])
        }
        else if parent.expanded {
            ; Find the last visible descendent (parent if none)
            node := parent
            while (n := node.children.Length) && node.expanded
                node := node.children[n]
            ; Insert after this node (if RowFromNode returns 0, it's likely the root)
            r := this.RowFromNode(node) + 1
        }
        parent.children.InsertAt(i, child)
        child.level := (parent == this.root) ? 0 : parent.level + 1
        if IsSet(r)
            this.InsertRow(r, child)
    }
    RemoveChild(parent, i) {
        if !(child := parent.children.RemoveAt(i))
            throw Error("No child at index " i, -1)
        if (r := this.RowFromNode(child))
            this.RemoveRow(r)
    }
    
    ;}
    
    ;{ Editing
    
    CanEdit(row, column:="") {
        ; Note: row parameter is intended for derived implementations.
        return column = "" ; Default edit column
            ? (this.MinEditColumn > 0)
            : (column
            && column >= this.MinEditColumn
            && column <= this.MaxEditColumn)
    }
    BeginEdit(r, column:="") {
        if this.EditRow
            this.SaveEdit("NewEdit")
        if (column = "")
            column := this.MinEditColumn
        if !this.CanEdit(r, column)
            return false
        node := this.NodeFromRow(r)
        static LVIR_LABEL := 2
        static LVM_GETSUBITEMRECT := 0x1038
        rect := Buffer(16, 0)
        NumPut("int", LVIR_LABEL, rect, 0)
        NumPut("int", column-1, rect, 4)
        if !SendMessage(LVM_GETSUBITEMRECT, r-1, rect.ptr,, this.hLV)
            return false
        this.EditRow := r
        this.EditColumn := column
        ; Scroll whole field into view if needed
        rL := NumGet(rect, 0, "int"), rR := NumGet(rect, 8, "int")
        client_rect := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", this.hLV, "ptr", client_rect)
        client_width := NumGet(client_rect, 8, "int")
        if (rR > client_width) {
            delta := rR - client_width
            if (delta > rL)
                delta := rL
            static LVM_SCROLL := 0x1014
            SendMessage(LVM_SCROLL, delta, 0,, this.hLV)
            NumPut("int", rL - delta, rect, 0)
            NumPut("int", rR - delta, rect, 8)
            Sleep 100
        }
        ; Convert coordinates
        DllCall("MapWindowPoints", "ptr", this.hLV, "ptr", this.hGui, "ptr", rect, "uint", 2)
        rL := NumGet(rect, 0, "int"), rT := NumGet(rect, 4, "int")
        rR := NumGet(rect, 8, "int"), rB := NumGet(rect, 12, "int")
        rW := rR - rL - 2, rH := rB - rT
        if column > 1 ; Hack-tweak
            rL += 3, rR += 3
        ; Limit width to visible area when value column is very wide
        if (rW > client_width)
            rW := client_width
        ; Move the edit control into position and show it
        this.EditText := "" node.values[column]
        this.Edit.Value := this.EditText
        this.Edit.Move(rL, rT, rW, rH)
        this.Edit.Visible := true
        this.Edit.Focus()
        static EM_SETSEL := 0xB1
        SendMessage(EM_SETSEL, 0, -1,, this.hEdit)
        return true
    }
    CancelEdit() {
        this.EditRow := ""
        this.EditColumn := ""
        this.Edit.Visible := false
    }
    SaveEdit(reason:="") {
        if !(r := this.EditRow)
            throw Error("Not editing", -1)
        value := this.Edit.Value
        node := this.NodeFromRow(r)
        if this.EditText == "" value  ; Avoid erasing objects.
            return this.CancelEdit()
        c := this.EditColumn
        this.LV.opt("-Redraw")
        this.EditRow := ""
        this.EditColumn := ""
        this.Edit.Visible := false
        this.SetNodeValue(node, c, value)
        this.LV.opt("+Redraw")
    }
    IsEditing() {
        return this.Edit.Visible
    }
    
    SetNodeValue(node, column, value) {
        value := node.values[column] := value
        if r := this.RowFromNode(node)
            this.LV.Modify(r, "Col" column, value)
    }
    
    RefreshValues(node) {
        if r := this.RowFromNode(node) {
            opt := "Icon" (node.expandable ? (node.expanded ? 3 : 2) : 1)
            this.LV.Modify(r, opt, node.values*)
        }
    }
    
    ;}
    
    ;{ Keyboard Handling
    
    OnKeyDown(ctrl, key) {
        if !this.HasMethod(ctrl "_Key_" key)
            return
        if (ctrl = "LV") {
            if !(r := this.LV.GetNext(0, "F")) {
                if (key = "Tab") {
                    this.LV_Focus(1)
                    return true
                }
                return
            }
            node := this.NodeFromRow(r)
            return this.LV_Key_%key%(r, node)
        }
        return this.%ctrl%_Key_%key%()
    }
    
    Edit_Key_Enter() {
        this.SaveEdit()
        return true
    }
    
    Edit_Key_Tab() {
        delta := GetKeyState("Shift") ? -1 : 1
        return this.EditNextColumn(delta,, this.EditColumn)
            || this.EditNextRow(delta)
            || this.TabNextControl(delta)
    }
    
    Edit_Key_Up() {
        return this.EditNextRow(-1,, this.EditColumn)
    }
    
    Edit_Key_Down() {
        return this.EditNextRow(+1,, this.EditColumn)
    }
    
    Edit_Key_Escape() {
        this.CancelEdit()
        return true
    }
    
    LV_Key_Tab(r, node) {
        return this.Edit_Key_Tab()
    }
    
    LV_Key_Enter(r, node) {
        if !node.expandable && this.CanEdit(r, , node) {
            this.BeginEdit(r)
            return true
        }
        if node.expandable && !node.expanded
            this.ExpandContract(r)
        else if (r = this.LV.GetCount())
            return ; Allow default handling
        this.LV_Focus(r+1)
        return true
    }
    
    LV_Key_Left(r, node) {
        if node.expanded {
            this.ExpandContract(r)
            return true
        }
        loop
            r -= 1
        until r < 1 || this.NodeFromRow(r).level < node.level
        if r
            this.LV_Focus(r)
        return true
    }
    
    LV_Key_Right(r, node) {
        if node.expandable
            if node.expanded
                this.LV_Focus(r+1)
            else
                this.ExpandContract(r)
        return true
    }
    
    ;}
    
    ;{ Navigation
    
    EditNextColumn(delta:=1, r:="", c:="") {
        ; r and c specify the origin.
        ; If r is omitted, edit the cell after/before EditRow:EditColumn.
        ; Else if c is omitted, edit the first/last column of r.
        if (r == "")
            r := this.EditRow, (c != "") || (c := this.EditColumn)
        (r != "") || (r := this.LV.GetNext(,"F"))
        (c != "") || (c := delta>0 ? this.MinEditColumn-1 : this.MaxEditColumn+1)
        loop {
            c += delta
            if (c > this.MaxEditColumn || c < this.MinEditColumn)
                return
        }
        until this.CanEdit(r, c) ; Allow derived implementations to restrict editing further.
        this.LV_Focus(r)
        this.BeginEdit(r, c)
        return true
    }
    
    EditNextRow(delta:=1, r:="", c:="") {
        (r != "") || (r := this.EditRow) || (r := this.LV.GetNext(,"F"))
        count := this.LV.GetCount()
        loop {
            r += delta
            if (r > count || r < 1)
                return
        }
        until c="" ? this.EditNextColumn(delta, r) : this.BeginEdit(r, c)
        (c != "") && this.LV_Focus(r)
        return true
    }
    
    TabNextControl(delta:=1) {
        if ((current := DllCall("GetFocus", "ptr")) == 0 || delta>0 && current == this.hEdit)
            current := this.hLV  ; Tab to the next control after LV.
        if hwnd := DllCall("GetNextDlgTabItem", "ptr", this.hGui, "ptr", current, "int", delta<0, "ptr")
            return DllCall("SetFocus", "ptr", hwnd)
    }
    
    ;}
    
    ;{ General Control Functionality
    
    EnableRedraw(enable) {
        this.LV.opt((enable ? "+" : "-") "Redraw")
    }
    
    ScrollPos {
        get {
            return DllCall("GetScrollPos", "ptr", this.hLV, "int", 1)
        }
        set {
            static LVM_GETITEMPOSITION := 0x1010, LVM_SCROLL := 0x1014
            pt := Buffer(8, 0)
            SendMessage(LVM_GETITEMPOSITION, this.ScrollPos, pt.ptr,, this.hLV)
            oldPixelY := NumGet(pt, 4, "int")
            r := SendMessage(LVM_GETITEMPOSITION, value, pt.ptr,, this.hLV)
            newPixelY := NumGet(pt, 4, "int")
            if (r = 1)
                SendMessage(LVM_SCROLL, 0, newPixelY - oldPixelY,, this.hLV)
            return value
        }
    }
    
    FocusedNode {
        get {
            return (r := this.LV.GetNext(,"F")) ? this.NodeFromRow(r) : ""
        }
        set {
            if !(r := this.RowFromNode(value))
                return ""
            this.LV_Focus(r)
            return value
        }
    }
    
    ;}
    
    ;{ Static Message Handlers
    
    static OnWmDestroy(w, l, m, hwnd) {
        for h, tlv in this.FromHwnd.Clone()
            if (tlv.hGui == hwnd && tlv.hLV == h)
                tlv.OnDestroy()
    }
    
    static OnWmLButtonDown(wParam, lParam, msg, hwnd) {
        if !(this := this.FromHwnd[hwnd])
         || (hwnd != this.hLV)
            return
        static LVM_SUBITEMHITTEST := 0x1039
        static LVHT_ONITEMICON := 2
        static LVHT_ONITEMLABEL := 4
        hti := Buffer(24, 0)
        NumPut("short", lParam & 0xFFFF, hti, 0)
        NumPut("short", lParam >> 16, hti, 4)
        SendMessage(LVM_SUBITEMHITTEST, 0, hti.ptr,, this.hLV)
        where := NumGet(hti, 8, "int")
        r := NumGet(hti, 12, "int") + 1
        if (!r)
            return
        if (where = LVHT_ONITEMICON) {
            this.LV.Focus()
            this.ExpandContract(r)
            return true
        }
        if (where = LVHT_ONITEMLABEL && msg = 0x203 && this.HasProp('OnDoubleClick')) {
            if node := this.NodeFromRow(r)
                this.OnDoubleClick(node)
            return true
        }
        if (where = LVHT_ONITEMLABEL && this.LV.GetNext(r-1) == r) { ; Was already selected.
            c := NumGet(hti, 16, "int") + 1
            this.BeginEdit(r, c)
            return true
        }
    }
    
    static OnWmNotify(wParam, lParam, *) {
        Critical 1000
        hwndFrom := NumGet(lParam+0, "ptr")
        if !(this := this.FromHwnd[hwndFrom])
            return
        code := NumGet(lParam + A_PtrSize*2, "int")
        if (code = -180 || code = -181) { ; LVN_BEGINSCROLL || LVN_ENDSCROLL
            if this.IsEditing()
                this.SaveEdit("Scroll")
            return
        }
        if (code = -306 || code = -326) && this.BeforeHeaderResize { ; HDN_BEGINTRACK A|W
            column := NumGet(lParam + A_PtrSize*3, "int") + 1
            return this.BeforeHeaderResize(column)
        }
        if (code = -307 || code = -327) && this.AfterHeaderResize { ; HDN_ENDTRACK A|W
            column := NumGet(lParam + A_PtrSize*3, "int") + 1
            return this.AfterHeaderResize(column)
        }
    }
    
    static OnWmKeyDown(wParam, lParam, msg, hwnd) {
        if !(this := this.FromHwnd[hwnd])
        || !(ctrl := this.CtrlName[hwnd])
            return
        keyname := GetKeyName(Format("vk{:x}sc{:x}", wParam, (lParam >> 16) & 0x1FF))
        return this.OnKeyDown(ctrl, keyname)
    }
    
    static OnWmCommand(wParam, lParam, *) {
        if !(this := this.FromHwnd[lParam])
            return
        static EN_KILLFOCUS := 0x200
        if ((wParam >> 16) = EN_KILLFOCUS) {
            if this.IsEditing()
                this.SaveEdit("Focus")
            ;else: focus was killed as a result of cancelling.
        }
    }
    
    ;}
    
    ;{ ListView Utility
    
    LV_Focus(row) {
        this.LV.Modify(0, "-Select")
        this.LV.Modify(row, "Focus Select")
    }
    
    ; Based on LV_EX - http://ahkscript.org/boards/viewtopic.php?f=6&t=1256
    LV_GetColumnWidth(column) {
        static LVM_GETCOLUMNWIDTH := 0x101D
        return SendMessage(LVM_GETCOLUMNWIDTH, column-1, 0,, this.hLV)
    }
    LV_SetItemIndent(row, numIcons) {
        ; LVM_SETITEMA = 0x1006 -> http://msdn.microsoft.com/en-us/library/bb761186(v=vs.85).aspx
        static OffIndent := 24 + (A_PtrSize * 3)
        LVITEM := this.LV_LVITEM(0x00000010, row) ; LVIF_INDENT
        NumPut("Int", numIcons, LVITEM, OffIndent)
        return SendMessage(0x1006, 0, LVITEM.ptr, , this.hLV)
    }
    LV_GetItemParam(row) {
        ; LVM_GETITEM -> http://msdn.microsoft.com/en-us/library/bb774953(v=vs.85).aspx
        static LVM_GETITEM := 0x104B ; LVM_GETITEMW
        static OffParam := 24 + (A_PtrSize * 2)
        LVITEM := this.LV_LVITEM(0x00000004, row) ; LVIF_PARAM
        SendMessage(LVM_GETITEM, 0, LVITEM.ptr, , this.hLV)
        return NumGet(LVITEM, OffParam, "UPtr")
    }
    LV_SetItemParam(row, value) {
        ; LVM_SETITEMA = 0x1006 -> http://msdn.microsoft.com/en-us/library/bb761186(v=vs.85).aspx
        static OffParam := 24 + (A_PtrSize * 2)
        LVITEM := this.LV_LVITEM(0x00000004, row) ; LVIF_PARAM
        NumPut("UPtr", value, LVITEM, OffParam)
        return SendMessage(0x1006, 0, LVITEM.ptr, , this.hLV)
    }
    LV_FindItemParam(param, start := 0) { ; Based on LV_EX_FindString
        ; LVM_FINDITEMA = 0x100D -> http://msdn.microsoft.com/en-us/library/bb774903
        static LVFISize := 40
        LVFI := Buffer(LVFISize, 0) ; LVFINDINFO
        NumPut("UInt", 0x1, LVFI, 0) ; LVFI_PARAM
        NumPut("Ptr", param, LVFI, A_PtrSize * 2) ; lParam
        r := SendMessage(0x100D, (start - 1), LVFI.ptr, , this.hLV)
        return (r > 0x7FFFFFFF ? 0 : r + 1)
    }
    LV_LVITEM(mask := 0, row := 1, col := 1) {
        static LVITEMSize := 48 + (A_PtrSize * 3)
        LVITEM := Buffer(LVITEMSize, 0)
        NumPut("uint", mask, "int", row - 1, "int", col - 1, LVITEM)
        return LVITEM
    }
    
    ;}
}