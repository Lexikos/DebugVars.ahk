
/*
    VarEditGui
    
    Public interface:
        ed := new VarEditGui({Name, Value, Type, ReadOnly})
        ed.SetVar({Name, Value, Type, ReadOnly)
        ed.Show()
        ed.Cancel()
        ed.Hide()
        ed.OnSave := Func(ed, value, type)
        ed.OnDirty := Func(ed)
        ed.OnCancel := Func(ed)
*/
class VarEditGui {
    __New(aVar:="") {
        editOpt := ""
        if aVar && (aVar.type = "integer" || aVar.type = "float")
            editOpt := "r1 Multi" ; Default to one line.
        this.CreateGui(editOpt)
        if aVar
            this.SetVar(aVar)
    }
    
    SetVar(aVar) {
        this.Dirty := false
        this.Var := aVar
        this.cSave.Enabled := false
        
        type := aVar.type
        value := aVar.value
        readonly := aVar.readonly
        
        if readonly
            types := type
        else {
            ; 'undefined' can't be set by the user, but may be the initial type
            types := (type = "undefined" ? "undefined|" : "") "string"
            if VarEditGui_isInt64(value)
                types .= "|integer" (InStr(value,"0x") ? "" : "|float")
            else if VarEditGui_isFloat(value)
                types .= "|float"
        }
        this.cType.Add(types)
        this.cType.Choose(type)
        this.preferredType := type
        
        this.cEdit.Opt((readonly ? "+" : "-") "ReadOnly")
        
        this.cEdit.Value := value
        
        this[InStr(value,"`r`n") ? "cCRLF" : "cLF"].Value := true
        this.DisEnableEOLControls(value, readonly)
        this.CheckWantReturn(type)
        
        this.UpdateTitle()
    }
    
    CreateGui(editOpt:="") {
        Gui := GuiCreate("+Resize")
        Gui.OnEvent("Close", "VarEditGui_OnClose")
        Gui.OnEvent("Escape", "VarEditGui_OnEscape")
        Gui.OnEvent("Size", "VarEditGui_OnSize")
        this.Gui := Gui
        
        this.cEdit := Gui.AddEdit("w300 r10 " editOpt)
        this.cEdit.OnEvent("Change", (ctrl) => VarEditGui.Instances[ctrl.Gui.Hwnd].ChangeValue())
        
        pos := this.cEdit.Pos
        this.marginX := pos.X, this.marginY := pos.Y
        
        this.cType := Gui.AddDDL("w70", "undefined||")
        this.cType.OnEvent("Change", (ctrl) => VarEditGui.Instances[ctrl.Gui.Hwnd].ChangeType())
        
        cH := this.cType.Pos.H
        this.footerH := cH
        
        this.cLF := Gui.AddRadio("x+m h" cH, "LF")
        this.cCRLF := Gui.AddRadio("x+0 h" cH, "CR+LF")
        fn := (ctrl) => VarEditGui.Instances[ctrl.Gui.Hwnd].ChangeEOL()
        this.cLF.OnEvent("Click", fn)
        this.cCRLF.OnEvent("Click", fn)
        
        this.cSave := Gui.AddButton("x+m Disabled", "&Save")
        this.cSave.OnEvent("Click", (ctrl) => VarEditGui.Instances[ctrl.Gui.Hwnd].SaveEdit())
        
        pos := this.cSave.Pos
        pos.X += pos.W + this.marginX
        Gui.Opt("+MinSize" pos.X "x")
    }
    
    Show(options:="") {
        VarEditGui.Instances[this.Gui.Hwnd] := this
        this.Gui.Show(options)
    }
    
    Cancel() {
        if this.Dirty
            this.CancelEdit()
        else
            this.Hide()
    }
    
    Hide() {
        this.Gui.Hide()
        VarEditGui.RevokeHwnd(this.Gui.Hwnd)
    }
    
