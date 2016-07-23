
myvar := 42
; myvartype := "undefined"
myvartype := "string"
; myvartype := "integer"
; myvartype := "float"

dv := new DebugVarTest({name: "myvar", value: myvar, type: myvartype})
dv.Show()

while dv.Instances.Length()
    Sleep 500
ExitApp

class DebugVarTest extends DebugVar {
    OnSave(value, type) {
        this.Var.value := value
        this.Var.type := type
    }
}

#Include DebugVar.ahk