#Include TreeListView.ahk

TestGui := Gui("-DPIScale")
TestGui.OnEvent("Close", GuiEscape)
TestGui.OnEvent("Escape", GuiEscape)
testobj := {one: [1,2,3], two: {foo: 1, bar: 2, baz: 3}}
tlv := TreeListViewTest(TestGui, TestNode(testobj), "w600 h400", ["One","Two","Three"])
tlv.MinEditColumn := 1
tlv.MaxEditColumn := 3
TestGui.AddButton(, "test button")
TestGui.Show()

; For testing cleanup of nodes (on control destruction
; or when object (value 2) is replaced with string):
; tlv.root.children[3].children.push(RefCountTestNode())
tlv.InsertChild(tlv.root, 3, nz := TestNode([], "z"))
tlv.InsertChild(nz, 1, RefCountTestNode()), nz := ""
class RefCountTestNode {
    values := ["One", "Two"]
    expandable := false
    expanded := false
    __delete() {
        MsgBox "Delete RefCountTestNode"
    }
}

#HotIf WinActive("TreeListView_test.ahk ahk_class AutoHotkeyGUI")

tlv.InsertChild(tlv.root, 2, TestNode("bar", "foo"))
F4::tlv.RemoveChild(tlv.root.children[3], 2)

F5::tlv.Reset()

GuiEscape(*) {
    global
    TestGui.Destroy()
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
        return super.CanEdit(r, c)
    }
}

; This is used to construct a tree from an object, but since the TLV
; allows a node to have both editable values and children, they aren't
; linked (i.e. replacing the initial "Object" value does not affect the
; child nodes).
TestNode(value, name:="") {
    this := {expandable: false, expanded: false}
    this.values := [GetValueString(name), GetValueString(value), ""]
    if IsObject(value) {
        this.expandable := true
        this.children := []
        for k,v in ObjOwnProps(value)
            this.children.Push(TestNode(v, k))
        if value.HasMethod('__enum')
            for k,v in value
                this.children.Push(TestNode(v, k))
    }
    return this
}

GetValueString(value) {
    try return String(value)
    return Type(value)
}