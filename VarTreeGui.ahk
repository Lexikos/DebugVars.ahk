
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
class VarTreeGui extends TreeListView._Base
{
    static Instances := {} ; Hwnd:Object map of *visible* instances
    
    __New(RootNode) {
        Gui := GuiCreate("+Resize -DPIScale")
        Gui.OnEvent("Close", Func("VarTreeGuiClose"))
        Gui.OnEvent("Escape", Func("VarTreeGuiEscape"))
        Gui.OnEvent("Size", Func("VarTreeGuiSize"))
        Gui.OnEvent("ContextMenu", Func("VarTreeGuiContextMenu"))
        Gui.MarginX := 0
        Gui.MarginY := 0
        this.Gui := Gui
        this.TLV := new this.Control(Gui, RootNode
            , "w" 500*(A_ScreenDPI/96) " h" 300*(A_ScreenDPI/96) " LV0x10000 -LV0x10 -Multi", "Name|Value") ; LV0x10 = LVS_EX_HEADERDRAGDROP
    }
    
    class Control extends TreeListView
    {
        static COL_NAME := 1, COL_VALUE := 2
        
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
            base.ExpandContract(r)
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
            if (vtg := VarTreeGui.Instances[this.hGui]) && vtg.OnDoubleClick
                vtg.OnDoubleClick(node)
        }
    }
    
    Show(options:="") {
        this.RegisterHwnd()
        this.Gui.Show(options)
    }
    
    Hide() {
        this.Gui.Hide()
        this.UnregisterHwnd()
    }
    
    RegisterHwnd() {
        VarTreeGui.Instances[this.Gui.Hwnd] := this
    }
    
    UnregisterHwnd() {
        VarTreeGui.Instances.Delete(this.Gui.Hwnd)
    }
    
    __Delete() {
        this.Gui.Destroy()
    }
    
    ContextMenu(ctrl, eventInfo, isRightClick, x, y) {
        if (ctrl != this.TLV.LV || !this.OnContextMenu)
            return
        node := eventInfo ? this.TLV.NodeFromRow(eventInfo) : ""
        this.OnContextMenu(node, isRightClick, x, y)
    }
}

VarTreeGuiClose(Gui) {
    VarTreeGui.Instances[Gui.hwnd].UnregisterHwnd()
}

VarTreeGuiEscape(Gui) {
    VarTreeGui.Instances[Gui.hwnd].Hide()
}

VarTreeGuiSize(Gui, e, w, h) {
    Gui.Control["SysListView321"].Move("w" w " h" h)
    VarTreeGui.Instances[Gui.hwnd].TLV.AutoSizeValueColumn()
}

VarTreeGuiContextMenu(Gui, prms*) {
    VarTreeGui.Instances[Gui.hwnd].ContextMenu(prms*)
}
