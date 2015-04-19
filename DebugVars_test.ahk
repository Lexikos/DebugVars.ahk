/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Warn,, StdOut
global A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

dv := new DebugVars(TestVarProvider)
dv.Show(), dv := ""
while DebugVars.Instances.MaxIndex()
    Sleep 1000
ExitApp

#Include DebugVars.ahk

class TestVarProvider extends DebugVars_Base
{
    __new(obj) {
        if !obj
            return
        this.root := {value: obj}
    }
    
    GetRoot() {
        if this.root
            return this.root
        test_names =
        (LTrim
            A_ScriptDir
            A_ScriptName
            A_ScriptFullPath
            A_ScriptHwnd
            A_Args
        )
        value := {}
        Loop Parse, test_names, `n
            value[A_LoopField] := %A_LoopField%
        return this.root := {value: value}
    }
    
    GetChildren(node) {
        if !nodes := node.children {
            nodes := node.children := []
            for k,v in node.value
                nodes.Push({name: k, value: v, parent: node})
        }
        return nodes
    }
    
    HasChildren(node) {
        return IsObject(node.value)
    }
    
    SetValue(node, value) {
        if node.parent
            node.parent.value[node.name] := value
        node.value := value
    }
}
