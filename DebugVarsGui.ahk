
#Include VarTreeGui.ahk
#Include VarEditGui.ahk

DvInspectProperty(dbg, fullname, extra_args:="", show_opt:="") {
    dbg.feature_set("-n max_depth -v 1")
    ; 1MB seems reasonably permissive.  Note that -m 0 (unlimited
    ; according to the spec) doesn't work with v1.1.24.02 and earlier.
    response := dbg.property_get("-m 1048576 -n " fullname (extra_args="" ? "" : " " extra_args))
    dbg.feature_set("-n max_depth -v 0")
    prop := DvLoadXml(response).selectSingleNode("/response/property")
    
    if (prop.getAttribute("name") = "(invalid)") {
        MsgBox "Invalid variable name: " fullname,, "Icon!"
        return false
    }
    
    type := prop.getAttribute("type")
    if (type != "object") {
        isReadOnly := prop.getAttribute("facet") = "Builtin"
        value := DBGp_Base64UTF8Decode(prop.text)
        dv := DebugVarGui(dbg, {name: fullname, value: value, type: type, readonly: isReadOnly})
    }
    else {
        dv := DebugVarsGui(DvPropertyNode(dbg, prop))
    }
    dv.Show(show_opt)
}

class DebugVarGui extends VarEditGui
{
    __New(dbg, var) {
        super.__New(var)
        this.dbg := dbg
    }
    
    OnSave(value, type) {
        DvSetProperty(this.dbg, this.var.name, value, type)
        this.var.value := value
        this.var.type := type
        DvRefreshAll()
    }
}

DvSetProperty(dbg, fullname, value, type) {
    if (type = "integer")
        value := format("{:i}", value) ; Force decimal format.
    if (type = "integer" || type = "float") && dbg.no_base64_numbers
        data := value
    else
        data := DBGp_Base64UTF8Encode(value)
    return dbg.property_set("-n " fullname " -t " type " -- " data)
}

class DvNodeBase
{
    static prototype.expandable := false
    static prototype.children := ""
    
    expanded {
        set {
            if value {
                ; Expanded for the first time: populate.
                this.children := this.GetChildren()
                this.DefineProp 'expanded', {value: true}
            }
            return value
        }
        get {
            return false
        }
    }
    
    SetValue(value) {
        return false
    }
    
    Clone() {
        node := super.Clone()
        node.children := this.GetChildren()
        return node
    }
    
    Update(tlv) {
        if !this.HasProp('children')
            return
        for child in this.children
            child.Update(tlv)
    }
}

class DvPropertyParentNode extends DvNodeBase
{
    UpdateChildren(tlv, props) {
        children := this.children
        if !children {
            if !props.length
                return
            this.children := children := []
        }
        np := 0, nc := 1
        loop {
            if (np < props.length) {
                prop := props.item(np)
                if (nc > children.Length() || prop.getAttribute("name") < children[nc].name) {
                    tlv.InsertChild(this, nc, DvPropertyNode(this.dbg, prop))
                    ++nc, ++np
                    continue
                }
                if (prop.getAttribute("name") = children[nc].name) {
                    children[nc].Update(tlv, prop)
                    ++nc, ++np
                    continue
                }
            }
            if (nc > children.Length())
                break
            tlv.RemoveChild(this, nc)
        }
    }
}

class DvPropertyNode extends DvPropertyParentNode
{
    __new(dbg, prop) {
        this.dbg := dbg
        this.fullname := prop.getAttribute("fullname")
        this.name := prop.getAttribute("name")
        this.xml := prop
        props := prop.selectNodes("property")
        if props.length {
            this.children := DvPropertyNode.FromXmlNodes(props, dbg)
            this.DefineProp 'expanded', {value: false}
        }
        else {
            this._value := DBGp_Base64UTF8Decode(prop.text)
        }
        this.values := [this.name, this.GetValueString()]
    }
    
    value {
        set {
            this._value := value
            this.values[2] := this.GetValueString()
            return value
        }
        get {
            return this._value
        }
    }
    
    static FromXmlNodes(props, dbg) {
        nodes := []
        for prop in props
            nodes.Push(DvPropertyNode(dbg, prop))
        return nodes
    }
    
    expandable {
        get {
            return this.xml.getAttribute("children")
        }
    }
    
    GetProperty() {
        this.dbg.feature_set("-n max_depth -v 1")
        response := this.dbg.property_get("-n " this.fullname)
        this.dbg.feature_set("-n max_depth -v 0")
        xml := DvLoadXml(response)
        return this.xml := xml.selectSingleNode("/response/property")
    }
    
    GetChildren() {
        prop := this.GetProperty()
        props := prop.selectNodes("property")
        return DvPropertyNode.FromXmlNodes(props, this.dbg)
    }
    
    GetValueString() {
        if (cn := this.xml.getAttribute("classname"))
            return cn
        utf8_len := StrPut(this.value, "UTF-8") - 1
        return this.value (this.xml.getAttribute("size") > utf8_len ? "..." : "")
    }
    
    GetWindowTitle() {
        title := "Inspector - " this.fullname
        if prop := this.xml {
            if !(type := prop.getAttribute("classname"))
                type := prop.getAttribute("type")
            title .= " (" type ")"
        }
        return title
    }
    
