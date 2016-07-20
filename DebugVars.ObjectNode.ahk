
class DvObjectNode extends DebugVars_Base
{
    __new(value) {
        this.value := value
    }
    
    children {
        get {
            ; Store the value so 'get' won't be called again:
            return this.children := this._MakeChildren()
        }
    }
    
    _MakeChildren() {
        nodes := []
        for k,v in this.value {
            child := new DvObjectNode(v)
            child.key := k
            child.name := IsObject(k) ? "Object(" (&k) ")" : k
            child.container := this.value
            nodes.Push(child)
        }
        return nodes
    }
    
    HasChildren() {
        return IsObject(this.value)
    }
    
    GetValueString() {
        value := this.value
        if IsObject(value) {
            try if value.ToString
                return value.ToString()
            try if className := value.__Class
                return className
            return "Object"
        }
        return value
    }
    
    SetValue(value) {
        ; Update the actual value
        this.container[this.key] := value
        ; Update our copy of the value
        this.value := value
    }
}
