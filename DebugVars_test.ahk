/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Warn,, StdOut
global A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

dv := new DebugVars(new GlobalVarProvider("
    (LTrim
        A_ScriptDir
        A_ScriptName
        A_ScriptFullPath
        A_ScriptHwnd
        A_Args
    )"))
dv.OnContextMenu := Func("DV_ContextMenu")
dv.OnDoubleClick := Func("DV_EditNode")
dv.Show(), dv := ""
while DebugVars.Instances.Length()
    Sleep 1000
ExitApp

DV_ContextMenu(dv, node, isRightClick, x, y) {
	fn := Func("DV_EditNode").Bind(dv, node)
	Menu OEmenu, Add, Inspect, % fn
	Menu OEmenu, Show, % x, % y
	Menu OEmenu, Delete
}

DV_EditNode(dv, node) {
	ed := new DebugVar({name: node.name, value: node.value, type: dv_type(node.value)})
    ed.OnSave := Func("ED_Save").Bind(dv, node)
    ed.Show()
}

ED_Save(dv, node, ed, value, type) {
    if (type = "integer")
        value += 0
    else if (type = "float")
        value += 0.0
    dv.provider.SetValue(node, value)
    dv.Reset()
    ed.Var.value := value
    ed.Var.type := type
}

; https://autohotkey.com/boards/viewtopic.php?t=2306
dv_type(v) {
    if IsObject(v)
        return "Object"
    return v="" || [v].GetCapacity(1) ? "string" : InStr(v,".") ? "float" : "integer"
}

#Include DebugVars.ahk
#Include DebugVars.Providers.ahk
#Include DebugVar.ahk
