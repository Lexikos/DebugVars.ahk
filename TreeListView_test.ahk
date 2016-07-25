#Include TreeListView.ahk

Gui -DPIScale
testobj := {one: [1,2,3], two: {foo: 1, bar: 2, baz: 3}, z:[]}
tlv := new TreeListViewTest(new TestNode(testobj), "w600 h400", "One|Two|Three")
Gui Add, Button,, test button
Gui Show

GuiEscape() {
    ExitApp
}
GuiClose() {
    ExitApp
}

class TreeListViewTest extends TreeListView {
    AfterPopulate() {
        LV_ModifyCol(1, 150)
        LV_ModifyCol(2, "AutoHdr")
        LV_ModifyCol(3, "AutoHdr")
    }
}

class TestNode
{
    __new(value) {
        this.values := [, value]
    }
    
    children {
        get {
            ; Store the value so 'get' won't be called again:
            return this.children := this._MakeChildren()
        }
    }
    
    _MakeChildren() {
        nodes := []
        for k,v in (container := this.values[2]) {
            child := new TestNode(v)
            child.key := k
            child.values[1] := IsObject(k) ? "Object(" (&k) ")" : k
            child.container := container
            nodes.Push(child)
        }
        return nodes
    }
    
    expandable {
        get {
            return IsObject(this.values[2])
        }
    }
    
    GetValueString() {
        value := this.values[2]
        if IsObject(value) {
            try if value.ToString
                return value.ToString()
            try if className := value.__Class
                return className
            return "Object"
        }
        return value
    }
    
    SetValue(value, c) {
        if (c = 2) {
            ; Update the actual value
            this.container[this.key] := value
        }
        ; Update our copy of the value
        this.values[c] := value
    }
}