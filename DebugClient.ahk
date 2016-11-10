
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
    ; SetEnableChildren(true)
    dbg.feature_set("-n max_depth -v 1")
    ; 1MB seems reasonably permissive.  Note that -m 0 (unlimited according
    ; to the spec) doesn't work with v1.1.24.02 and earlier.
    dbg.property_get("-m 1048576 -n " fullname (extra_args="" ? "" : " " extra_args), response)
    dbg.feature_set("-n max_depth -v 0")
    ; SetEnableChildren(false)
    prop := loadXML(response).selectSingleNode("/response/property")
    
    if (prop.getAttribute("name") = "(invalid)") {
        MsgBox, 48,, Invalid variable name: %fullname%
        return false
    }
    
    type := prop.getAttribute("type")
    if (type != "object") {
        isReadOnly := prop.getAttribute("facet") = "Builtin"
        value := DBGp_Base64UTF8Decode(prop.text)
        VE_Create(dbg, fullname, value, type, isReadOnly)
    } else {
        dv := new DcDebugVars(new DcPropertyNode(dbg, prop))
        dv.Show()
    }
}

VE_Create(dbg, name, ByRef value, type, isReadOnly) {
    dv := new DebugVar({name: name, value: value, type: type, readonly: isReadOnly})
    dv.dbg := dbg
    dv.OnSave := Func("VE_Save")
    dv.Show()
}

VE_Save(dv, ByRef value, type) {
    dv.dbg.property_set("-n " dv.var.name " -t " type " -- " DBGp_Base64UTF8Encode(value))
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
}

class DcAllScriptsNode extends DcNodeBase
{
    static fullname := "*"
    
