
class VarTreeObjectNode extends TreeListView._Base
{
    __new(value, name:="") {
        this.value := value
        this.values := [name, this._GetValueString(value)]
    }
    
    expandable {
        get {
            return IsObject(this.value)
        }
    }
    
    expanded {
        set {
            if value {
                ; Expanded for the first time: populate.
                this.children := this._MakeChildren()
                ObjRawSet(this, "expanded", true)
            }
            return value
        }
        get {
            return false
        }
    }
    
    _MakeChildren() {
        children := []
        for k,v in this.value {
            child := new VarTreeObjectNode(v, this._GetValueString(k))
            child.key := k
            child.container := this.value
            children.Push(child)
        }
        return children
    }
    
    _GetValueString(value) {
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
        this.values[2] := this._GetValueString(value)
    }
}
