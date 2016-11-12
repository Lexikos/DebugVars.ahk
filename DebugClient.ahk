
#Include DebugVars.ahk
#Include DebugVar.ahk

global ShortValueLimit := 64

global PendingThreads := {}
global DbgSessions := {}

DBGp_OnBegin("DebugBegin")
DBGp_OnBreak("DebugBreak")
DBGp_OnEnd("DebugEnd")

DBGp_StartListening()

GroupAdd all, % "ahk_class AutoHotkeyGUI ahk_pid " DllCall("GetCurrentProcessId", "uint")
OnExit("CloseAll")
CloseAll(exitReason:="") {
    DetectHiddenWindows Off
    if exitReason && WinExist("ahk_group all") {
        ; Start a new thread which can be interrupted (OnExit can't).
        SetTimer CloseAll, -10
        return true
    }
    GroupClose all
    ExitApp
}

dv := new DcDebugVars(new DcAllScriptsNode)
dv.Show()

InspectProperty(dbg, fullname, extra_args:="") {
    dbg.feature_set("-n max_depth -v 1")
    ; 1MB seems reasonably permissive.  Note that -m 0 (unlimited
    ; according to the spec) doesn't work with v1.1.24.02 and earlier.
    dbg.property_get("-m 1048576 -n " fullname (extra_args="" ? "" : " " extra_args), response)
    dbg.feature_set("-n max_depth -v 0")
    prop := DcLoadXml(response).selectSingleNode("/response/property")
    
    if (prop.getAttribute("name") = "(invalid)") {
        MsgBox, 48,, Invalid variable name: %fullname%
        return false
    }
    
    type := prop.getAttribute("type")
    if (type != "object") {
        isReadOnly := prop.getAttribute("facet") = "Builtin"
        value := DBGp_Base64UTF8Decode(prop.text)
        dv := new DcDebugVar(dbg, {name: fullname, value: value, type: type, readonly: isReadOnly})
    } else {
        dv := new DcDebugVars(new DcPropertyNode(dbg, prop))
    }
    dv.Show()
}

class DcDebugVar extends DebugVar
{
    __New(dbg, var) {
        base.__New(var)
        this.dbg := dbg
    }
    
    OnSave(value, type) {
        if (type = "integer" || type = "float") && this.dbg.no_base64_numbers
            data := value
        else
            data := DBGp_Base64UTF8Encode(value)
        this.dbg.property_set("-n " this.var.name " -t " type " -- " data)
        this.var.value := value
        this.var.type := type
        RefreshAll()
    }
}

class DcNodeBase extends TreeListView._Base
{
    expanded {
        set {
            if value {
                ; Expanded for the first time: populate.
                this.children := this.GetChildren()
                ObjRawSet(this, "expanded", true)
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
        node := ObjClone(this)
        node.children := this.GetChildren()
        return node
    }
    
    Update(tlv) {
        for i, child in this.children
            child.Update(tlv)
    }
}

class DcAllScriptsNode extends DcNodeBase
{
    GetChildren() {
        children := []
        for i, script_id in this.GetScripts()
            children.Push(new DcScriptNode(script_id))
        return children
    }
    
    GetScripts() {
        DetectHiddenWindows On
        script_ids := []
        WinGet scripts, List, ahk_class AutoHotkey
        loop % scripts {
            script_id := scripts%A_Index%
            if (script_id = A_ScriptHwnd)
                continue
            PostMessage 0x44, 0, 0,, ahk_id %script_id%  ; WM_COMMNOTIFY, WM_NULL
            if ErrorLevel  ; Likely blocked by UIPI (won't be able to attach).
                continue
            script_ids.Push(script_id)
        }
        return script_ids
    }
    
    GetWindowTitle() {
        return "Variables"
    }
    
    Update(tlv) {
        nc := 1
        new_scripts := this.GetScripts()
        children := this.children
        while nc <= children.Length() {
            node := children[nc]
            ns := 0
            while ++ns <= new_scripts.Length() {
                if (new_scripts[ns] == node.hwnd) {
                    new_scripts.RemoveAt(ns), ++nc
                    continue 2
                }
            }
            tlv.RemoveChild(this, nc)
        }
        for ns, script_id in new_scripts {
            tlv.InsertChild(this, nc++, new DcScriptNode(script_id))
        }
        base.Update(tlv)
    }
}

class DcScriptNode extends DcNodeBase
{
    static expandable := true
    
    __new(hwnd) {
        this.hwnd := hwnd
        WinGetTitle title, ahk_id %hwnd%
        title := RegExReplace(title, " - AutoHotkey v\S*$")
        SplitPath title, name, dir
        this.values := [name, hwnd "  -  " dir]
    }
    
    GetChildren() {
        static attach_msg := DllCall("RegisterWindowMessage", "str", "AHK_ATTACH_DEBUGGER", "uint")
        thread_id := DllCall("GetWindowThreadProcessId", "ptr", this.hwnd, "ptr", 0, "uint")
        if !this.dbg := DbgSessions[thread_id] {
            PendingThreads[thread_id] := this
            PostMessage % attach_msg,,,, % "ahk_id " this.hwnd
            began := A_TickCount
        }
        Loop {
            if this.dbg
                break
            if (A_TickCount-began > 5000) || ErrorLevel {
                PendingThreads.Delete(thread_id)
                return [{values: ["", "Failed to attach."]}]
            }
            Sleep 15
        }
        return [new DcContextNode(this.dbg, 0), new DcContextNode(this.dbg, 1)]
    }
    
    GetWindowTitle() {
        return format("Variables - {} (0x{:x})", this.values[1], this.hwnd)
    }
}

class DcPropertyParentNode extends DcNodeBase
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
                    tlv.InsertChild(this, nc, new DcPropertyNode(this.dbg, prop))
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

class DcPropertyNode extends DcPropertyParentNode
{
    __new(dbg, prop) {
        this.dbg := dbg
        this.fullname := prop.getAttribute("fullname")
        this.name := prop.getAttribute("name")
        this.xml := prop
        props := prop.selectNodes("property")
        if props.length
            this.children := this.FromXmlNodes(props, dbg)
        else
            this._value := DBGp_Base64UTF8Decode(prop.text)
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
    
    FromXmlNodes(props, dbg) {
        nodes := []
        for prop in props
            nodes.Push(new DcPropertyNode(dbg, prop))
        return nodes
    }
    
    expandable {
        get {
            return this.xml.getAttribute("children")
        }
    }
    
    GetProperty() {
        ; SetEnableChildren(true) ; SciTE
        this.dbg.feature_set("-n max_depth -v 1")
        this.dbg.property_get("-n " this.fullname, response)
        this.dbg.feature_set("-n max_depth -v 0")
        ; SetEnableChildren(false) ; SciTE
        xml := DcLoadXml(response) ; SciTE
        return this.xml := xml.selectSingleNode("/response/property")
    }
    
    GetChildren() {
        prop := this.GetProperty()
        props := prop.selectNodes("property")
        return DcPropertyNode.FromXmlNodes(props, this.dbg)
    }
    
    GetValueString() {
        return (cn := this.xml.getAttribute("classname")) ? cn
            : this.value . (this.xml.getAttribute("size") > ShortValueLimit ? "..." : "")
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
        this.dbg.property_set("-n " this.xml.getAttribute("fullname")
            . " -- " DBGp_Base64UTF8Encode(value), response)
        if InStr(response, "<error") || InStr(response, "success=""0""")
            return false
        ; Update .xml for @classname and @children, and in case the value
        ; differs from what we set (e.g. for setting A_KeyDelay in v2).
        this.dbg.property_get("-n " this.xml.getAttribute("fullname"), response)
        if InStr(response, "<error")
            return false
        this.xml := DcLoadXml(response).selectSingleNode("/response/property")
        this.value := DBGp_Base64UTF8Decode(this.xml.text)
        return true
    }
    
    Update(tlv, prop:="") {
        if !prop || prop.getAttribute("children")
            prop := this.GetProperty()
        else
            this.xml := prop
        props := prop.selectNodes("property")
        value2 := this.values[2]
        this.value := props.length ? "" : DBGp_Base64UTF8Decode(prop.text)
        if !(this.values[2] == value2) ; Prevent unnecessary redraw and flicker.
            tlv.RefreshValues(this)
        this.UpdateChildren(tlv, props)
    }
}

class DcContextNode extends DcPropertyParentNode
{
    static expandable := true
    
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
        this.dbg.context_get("-c " this.context, response)
        xml := DcLoadXml(response)
        return xml.selectNodes("/response/property")
    }
    
    GetChildren() {
        props := this.GetProperties()
        return DcPropertyNode.FromXmlNodes(props, this.dbg)
    }
    
    GetWindowTitle() {
        return this.context=0 ? "Local vars" : "Global vars"
    }
    
    Update(tlv) {
        props := this.GetProperties()
        this.UpdateChildren(tlv, props)
    }
}

DebugBegin(dbg, initPacket) {
    if !(node := PendingThreads.Delete(dbg.thread += 0))
        return dbg.detach(), dbg.Close()
    dbg.feature_set("-n max_depth -v 0")
    dbg.feature_set("-n max_data -v " ShortValueLimit)
    dbg.feature_get("-n language_version", response)
    dbg.version := RegExReplace(DcLoadXml(response).selectSingleNode("response").text, " .*")
    dbg.no_base64_numbers := dbg.version && dbg.version <= "1.1.24.02" ; Workaround.
    dbg.run()
    node.dbg := dbg
    DbgSessions[dbg.thread] := dbg
}

DebugBreak() {
    ; This shouldn't be called, but needs to be present.
}

DebugEnd(dbg) {
    DbgSessions.Delete(dbg.thread)
    close := []
    for hwnd, dv in DebugVars.Instances {
        tlv := dv.TLV, root := tlv.root
        if (dbg == root.dbg) {
            close.Push(dv)
            continue
        }
        n := 1, children := root.children
        while n <= children.Length() {
            if (dbg == children[n].dbg)
                tlv.RemoveChild(root, n)
            else
                ++n
        }
    }
    for i, dv in close
        dv.Hide()
}

class DcDebugVars extends DebugVars
{
    Show(options:="", title:="") {
        return base.Show(options
            , title != "" ? title : this.TLV.root.GetWindowTitle())
    }
    
    UnregisterHwnd() {
        base.UnregisterHwnd()
        this.SetAutoRefresh(0)
        if !this.Instances.MaxIndex() {
            DetachAll()
            ExitApp
        }
    }
    
    class Control extends DebugVars.Control {
        LV_Key_F5() {
            this.root.Update(this)
        }
    }
    
    OnContextMenu(node, isRightClick, x, y) {
        try Menu DC_Menu, DeleteAll  ; In case we're interrupting a prior call.
        if node.base != DcPropertyNode
            Menu DC_Menu, Add, New window, DC_CM_NewWindow
        else
            Menu DC_Menu, Add, Inspect, DC_CM_InspectNode
        Menu DC_Menu, Add, Refresh, DC_CM_Refresh
        Menu DC_RefreshMenu, Add, Off, DC_CM_AutoRefresh
        Menu DC_RefreshMenu, Add, 0.5 s, DC_CM_AutoRefresh
        Menu DC_RefreshMenu, Add, 1.0 s, DC_CM_AutoRefresh
        Menu DC_RefreshMenu, Add, 5.0 s, DC_CM_AutoRefresh
        static refresh_intervals := [0, 500, 1000, 5000]
        for i, interval in refresh_intervals
            Menu DC_RefreshMenu, % interval=this.refresh_interval ? "Check" : "Uncheck", %i%&
        Menu DC_Menu, Add, Auto refresh, :DC_RefreshMenu
        Menu DC_Menu, Show, % x, % y
        try Menu DC_Menu, Delete
        return
        DC_CM_NewWindow:
        DC_CM_InspectNode:
        this[SubStr(A_ThisLabel,7)](node)
        return
        DC_CM_Refresh:
        this.Refresh()
        return
        DC_CM_AutoRefresh:
        this.SetAutoRefresh(refresh_intervals[A_ThisMenuItemPos])
        return
    }
    
    OnDoubleClick(node) {
        if node.base != DcPropertyNode
            this.NewWindow(node)
        else
            this.InspectNode(node)
    }
    
    InspectNode(node) {
        InspectProperty(node.dbg, node.xml.getAttribute("fullname"))
    }
    
    NewWindow(node) {
        dv := new this.base(node.Clone())
        dv.Show()
    }
    
    refresh_interval := 0
    SetAutoRefresh(interval) {
        this.refresh_interval := interval
        timer := this.timer
        if !interval {
            if timer {
                SetTimer % timer, Delete
                this.timer := ""
            }
            return 
        }
        if !timer
            this.timer := timer := ObjBindMethod(this, "Refresh")
        SetTimer % timer, % interval
    }
    
    Refresh() {
        this.TLV.root.Update(this.TLV)
    }
}

RefreshAll() {
    for hwnd, dv in DebugVars.Instances
        dv.Refresh()
}

DetachAll() {
    for thread, session in DbgSessions.Clone()
        session.detach(), session.Close()
}

DcLoadXml(ByRef data) {
    o := ComObjCreate("MSXML2.DOMDocument")
    o.async := false
    o.setProperty("SelectionLanguage", "XPath")
    o.loadXml(data)
    return o
}