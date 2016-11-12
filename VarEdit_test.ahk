
myvar := 42
; myvartype := "undefined"
myvartype := "string"
; myvartype := "integer"
; myvartype := "float"

ed := new VarEditTestGui({name: "myvar", value: myvar, type: myvartype})
ed.Show()

while VarEditGui.Instances.Length()
    Sleep 500
ExitApp

class VarEditTestGui extends VarEditGui {
    OnSave(value, type) {
        this.Var.value := value
        this.Var.type := type
    }
}

#Include VarEditGui.ahk