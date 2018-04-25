/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Warn , StdOut
global A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

test_vars := "
    (LTrim
        A_ScriptDir
        A_ScriptName
        A_ScriptFullPath
        A_ScriptHwnd
        A_Args
    )"
test_obj := {}
Loop Parse test_vars, "`n"
    test_obj[A_LoopField] := %A_LoopField%
ShowGuiForObject(test_obj)
while VarTreeGui.Instances.Length()
    Sleep 1000
ExitApp

ShowGuiForObject(obj) {
    vtg := new VarTreeGui(new VarTreeObjectNode(obj))
    vtg.OnContextMenu := Func("ContextMenu")
    vtg.OnDoubleClick := Func("EditNode")
    vtg.Show()
}

ContextMenu(vtg, node, isRightClick, x, y) {
    m := MenuCreate()
    m.Add("Inspect", Func("EditNode").Bind(vtg, node))
    m.Show(x, y)
}

EditNode(vtg, node) {
    if IsObject(node.value) {
        ShowGuiForObject(node.value)
    }
    else {
        gui := new VarEditGui({name: node.values[1], value: node.value, type: type(node.value)})
        gui.OnSave := Func("ED_Save").Bind(vtg, node)
        gui.Show()
    }
}

ED_Save(vtg, node, ed, value, type) {
    if (type = "integer")
        value += 0
    else if (type = "float")
        value += 0.0
    node.SetValue(value)
    vtg.EnableRedraw(false)
    vtg.Reset()
    vtg.EnableRedraw(true)
    ed.Var.value := value
    ed.Var.type := type
}

#Include VarTreeGui.ahk
#Include VarTreeObjectNode.ahk
#Include VarEditGui.ahk
