#======================================================================================
#   Run as Administrator Elevated
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Verbose "Checking User Account Control settings" -Verbose
    if ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).EnableLUA -eq 0) {
        #UAC Disabled
        Write-Verbose "User Account Control is Disabled" -Verbose
        Write-Verbose "You will need to correct your UAC Settings before running this script" -Verbose
        Write-Verbose "Try running this script in an Elevated PowerShell session ... Exiting" -Verbose
        Start-Sleep -s 10
        Exit 0
    } else {
        #UAC Enabled
        Write-Verbose "UAC is Enabled. Relaunching script with Elevated Permissions" -Verbose
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
        Exit 0
    }
} else {
    Write-Verbose "Running with Elevated Permissions" -Verbose
}
#======================================================================================
#   Task Properties
$TaskName = 'Remove-LocalComputerPolicy'
$TaskPath = '\Corporate\Policies'
$Description = @"
Deletes all files in $env:SystemRoot\System32\GroupPolicy\Machine  
Transcripts are stored in $env:SystemRoot\Logs\Policies  
Runs as SYSTEM and does not display any progress or results  
PowerShell Encoded Script  
Version 21.1.21
"@
#======================================================================================
#   Script
$TaskScript = @'
$TaskName = 'Remove-LocalComputerPolicy'
#======================================================================================
#   Logs
#======================================================================================
$TaskLogs = "$env:SystemRoot\Logs\Policies"
if (!(Test-Path $TaskLogs)) {New-Item $TaskLogs -ItemType Directory -Force | Out-Null}
$TaskLogName = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$TaskName.log"
Start-Transcript -Path (Join-Path $TaskLogs $TaskLogName)
#======================================================================================
#   Main
#======================================================================================
if (Test-Path $env:SystemRoot\System32\GroupPolicy\Machine) {
    Remove-Item $env:SystemRoot\System32\GroupPolicy\Machine\* -Recurse -Force -ErrorAction SilentlyContinue
}
#======================================================================================
#   Complete
#======================================================================================
Stop-Transcript
'@
#======================================================================================
#   Encode the Script
$EncodedCommand = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($TaskScript))
#======================================================================================
#   Splat the Task
$Action = @{
    Execute = 'powershell.exe'
    Argument = "-ExecutionPolicy ByPass -EncodedCommand $EncodedCommand"
}
$Principal = @{
    UserId = 'NT AUTHORITY\SYSTEM'
    LogonType = 'ServiceAccount'
    RunLevel = 'Highest'
}
$Settings = @{
    AllowStartIfOnBatteries = $true
    Compatibility = 'Win8'
    DontStopIfGoingOnBatteries = $true
    DontStopOnIdleEnd = $true
    ExecutionTimeLimit = (New-TimeSpan -Minutes 60)
    MultipleInstances = 'IgnoreNew'
    Priority = 0
    StartWhenAvailable = $true
}
$ScheduledTask = @{
    Action = New-ScheduledTaskAction @Action
    Principal = New-ScheduledTaskPrincipal @Principal
    Settings = New-ScheduledTaskSettingsSet @Settings
    Description = $Description
}
#======================================================================================
#   Build the Task
New-ScheduledTask @ScheduledTask | Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Force
#======================================================================================
#   Apply Authenticated User Permissions
$Scheduler = New-Object -ComObject "Schedule.Service"
$Scheduler.Connect()
$GetTask = $Scheduler.GetFolder($TaskPath).GetTask($TaskName)
$GetSecurityDescriptor = $GetTask.GetSecurityDescriptor(0xF)
if ($GetSecurityDescriptor -notmatch 'A;;0x1200a9;;;AU') {
    $GetSecurityDescriptor = $GetSecurityDescriptor + '(A;;GRGX;;;AU)'
    $GetTask.SetSecurityDescriptor($GetSecurityDescriptor, 0)
}