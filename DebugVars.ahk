
#Include DebugVarsGui.ahk

global ShortValueLimit := 64
global MaxChildren := 1000

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

OnMessage(2, Func("OnWmDestroy"))
OnWmDestroy(wParam, lParam, msg, hwnd) {
    if !DebugVarsGui.Instances.MaxIndex() {
        DetachAll()
        ExitApp
    }
}

(new DebugVarsGui(new DvAllScriptsNode)).Show()

class DvAllScriptsNode extends DvNodeBase
{
    GetChildren() {
        children := []
        for i, script_id in this.GetScripts()
            children.Push(new DvScriptNode(script_id))
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
            tlv.InsertChild(this, nc++, new DvScriptNode(script_id))
        }
        base.Update(tlv)
    }
}

class DvScriptNode extends Dv2ContextsNode
{
    __new(hwnd) {
        this.hwnd := hwnd
        WinGetTitle title, ahk_id %hwnd%
        title := RegExReplace(title, " - AutoHotkey v\S*$")
        SplitPath title, name, dir
        this.values := [name, format("0x{:x}", hwnd) "  -  " dir]
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
        return base.GetChildren()
    }
    
    GetWindowTitle() {
        return format("Variables - {} (0x{:x})", this.values[1], this.hwnd)
    }
}

DebugBegin(dbg, initPacket) {
    if !(node := PendingThreads.Delete(dbg.thread += 0))
        return dbg.detach(), dbg.Close()
    dbg.feature_set("-n max_depth -v 0")
    dbg.feature_set("-n max_data -v " ShortValueLimit)
    dbg.feature_set("-n max_children -v " MaxChildren)
    dbg.feature_get("-n language_version", response)
    dbg.version := RegExReplace(DvLoadXml(response).selectSingleNode("response").text, " .*")
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
    for hwnd, dv in VarTreeGui.Instances {
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

DetachAll() {
    for thread, session in DbgSessions.Clone()
        session.detach(), session.Close()
}
