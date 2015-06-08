/*
TODO:
  show a separate dialog for editing really large (or multi-line) values
  consider how to display `n and other such characters

*/

#Warn,, StdOut
global A_Args := [["line1`nline2","B"],["C",["D"],"E"]]

dv := new DebugVars(new GlobalVarProvider("
    (LTrim
        A_ScriptDir
        A_ScriptName
        A_ScriptFullPath
        A_ScriptHwnd
        A_Args
    )"))
dv.Show(), dv := ""
while DebugVars.Instances.Length()
    Sleep 1000
ExitApp

#Include DebugVars.ahk
#Include DebugVars.Providers.ahk
