
class DvObjectNode extends DebugVars_Base
{
    __new(value) {
        this.value := value
    }
    
    GetChildren() {
        if !nodes := this.children {
            nodes := this.children := []
            for k,v in this.value {
                child := new DvObjectNode(v)
                child.key := k
                child.name := IsObject(k) ? "Object(" (&k) ")" : k
                child.container := this.value
                nodes.Push(child)
            }
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
