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
$TaskName = 'Register to OSDeploy'
$TaskPath = '\Corporate\Owner'
$Description = @"
Changes the Registered Owner and Organization to OSDeploy  
Runs as SYSTEM and does not display any progress or results  
Version 21.1.21
"@
#======================================================================================
#   Splat the Task
$Action1 = @{Execute = 'reg.exe';Argument = 'add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /V RegisteredOwner /T REG_SZ /D "OSDeploy" /F'}
$Action2 = @{Execute = 'reg.exe';Argument = 'add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /V RegisteredOrganization /T REG_SZ /D "OSDeploy" /F'}
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
    Action = (New-ScheduledTaskAction @Action1),(New-ScheduledTaskAction @Action2)
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