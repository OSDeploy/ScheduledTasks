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
$TaskName = 'Set-ExecutionPolicy Restricted AtStartup'
$TaskPath = '\Corporate\PowerShell'
$Description = @"
Version 21.1.19  
Set-ExecutionPolicy Restricted -Force  
Runs as SYSTEM at startup and does not display any progress or results
"@
#======================================================================================
#   Splat the Task
$Action = @{
    Execute = 'powershell.exe'
    Argument = 'Set-ExecutionPolicy Restricted -Force'
}
$Principal = @{
    UserId = 'SYSTEM'
    RunLevel = 'Highest'
}
$Settings = @{
    AllowStartIfOnBatteries = $true
    Compatibility = 'Win8'
    MultipleInstances = 'Parallel'
    ExecutionTimeLimit = (New-TimeSpan -Minutes 60)
}
$Trigger = @{
    AtStartup = $true
}
$ScheduledTask = @{
    Action = New-ScheduledTaskAction @Action
    Principal = New-ScheduledTaskPrincipal @Principal
    Settings = New-ScheduledTaskSettingsSet @Settings
    Trigger = New-ScheduledTaskTrigger @Trigger
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