
class ObjectVarProvider extends DebugVars_Base
{
    __new(obj) {
        this.root := {value: obj}
    }
    
    GetRoot() {
        return this.root
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
    
    GetValueString(node) {
        if IsObject(node.value) {
            try return node.value.ToString()
            try if className := node.value.__Class
                return className " object"
            return DebugVars.OBJECT_STRING
        }
        return node.value
    }
    
    SetValue(node, value) {
        if node.parent
            node.parent.value[node.name] := value
        node.value := value
    }
}

class GlobalVarProvider extends ObjectVarProvider
{
    __new(var_names) {
        value := {}
        Loop Parse, % var_names, `n
            value[A_LoopField] := %A_LoopField%
        base.__new(value)
    }
}