    SetValue(value) {
        type := this.xml.getAttribute("type") ; Try to match type of previous value.
        if (type = "float" || type = "integer") && value+0 != ""
            type := InStr(value, ".") ? "float" : "integer"
        else
            type := "string"
        try
            response := DvSetProperty(this.dbg, this.xml.getAttribute("fullname"), value, type)
        catch DbgpError
            return false
        else if InStr(response, 'success="0"')
            return false
        ; Update .xml for @classname and @children, and in case the value
        ; differs from what we set (e.g. for setting A_KeyDelay in v2).
        this.GetProperty()
        this.value := value := DBGp_Base64UTF8Decode(this.xml.text)
    }
    
    Update(tlv, prop:="") {
        had_children := this.xml.getAttribute("children")
        if !prop || prop.getAttribute("children") && !prop.selectSingleNode("property")
            prop := this.GetProperty()
        else
            this.xml := prop
        props := prop.selectNodes("property")
        value2 := this.values[2]
        this.value := props.length ? "" : DBGp_Base64UTF8Decode(prop.text)
        if !(this.values[2] "" ==  "" value2) ; Prevent unnecessary redraw and flicker.
            || (had_children != prop.getAttribute("children"))
            tlv.RefreshValues(this)
        this.UpdateChildren(tlv, props)
    }
}

class DvContextNode extends DvPropertyParentNode
{
    static prototype.expandable := true
    
    __new(dbg, context) {
        this.dbg := dbg
        this.context := context
    }
    
    values {
        get {
            return [this.GetWindowTitle(), ""]
        }
    }
    
    GetProperties() {
        response := this.dbg.context_get("-c " this.context)
        xml := DvLoadXml(response)
        return xml.selectNodes("/response/property")
    }
    
    GetChildren() {
        props := this.GetProperties()
        return DvPropertyNode.FromXmlNodes(props, this.dbg)
    }
    
    GetWindowTitle() {
        return this.context=0 ? "Local vars" : "Global vars"
    }
    
    Update(tlv) {
        props := this.GetProperties()
        this.UpdateChildren(tlv, props)
    }
}

class Dv2ContextsNode extends DvNodeBase
{
    static prototype.expandable := true
    
    __new(dbg) {
        this.dbg := dbg
    }
    
    GetChildren() {
        children := []
        Loop 2 {
            children.Push(node := DvContextNode(this.dbg, A_Index-1))
            node.expanded := true
        }
        return children
    }
    
    GetWindowTitle() {
        return "Variables"
    }
}

class DebugVarsGui extends VarTreeGui
{
    AddVarTree(p*) => DebugVarsGui.Control(this, p*)
    
    class Control extends VarTreeGui.Control
    {
        LV_Key_F5() {
            this.LV.Gui.Refresh()
        }
        
        LV_Key_Enter(r, node) {
            DvInspectProperty(node.dbg, node.xml.getAttribute("fullname"))
        }
    }
    
    OnContextMenu(node, isRightClick, x, y) {
        m := Menu()
        if !(node is DvPropertyNode)
            m.Add "New window", (*) => this.NewWindow(node)
        else
            m.Add "Inspect", (*) => this.InspectNode(node)
        m.Add "Refresh", (*) => this.Refresh()
        mr := Menu()
        static refresh_intervals := Map("Off", 0, "0.5 s", 500, "1.0 s", 1000, "5.0 s", 5000)
        for text, interval in refresh_intervals {
            mr.Add text, ((n, *) => this.SetAutoRefresh(n)).Bind(interval)
            if interval = this.refresh_interval
                mr.Check text
        }
        m.Add "Auto refresh", mr
        m.Show x, y
    }
    
    OnDoubleClick(node) {
        if !(node is DvPropertyNode)
            this.NewWindow(node)
        else
            this.InspectNode(node)
    }
    
    InspectNode(node) {
        DvInspectProperty(node.dbg, node.xml.getAttribute("fullname"))
    }
    
    NewWindow(node) {
        dv := DebugVarsGui(node.Clone())
        dv.Show()
    }
    
    refresh_interval := 0
    SetAutoRefresh(interval) {
        this.refresh_interval := interval
        timer := this.HasProp('timer') ? this.timer : ""
        if !interval {
            if timer {
                SetTimer timer, 0
                this.timer := ""
            }
            return
        }
        if !timer
            this.timer := timer := ObjBindMethod(this, "Refresh", true)
        SetTimer timer, interval
    }
    
    Refresh(auto:=false) {
        if auto && !DllCall("IsWindowVisible", "ptr", this.hwnd)
            ; @Debug-Output => DebugVarsGui refreshed when not visible; turning off now.
            return this.SetAutoRefresh(0)
        this.TLV.root.Update(this.TLV)
        this.Title := this.TLV.root.GetWindowTitle()
    }
}

DvRefreshAll() {
    for hwnd in WinGetList("ahk_class AutoHotkeyGui ahk_pid " ProcessExist())
        if (g := GuiFromHwnd(hwnd)) && g is DebugVarsGui
            g.Refresh()
}

DvLoadXml(data) {
    o := ComObject("MSXML2.DOMDocument")
    o.async := false
    o.setProperty("SelectionLanguage", "XPath")
    o.loadXml(data)
    return o
}
