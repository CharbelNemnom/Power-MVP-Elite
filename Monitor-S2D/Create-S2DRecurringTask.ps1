# Change these three variables to whatever you want
$jobname = "Recurring S2D Monitoring"
$script =  "C:\Path\Monitor-S2D.ps1"
$repeat = (New-TimeSpan -Minutes 60)

# The script below will run as the specified user (you will be prompted for credentials),
# and it is set to be elevated to use the highest privileges.
# In addition, the task will run every 60 minutes or however long you specified in $repeat variable.
$scriptblock = [scriptblock]::Create($script)
$trigger = New-JobTrigger -Once -At (Get-Date).Date -RepeatIndefinitely -RepetitionInterval $repeat
$msg = "Enter the username and password that will run S2D monitoring task"; 
$credential = $Host.UI.PromptForCredential("Task username and password",$msg,"$env:userdomain\$env:username",$env:userdomain)

$options = New-ScheduledJobOption -RunElevated -ContinueIfGoingOnBattery -StartIfOnBattery
Register-ScheduledJob -Name $jobname -ScriptBlock $scriptblock -Trigger $trigger -ScheduledJobOption $options -Credential $credential