    GetChildren() {
        DetectHiddenWindows On
        children := []
        WinGet scripts, List, ahk_class AutoHotkey
        loop % scripts {
            script_id := scripts%A_Index%
            if (script_id = A_ScriptHwnd)
                continue
            PostMessage 0x44, 0, 0,, ahk_id %script_id%  ; WM_COMMNOTIFY, WM_NULL
            if ErrorLevel  ; Likely blocked by UIPI (won't be able to attach).
                continue
            children.Push(new DcScriptNode(script_id))
        }
        return children
    }
    
    GetWindowTitle() {
        return "Variables"
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
        this.fullname := "script/" hwnd
    }
    
    GetChildren() {
        static attach_msg := DllCall("RegisterWindowMessage", "str", "AHK_ATTACH_DEBUGGER", "uint")
        thread_id := DllCall("GetWindowThreadProcessId", "ptr", this.hwnd, "ptr", 0, "uint")
        if !this.dbg := DbgSessions[thread_id] { ; hackfix for DV_Update
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

class DcPropertyNode extends DcNodeBase
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
    
    GetChildren() {
        ; SetEnableChildren(true) ; SciTE
        this.dbg.feature_set("-n max_depth -v 1")
        this.dbg.property_get("-n " this.fullname, response)
        this.dbg.feature_set("-n max_depth -v 0")
        ; SetEnableChildren(false) ; SciTE
        xml := loadXML(response) ; SciTE
        this.xml := prop := xml.selectSingleNode("/response/property")
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
        if (InStr(response, "<error"))
            return false
        ; Update .xml for @classname and @children, and in case the value
        ; differs from what we set (e.g. for setting A_KeyDelay in v2).
        this.dbg.property_get("-n " this.xml.getAttribute("fullname"), response)
        if (InStr(response, "<error"))
            return false
        this.xml := loadXML(response).selectSingleNode("/response/property")
        this.value := DBGp_Base64UTF8Decode(this.xml.text)
        return true
    }
}

class DcContextNode extends DcNodeBase
{
    static expandable := true
    
    __new(dbg, context) {
        this.dbg := dbg
        this.context := context
        this.fullname := this.dbg.socket "/context/" context ; hackfix for DV_Update_Expand
    }
    
    values {
        get {
            return [this.GetWindowTitle(), ""]
        }
    }
    
    GetChildren() {
        this.dbg.context_get("-c " this.context, response)
        xml := loadXML(response)
        props := xml.selectNodes("/response/property")
        return DcPropertyNode.FromXmlNodes(props, this.dbg)
    }
    
    GetWindowTitle() {
        return this.context=0 ? "Local vars" : "Global vars"
    }
}

DebugBegin(session, initPacket) {
    if !(node := PendingThreads.Delete(session.thread += 0))
        return session.detach(), session.Close()
    session.feature_set("-n max_depth -v 0")
    session.feature_set("-n max_data -v " ShortValueLimit)
    session.run()
    node.dbg := session
    session.node := node
    DbgSessions[session.thread] := session
}

DebugBreak() {
    ; This shouldn't be called, but needs to be present.
}

DebugEnd(session) {
    DbgSessions.Delete(session.thread)
    global dv
    for i, node in dv.TLV.root.children {
        if (node == session.node) {
            dv.TLV.RemoveChild(dv.TLV.root, i)
            break
        }
    }
    ; dv.TLV.RemoveNode(session.node)
    session.node := ""
}

class DcDebugVars extends DebugVars
{
    Show(options:="", title:="") {
        return base.Show(options
            , title != "" ? title : this.TLV.root.GetWindowTitle())
    }
    
    UnregisterHwnd() {
        base.UnregisterHwnd()
        if !this.Instances.MaxIndex() {
            DetachAll()
            ExitApp
        }
    }
    
    class Control extends DebugVars.Control {
        LV_Key_F5() {
            if dv := DebugVars.Instances[this.hGui] {
                DV_Update(dv)
                return true
            }
        }
    }
    
    OnContextMenu(node, isRightClick, x, y) {
        try Menu DV_Menu, DeleteAll  ; In case we're interrupting a prior call.
        if node.base != DcPropertyNode {
            fn := ObjBindMethod(this, "NewWindow", node)
            Menu DV_Menu, Add, New Window, % fn
        } else {
            fn := ObjBindMethod(this, "InspectNode", node)
            Menu DV_Menu, Add, Inspect, % fn
        }
        Menu DV_Menu, Show, % x, % y
        try Menu DV_Menu, Delete
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
}

DV_Update(dv) {
    tlv := dv.TLV
    node := tlv.root
    tlv.EnableRedraw(false)
    ; Save scroll/focus
    scrollPos := tlv.ScrollPos, oldfocus := tlv.FocusedNode
    ; Reset tree
    oldch := node.children
    newch := node.children := node.GetChildren()
    ; Transfer expanded state
    DV_Update_Expand(oldch, newch, oldfocus, newfocus := "")
    ; Refresh the control
    tlv.Reset()
    ; Restore scroll/focus
    if newfocus
        tlv.FocusedNode := newfocus
    tlv.EnableRedraw(true)
    tlv.ScrollPos := scrollPos ; Must be done after EnableRedraw(true).
    ; Update window title
    WinSetTitle % "ahk_id " dv.hGui,, % node.GetWindowTitle()
}

DV_Update_Expand(oldnodes, newnodes, oldfocus, ByRef newfocus) {
    for _, oldnode in oldnodes {
        if (!oldnode.expanded && oldnode != oldfocus)
            continue
        for _, newnode in newnodes {
            if (newnode.fullname == oldnode.fullname) {
                if (oldnode == oldfocus) {
                    newfocus := newnode
                    if !oldnode.expanded
                        break
                }
                newnode.children := newnode.GetChildren()
                newnode.expanded := true
                DV_Update_Expand(oldnode.children, newnode.children, oldfocus, newfocus)
                break
            }
        }
    }
}

DetachAll() {
    for thread, session in DbgSessions.Clone()
        session.detach(), session.Close()
}

loadXML(ByRef data) {
    o := ComObjCreate("MSXML2.DOMDocument")
    o.async := false
    o.setProperty("SelectionLanguage", "XPath")
    o.loadXML(data)
    return o
}