#Requires -RunAsAdministrator

$TaskName = 'Enable-TaskSchedulerHistory'
$TaskPath = '\Task Scheduler'
$Description = @"
Version 21.1.18  
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true  
Runs as SYSTEM and does not display any progress or results  
"@

$Action = @{
    Execute = 'wevtutil.exe'
    Argument = 'set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true'
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
$ScheduledTask = @{
    Action = New-ScheduledTaskAction @Action
    Principal = New-ScheduledTaskPrincipal @Principal
    Settings = New-ScheduledTaskSettingsSet @Settings
    Description = $Description
}

New-ScheduledTask @ScheduledTask | Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Force

$Scheduler = New-Object -ComObject "Schedule.Service"
$Scheduler.Connect()
$GetTask = $Scheduler.GetFolder($TaskPath).GetTask($TaskName)
$GetSecurityDescriptor = $GetTask.GetSecurityDescriptor(0xF)
if ($GetSecurityDescriptor -notmatch 'A;;0x1200a9;;;AU') {
    $GetSecurityDescriptor = $GetSecurityDescriptor + '(A;;GRGX;;;AU)'
    $GetTask.SetSecurityDescriptor($GetSecurityDescriptor, 0)
}