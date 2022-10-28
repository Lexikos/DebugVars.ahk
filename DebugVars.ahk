
#include lib\dbgp.ahk
#include DebugVarsGui.ahk

ShortValueLimit := 64
MaxChildren := 1000

PendingThreads := Map()
DbgSessions := Map()

DBGp_OnBegin(DebugBegin)
DBGp_OnBreak(DebugBreak)
DBGp_OnEnd(DebugEnd)

DBGp_StartListening()

GroupAdd "all", "ahk_class AutoHotkeyGUI ahk_pid " ProcessExist()
OnExit CloseAll
CloseAll(exitReason:="", *) {
    DetectHiddenWindows false
    if exitReason && WinExist("ahk_group all") {
        ; Start a new thread which can be interrupted (OnExit can't).
        SetTimer CloseAll, -10
        return true
    }
    GroupClose "all"
    ExitApp
}

DebugVarsGui(DvAllScriptsNode()).Show()

class DvAllScriptsNode extends DvNodeBase
{
    GetChildren() {
        children := []
        for script_id in this.GetScripts()
            children.Push(DvScriptNode(script_id))
        return children
    }
    
    GetScripts() {
        DetectHiddenWindows true
        script_ids := []
        for script_id in WinGetList("ahk_class AutoHotkey",, A_ScriptFullPath) {
            try
                PostMessage 0x44, 0, 0, script_id ; WM_COMMNOTIFY, WM_NULL
            catch
                continue ; Likely blocked by UIPI (won't be able to attach).
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
        while nc <= children.Length {
            node := children[nc]
            ns := 0
            while ++ns <= new_scripts.Length {
                if (new_scripts[ns] == node.hwnd) {
                    new_scripts.RemoveAt(ns), ++nc
                    continue 2
                }
            }
            tlv.RemoveChild(this, nc)
        }
        for script_id in new_scripts {
            tlv.InsertChild(this, nc++, DvScriptNode(script_id))
        }
        super.Update(tlv)
    }
}

class DvScriptNode extends Dv2ContextsNode
{
    __new(hwnd) {
        this.hwnd := hwnd
        title := RegExReplace(WinGetTitle(hwnd), " - AutoHotkey v\S*$")
        SplitPath title, &name, &dir
        this.values := [name, format("0x{:x}", hwnd) "  -  " dir]
    }
    
    GetChildren() {
        static attach_msg := DllCall("RegisterWindowMessage", "str", "AHK_ATTACH_DEBUGGER", "uint")
        thread_id := DllCall("GetWindowThreadProcessId", "ptr", this.hwnd, "ptr", 0, "uint")
        if !this.dbg := DbgSessions.Get(thread_id, 0) {
            PendingThreads[thread_id] := this
            began := 0 ; For instant timeout if PostMessage fails.
            try {
                PostMessage attach_msg,,,, this.hwnd
                began := A_TickCount
            }
        }
        Loop {
            if this.dbg
                break
            if (A_TickCount-began > 5000) {
                PendingThreads.Delete(thread_id)
                return [{values: ["", "Failed to attach."]}]
            }
            Sleep 15
        }
        return super.GetChildren()
    }
    
    GetWindowTitle() {
        return format("Variables - {} (0x{:x})", this.values[1], this.hwnd)
    }
}

DebugBegin(dbg, initPacket) {
    if !(node := PendingThreads.Delete(dbg.thread)) {
        dbg.detach()
        dbg.Close()
        return
    }
    dbg.feature_set("-n max_depth -v 0")
    dbg.feature_set("-n max_data -v " ShortValueLimit)
    dbg.feature_set("-n max_children -v " MaxChildren)
    response := dbg.feature_get("-n language_version")
    dbg.version := RegExReplace(DvLoadXml(response).selectSingleNode("response").text, " .*")
    dbg.no_base64_numbers := dbg.version && VerCompare(dbg.version, "1.1.24.02") <= 0 ; Workaround.
    dbg.run()
    node.dbg := dbg
    DbgSessions[dbg.thread] := dbg
}

DebugBreak(*) {
    ; This shouldn't be called, but needs to be present.
}

DebugEnd(dbg) {
    DbgSessions.Delete(dbg.thread)
    close := []
    for hwnd in WinGetList("ahk_group all") {
        if !(dv := GuiFromHwnd(hwnd)) || !(dv is DebugVarsGui)
            continue
        tlv := dv.TLV, root := tlv.root
        if (dbg == root.dbg) {
            close.Push(dv)
            continue
        }
        n := 1, children := root.children
        while n <= children.Length {
            if (dbg == children[n].dbg)
                tlv.RemoveChild(root, n)
            else
                ++n
        }
    }
    for i, dv in close
        dv.Hide()
}

DetachAll() {
    for thread, session in DbgSessions.Clone()
        session.detach(), session.Close()
}
