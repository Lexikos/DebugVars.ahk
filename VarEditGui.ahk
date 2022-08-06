
/*
    VarEditGui
    
    Public interface:
        ed := VarEditGui({Name, Value, Type, ReadOnly})
        ed.SetVar({Name, Value, Type, ReadOnly)
        ed.Show()
        ed.Cancel()
        ed.Hide()
        ed.OnSave := Func(ed, value, type)
        ed.OnDirty := Func(ed)
        ed.OnCancel := Func(ed)
*/
class VarEditGui extends Gui {
    __New(aVar:="") {
        editOpt := ""
        if aVar && (aVar.type = "integer" || aVar.type = "float")
            editOpt := "r1 Multi" ; Default to one line.
        this._CreateGui(editOpt)
        if aVar
            this.SetVar(aVar)
    }
    
    SetVar(aVar) {
        this.Dirty := false
        this.Var := aVar
        this.cSave.Enabled := false
        
        vtype := aVar.type
        value := aVar.value
        readonly := aVar.HasProp('readonly') && aVar.readonly
        
        types := []
        if readonly
            types.Push vtype
        else {
            ; 'undefined' can't be set by the user, but may be the initial type
            if vtype = "undefined"
                types.Push "undefined"
            types.Push "string"
            if VarEditGui_isInt64(value)
                types.Push "integer"
            if IsNumber(value) && !InStr(value,"0x")
                types.Push "float"
        }
        this.cType.Delete()
        this.cType.Add(types)
        this.cType.Choose(vtype)
        this.preferredType := vtype
        
        this.cEdit.Opt((readonly ? "+" : "-") "ReadOnly")
        
        this.cEdit.Value := value
        
        this.%InStr(value,"`r`n") ? "cCRLF" : "cLF"%.Value := true
        this.DisEnableEOLControls(value, readonly)
        this.CheckWantReturn(vtype)
        
        this.UpdateTitle()
    }
    
    _CreateGui(editOpt:="") {
        super.__new("+Resize",, this)
        this.OnEvent("Escape", "Hide")
        this.OnEvent("Size", "GuiSize")
        
        this.cEdit := this.AddEdit("w300 r10 " editOpt)
        this.cEdit.OnEvent("Change", "ChangeValue")
        
        this.cType := this.AddDDL("w70", ["undefined"])
        this.cType.OnEvent("Change", "ChangeType")
        
        this.cType.GetPos(,,, &cH)
        this.footerH := cH
        
        this.cLF := this.AddRadio("x+m h" cH, "LF")
        this.cCRLF := this.AddRadio("x+0 h" cH, "CR+LF")
        this.cLF.OnEvent("Click", "ChangeEOL")
        this.cCRLF.OnEvent("Click", "ChangeEOL")
        
        this.cSave := this.AddButton("x+m Disabled", "&Save")
        this.cSave.OnEvent("Click", "SaveEdit")
        
        this.cSave.GetPos(&x,, &w)
        this.Opt("+MinSize" (x + w + this.marginX) "x")
    }
    
    Cancel() {
        if this.Dirty
            this.CancelEdit()
        else
            this.Hide()
    }
    
    GuiSize(state, w, h) {
        cW := w - this.marginX*2
        cH := h - this.marginY*3 - this.footerH
        this.cEdit.Move(,, cW, cH)
        y := cH + this.marginY*2
        this.cType.Move(, y)
        this.cLF.Move(, y)
        this.cCRLF.Move(, y)
        this.cSave.GetPos(,, &sW)
        x := w - this.marginX - sW
        this.cSave.Move(x, y-2)
    }
    
    UpdateTitle() {
        this.Title := "Inspector - "
            . this.Var.name (this.Dirty ? " (modified)" : "")
    }
    
    BeginEdit() {
        if !(this.HasProp('OnDirty') && this.OnDirty()) {
            this.Dirty := true
            this.cSave.Enabled := true
            this.UpdateTitle()
        }
    }
    
    CancelEdit() {
        if !(this.HasProp('OnCancel') && this.OnCancel())
            this.SetVar(this.Var)
    }
    
    SaveEdit(*) {
        value := this.cEdit.Value
        if this.cCRLF.Value
            value := StrReplace(value, "`n", "`r`n")
        if !this.OnSave(value, this.cType.Text)
            this.SetVar(this.Var)
    }
    
    ChangeEOL(*) {
        if !this.Dirty
            this.BeginEdit()
    }
    
    ChangeType(*) {
        vtype := this.cType.Text
        this.preferredType := vtype
        this.CheckWantReturn(vtype)
        if !this.Dirty
            this.BeginEdit()
    }
    
    ChangeValue(*) {
        value := this.cEdit.Value
        types := []
        if (value = "" || !IsFloat(value) && !VarEditGui_isInt64(value)) {
            ; Only 'string' is valid for this value
            types.Push "string"
        }
        else {
            types.Push "string"
            if InStr(value, "0x")
                types.Push "integer"
            else if InStr(value, ".")
                types.Push "float"
            else
                types.Push "integer", "float"
        }
        this.cType.Delete()
        this.cType.Add(types)
        try this.cType.Choose(Min(2, types.Length))
        try this.cType.Choose(this.preferredType)
        this.DisEnableEOLControls(value, false)
        this.CheckWantReturn(this.cType.Text)
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
    ; Unlike IsInteger(s), this detects overflow.
    NumPut("int", 0, DllCall("msvcrt\_errno", "ptr"))
	DllCall("msvcrt\_wcstoi64", "wstr", s, "wstr*", &suffix:="", "int", 0)
	return DllCall("msvcrt\_errno", "int*") != 34 ; ERANGE
		&& suffix = "" && s != ""
}
