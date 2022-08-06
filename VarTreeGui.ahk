
#Include TreeListView.ahk

/*
    VarTreeGui
    
    Public interface:
        vtg := new VarTreeGui(RootNode)
        vtg.TLV
        vtg.Show()
        vtg.Hide()
        vtg.OnContextMenu := Func(vtg, node, isRightClick, x, y)
        vtg.OnDoubleClick := Func(vtg, node)
*/
class VarTreeGui extends Gui
{
    __New(RootNode) {
        super.__New("+Resize -DPIScale",, this)
        this.OnEvent("Escape", "Hide")
        this.OnEvent("Size", "Resized")
        this.OnEvent("ContextMenu", "ContextMenu")
        this.MarginX := 0
        this.MarginY := 0
        this.TLV := VarTreeGui.Control(this, RootNode
            , "w" 500*(A_ScreenDPI/96) " h" 300*(A_ScreenDPI/96) " LV0x10000 -LV0x10 -Multi", ["Name","Value"]) ; LV0x10 = LVS_EX_HEADERDRAGDROP
    }
    
    class Control extends TreeListView
    {
        static prototype.COL_NAME := 1, prototype.COL_VALUE := 2
        
        MinEditColumn := 2
        MaxEditColumn := 2
        
        AutoSizeValueColumn() {
            this.LV.ModifyCol(this.COL_VALUE, "AutoHdr")
        }
        
        AfterPopulate() {
            this.LV.ModifyCol(this.COL_NAME, 150*(A_ScreenDPI/96))
            this.AutoSizeValueColumn()
            if !this.LV.GetNext(,"F")
                this.LV.Modify(1, "Focus")
        }
        
        ExpandContract(r) {
            super.ExpandContract(r)
            this.AutoSizeValueColumn()  ; Adjust for +/-scrollbars
        }
        
        BeforeHeaderResize(column) {
            if (column != this.COL_NAME)
                return true
            ; Collapse to fit just the value so that scrollbars will be
            ; visible only when needed.
            this.LV.ModifyCol(this.COL_VALUE, "Auto")
        }
        
        AfterHeaderResize(column) {
            this.AutoSizeValueColumn()
        }
        
        SetNodeValue(node, column, value) {
            if (column != this.COL_VALUE)
                return
            if (node.SetValue(value) = 0)
                return
            if !(r := this.RowFromNode(node))
                return
            this.LV.Modify(r, "Col" column, value)
            if (!node.expandable && node.children) {
                ; Since value is a string, node can't be expanded
                this.LV.Modify(r, "Icon1")
                this.RemoveChildren(r+1, node)
                node.children := ""
                node.expanded := false
            }
        }
        
        OnDoubleClick(node) {
            g := GuiFromHwnd(this.hGui)
            if g && g.HasMethod('OnDoubleClick')
                g.OnDoubleClick(node)
        }
    }
    
    ContextMenu(ctrl, eventInfo, isRightClick, x, y) {
        if (ctrl != this.TLV.LV || !this.HasMethod('OnContextMenu'))
            return
        node := eventInfo ? this.TLV.NodeFromRow(eventInfo) : ""
        this.OnContextMenu(node, isRightClick, x, y)
    }
    
    Resized(e, w, h) {
        this["SysListView321"].Move(,, w, h)
        this.TLV.AutoSizeValueColumn()
    }
}
