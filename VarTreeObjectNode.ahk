
class VarTreeObjectNode
{
    static prototype.children := ""
    
    __new(value, name:="") {
        this.value := value
        this.values := [name, this._GetValueString(value)]
    }
    
    expandable => IsObject(this.value)
    
    expanded {
        set {
            if value {
                ; Expanded for the first time: populate.
                this.children := this._MakeChildren()
                this.DefineProp 'expanded', {value: true}
            }
        }
        get => false
    }
    
    _MakeChildren() {
        children := []
        if this.value.HasMethod('__enum')
            for k,v in this.value
                children.Push(VarTreeObjectNode.Item(v, k, this.value))
        for k,v in ObjOwnProps(this.value)
            children.Push(VarTreeObjectNode.Property(v, k, this.value))
        return children
    }
    
    _GetValueString(value) {
        try return String(value)
        return Type(value)
    }
    
    SetValue(value) {
        this.value := value
        this.values[2] := this._GetValueString(value)
    }
    
    class Item extends VarTreeObjectNode {
        __new(value, key, container) {
            super.__new(value, '[' this._GetValueString(key) ']')
            this.container := container
            this.key := key
        }
        
        SetValue(value) {
            super.SetValue(value)
            this.container[this.key] := value
        }
    }
    
    class Property extends VarTreeObjectNode {
        __new(value, name, container) {
            super.__new(value, name)
            this.container := container
        }
        
        SetValue(value) {
            super.SetValue(value)
            this.container.%this.values[1]% := value
        }
    }
}
