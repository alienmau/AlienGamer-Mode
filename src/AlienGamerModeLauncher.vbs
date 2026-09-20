Option Explicit

Dim shell, fso, appRoot, powershell, mode, command, bridgeUrl, rainmeterConfig
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appRoot = fso.GetParentFolderName(WScript.ScriptFullName)
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
mode = "agent"
If WScript.Arguments.Count > 0 Then mode = LCase(WScript.Arguments(0))

Select Case mode
    Case "activate"
        command = PsCommand(appRoot & "\AlienGamerModeCommand.ps1", "-Activate")
    Case "agent-activate"
        command = PsCommand(appRoot & "\AlienGamerModeAgent.ps1", "-Activate")
    Case "stop"
        command = PsCommand(appRoot & "\AlienGamerModeCommand.ps1", "-Stop")
    Case "record-toggle"
        bridgeUrl = "http://127.0.0.1:27843/v2/status"
        If WScript.Arguments.Count > 1 Then bridgeUrl = WScript.Arguments(1)
        rainmeterConfig = "AlienGamerMode"
        If WScript.Arguments.Count > 2 Then rainmeterConfig = WScript.Arguments(2)
        command = PsCommand(appRoot & "\AlienGamerEventRecorder.ps1", "-Toggle -BridgeUrl " & Quote(bridgeUrl) & " -RainmeterConfig " & Quote(rainmeterConfig))
    Case "mark-incident"
        bridgeUrl = "http://127.0.0.1:27843/v2/status"
        If WScript.Arguments.Count > 1 Then bridgeUrl = WScript.Arguments(1)
        rainmeterConfig = "AlienGamerMode"
        If WScript.Arguments.Count > 2 Then rainmeterConfig = WScript.Arguments(2)
        command = PsCommand(appRoot & "\AlienGamerEventRecorder.ps1", "-MarkIncident -BridgeUrl " & Quote(bridgeUrl) & " -RainmeterConfig " & Quote(rainmeterConfig))
    Case Else
        command = PsCommand(appRoot & "\AlienGamerModeAgent.ps1", "")
End Select

' Window style 0 prevents a console from being allocated visibly. The launcher
' returns immediately; the agent and commands keep their own lifecycle.
shell.Run command, 0, False

Function PsCommand(scriptPath, arguments)
    PsCommand = Quote(powershell) & " -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Quote(scriptPath)
    If Len(arguments) > 0 Then PsCommand = PsCommand & " " & arguments
End Function

Function Quote(value)
    Quote = Chr(34) & Replace(CStr(value), Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