    RevokeHwnd(hwnd) {
        this.Instances.Delete(hwnd)
    }
    
    __Delete() {
        this.Gui.Destroy()
    }
    
    GuiSize(w, h) {
        cW := w - this.marginX*2
        cH := h - this.marginY*3 - this.footerH
        this.cEdit.Move("w" cW " h" cH)
        y := cH + this.marginY*2
        this.cType.Move("y" y)
        this.cLF.Move("y" y)
        this.cCRLF.Move("y" y)
        pos := this.cSave.Pos
        x := w - this.marginX - pos.W
        this.cSave.Move("x" x " y" y-2)
    }
    
    UpdateTitle() {
        this.Gui.Title := "Inspector - "
            . this.Var.name (this.Dirty ? " (modified)" : "")
    }
    
    BeginEdit() {
        if !(this.OnDirty && this.OnDirty()) {
            this.Dirty := true
            this.cSave.Enabled := true
            this.UpdateTitle()
        }
    }
    
    CancelEdit() {
        if !(this.OnCancel && this.OnCancel())
            this.SetVar(this.Var)
    }
    
    SaveEdit() {
        value := this.cEdit.Value
        if this.cCRLF.Value
            value := StrReplace(value, "`n", "`r`n")
        if !this.OnSave(value, this.cType.Value)
            this.SetVar(this.Var)
    }
    
    ChangeEOL() {
        if !this.Dirty
            this.BeginEdit()
    }
    
    ChangeType() {
        type := this.cType.Value
        this.preferredType := type
        this.CheckWantReturn(type)
        if !this.Dirty
            this.BeginEdit()
    }
    
    ChangeValue() {
        value := this.cEdit.Value
        this.cType.Delete()
        if (value = "" || !VarEditGui_isFloat(value) && !VarEditGui_isInt64(value)) {
            ; Only 'string' is valid for this value
            this.cType.Add("string||")
        }
        else {
            types := "string"
            if InStr(value, "0x")
                types .= "|integer||"
            else if InStr(value, ".")
                types .= "|float||"
            else
                types .= "|integer||float"
            this.cType.Add(types)
            try this.cType.Choose(this.preferredType)
        }
        this.DisEnableEOLControls(value, false)
        this.CheckWantReturn(this.cType.Value)
        if !this.Dirty
            this.BeginEdit()
    }
    
    DisEnableEOLControls(value, readonly) {
        enabled := !readonly && InStr(value,"`n")
        this.cLF.Enabled := enabled
        this.cCRLF.Enabled := enabled
    }
    
    CheckWantReturn(type) {
        ; For convenience, make Enter activate the Save button if user
        ; is unlikely to want to insert a newline (i.e. type is numeric).
        WantReturn := !(type = "integer" || type = "float")
        this.cEdit.Opt((WantReturn ? "+" : "-") "WantReturn")
        this.cSave.Opt((Wantreturn ? "-" : "+") "Default")
    }
}

VarEditGui_isInt64(s) {
    ; Unlike (s+0 != ""), this detects overflow and rules out floating-point.
    NumPut(0, DllCall("msvcrt\_errno", "ptr"), "int")
	if A_IsUnicode
		DllCall("msvcrt\_wcstoi64", "ptr", &s, "ptr*", endp:=0, "int", 0)
	else
		DllCall("msvcrt\_strtoi64", "ptr", &s, "ptr*", endp:=0, "int", 0)
	return DllCall("msvcrt\_errno", "int*") != 34 ; ERANGE
		&& StrGet(endp) = "" && s != ""
}

VarEditGui_isFloat(s) {
    return s is "float"
}

VarEditGui_OnClose(g) {
    VarEditGui.RevokeHwnd(g.hwnd)
}

VarEditGui_OnEscape(g) {
    VarEditGui.Instances[g.hwnd].Cancel()
}

VarEditGui_OnSize(g, state, w, h) {
    VarEditGui.Instances[g.hwnd].GuiSize(w, h)
}
