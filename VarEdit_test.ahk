
myvar := ""
myvartype := "undefined"
; myvartype := "string"
; myvartype := "integer"
; myvartype := "float"

ed := VarEditTestGui({name: "myvar", value: myvar, type: myvartype})
ed.Show()

class VarEditTestGui extends VarEditGui {
    OnSave(value, type) {
        this.Var.value := value
        this.Var.type := type
    }
}

#Include VarEditGui.ahk