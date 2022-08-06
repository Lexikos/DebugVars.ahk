/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Warn , StdOut
A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

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
    test_obj.%A_LoopField% := %A_LoopField%
ShowGuiForObject(test_obj)

ShowGuiForObject(obj) {
    vtg := VarTreeGui(VarTreeObjectNode(obj))
    vtg.OnContextMenu := ContextMenu
    vtg.OnDoubleClick := EditNode
    vtg.Show()
}

ContextMenu(vtg, node, isRightClick, x, y) {
    m := Menu()
    m.Add("Inspect", (*) => EditNode(vtg, node))
    m.Show(x, y)
}

EditNode(vtg, node) {
    if IsObject(node.value) {
        ShowGuiForObject(node.value)
    }
    else {
        veg := VarEditGui({name: node.values[1], value: node.value, type: type(node.value)})
        veg.OnSave := ED_Save.Bind(vtg, node)
        veg.Show()
    }
}

ED_Save(vtg, node, ed, value, type) {
    node.SetValue(%type%(value))
    vtg.TLV.EnableRedraw(false)
    vtg.TLV.Reset()
    vtg.TLV.EnableRedraw(true)
    ed.Var.value := value
    ed.Var.type := type
}

#Include VarTreeGui.ahk
#Include VarTreeObjectNode.ahk
#Include VarEditGui.ahk
