#Include TreeListView.ahk

Gui := GuiCreate("-DPIScale")
Gui.OnEvent("Close", "GuiEscape")
Gui.OnEvent("Escape", "GuiEscape")
testobj := {one: [1,2,3], two: {foo: 1, bar: 2, baz: 3}}
tlv := new TreeListViewTest(Gui, TestNode(testobj), "w600 h400", "One|Two|Three")
tlv.MinEditColumn := 1
tlv.MaxEditColumn := 3
Gui.AddButton(, "test button")
Gui.Show()

; For testing cleanup of nodes (on control destruction
; or when object (value 2) is replaced with string):
; tlv.root.children[3].children.push(new RefCountTestNode)
tlv.InsertChild(tlv.root, 3, nz := TestNode([], "z"))
tlv.InsertChild(nz, 1, new RefCountTestNode), nz := ""
class RefCountTestNode {
    values := ["One", "Two"]
    __delete() {
        MsgBox "Delete RefCountTestNode"
    }
}

#If WinActive("TreeListView_Test.ahk ahk_class AutoHotkeyGUI")

tlv.InsertChild(tlv.root, 2, TestNode("bar", "foo"))
F4::tlv.RemoveChild(tlv.root.children[3], 2)

F5::tlv.Reset()

GuiEscape() {
    global
    Gui.Destroy()
    tlv := ""
    ExitApp
}

class TreeListViewTest extends TreeListView {
    AfterPopulate() {
        this.LV.ModifyCol(1, 150)
        this.LV.ModifyCol(2, "AutoHdr")
        this.LV.ModifyCol(3, "AutoHdr")
    }
    CanEdit(r, c:="") {
        ; This is just to show how tabbing works when some cells are
        ; not editable.
        if (c != "" && InStr(this.LV.GetText(r, c), "object"))
            return false
        return base.CanEdit(r, c)
    }
}

; This is used to construct a tree from an object, but since the TLV
; allows a node to have both editable values and children, they aren't
; linked (i.e. replacing the initial "Object" value does not affect the
; child nodes).
TestNode(value, name:="") {
    this := {}
    this.values := [GetValueString(name), GetValueString(value)]
    if IsObject(value) {
        this.expandable := true
        this.children := []
        for k,v in value
            this.children.Push(TestNode(v, k))
    }
    return this
}

GetValueString(value) {
    if IsObject(value) {
        try if value.ToString
            return value.ToString()
        try if className := value.__Class
            return className
        return "Object"
    }
    return value
}