<#
.SYNOPSIS
S2D Monitoring tool.

.DESCRIPTION
Storage Spaces Direct Monitoring tool including email Alerts.

.NOTES
===========================================================================
Tool Name    : Monitor-S2D.ps1
Author       : Charbel Nemnom
Version      : 1.1
Date created : 07.12.2017
Last modified: 15.12.2017
Requires     : PowerShell Version 5.1 or above
OS           : Windows Server 2016 Version 1607
Role         : Storage Spaces Direct
PSModule     : Storage
===========================================================================

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
.\Monitor-S2D.ps1 -ClusterName <ClusterName> -Credential <DomainName\UserName>
This example will check the Storage Spaces Direct (S2D) Cluster Health,
If the cluster reports any minor or critical issues, you will receive immediate alert via email.    

.EXAMPLE
You can create a recurring task that will run every X minutes, and monitor your S2D Cluster.
Refer to 
#>

##### Parameters #####
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='Specify the name of the S2D cluster')]
    [Alias('S2DCluster')]
    [string]$ClusterName,
    [Parameter(HelpMessage='Specify Credentials')]
    [Alias('Cred')]
    [PSCredential]$Credential
     )

Try {
# Connect to S2D Cluster
    $Session = New-CimSession -Credential $Credential -ComputerName $ClusterName -ErrorAction Stop
}
Catch {
    Write-Error "Can't connect to S2D cluster: $($Error[0].Exception.Message) Exiting"
    Exit
}

# Variables
$Filedate = Get-date
$report = $null
$FromEmail = "fromemail@domain.com"
$ToEmail1 = "email1@domain.com"
$ToEmail2 = "email2@domain.com"
$email = new-object Net.Mail.MailMessage
$email.From = new-object Net.Mail.MailAddress($FromEmail)
$email.Priority = [System.Net.Mail.MailPriority]::High
$email.IsBodyHtml = $true
$email.Body = $report
$email.To.Add($ToEmail1)
$email.To.Add($ToEmail2)
$errorColor = "Red"
$warningColor = "Yellow"

# Establish Connection to SMTP server
$smtpServer = "smtp.office365.com"
$smtpCreds = new-object Net.NetworkCredential("Username", "Password")
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.UseDefaultCredentials = $false
$smtp.Credentials = $smtpCreds

# HTML Style Definition
$report += "<!DOCTYPE html  PUBLIC`"-//W3C//DTD XHTML 1.0 Strict//EN`"  `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`">"
$report += "<html xmlns=`"http://www.w3.org/1999/xhtml`"><body>"
$report += "<style>"
$report += "TABLE{border-width:2px;border-style: solid;border-color: #C0C0C0 ;border-collapse: collapse;width: 100%}"
$report += "TH{border-width: 2px;padding: 0px;border-style: solid;border-color: #C0C0C0 ;text-align: center}"
$report += "TD{border-width: 2px;padding: 0px;border-style: solid;border-color: #C0C0C0 ;text-align: center}"
$report += "TD{border-width: 2px;padding: 0px;border-style: solid;border-color: #C0C0C0 ;text-align: center}"
$report += "H1{font-family:Calibri;}"
$report += "H2{font-family:Calibri;}"
$report += "H3{font-family:Calibri;}"
$report += "Body{font-family:Calibri;}"
$report += "</style>"
$report += "<center><p style=""font-size:12px;color:#BDBDBD"">Monitor-S2D - Version: 1.1 | Created By: Charbel Nemnom [MVP] | Feedback: https://charbelnemnom.com</p></center>"

# Check if Storage Spaces Direct is in Minor Severity State
$DebugMinor    = Get-StorageSubSystem *Cluster* -CimSession $Session | Debug-StorageSubSystem -CimSession $Session | ?{$_.PerceivedSeverity -eq "Minor"}      
# Check if Storage Spaces Direct is in Critical Severity State
$DebugCritical = Get-StorageSubSystem *Cluster* -CimSession $Session | Debug-StorageSubSystem -CimSession $Session | ?{$_.PerceivedSeverity -eq "Critical"}

If ($DebugMinor.PerceivedSeverity -match "Minor") {
   Write-Verbose "Minor S2D issues found"
   $email.Subject = "Cluster: $ClusterName is in Minor Severity State! $($filedate)"
   $report +=  "<style>TH{background-color:Indigo}TR{background-color:$($warningColor)}</style>"
   # Get S2D Minor State details
   Foreach ($Minor in $DebugMinor) {
   $FaultingObjectType = ($Minor.FaultingObjectType) -replace "\."," "
   $FaultType = ($Minor.FaultType) -replace "\."," "
   $report +=  "<p style=""font-size:16px""><B>Storage Spaces Direct Cluster @ $ClusterName is in Minor Severity State! </B><br><br>" + ( $Minor | `
   Select-Object @{ Expression = { $Minor.PerceivedSeverity }; Label = "Severity" }, `
                 @{ Expression = { $Minor.FaultingObjectDescription }; Label = "Faulty Object Description" }, `
                 @{ Expression = { $Minor.FaultingObjectLocation }; Label = "Faulty Object Location" }, `
                 @{ Expression = { $FaultingObjectType }; Label = "Faulty Object Type" }, `
                 @{ Expression = { $Minor.FaultingObjectUniqueId }; Label = "Faulty Object" }, `
                 @{ Expression = { $FaultType }; Label = "Faulty Type" }, `
                 @{ Expression = { $Minor.Reason }; Label = "Reason" }, `
                 @{ Expression = { $Minor.RecommendedActions }; Label = "Action" } `
   | ConvertTo-HTML -Fragment ) + " <br>"
   } 
}
Else {
Write-Verbose "No Minor issues found"
}

If ($DebugCritical.PerceivedSeverity -match "Critical") {
   Write-Verbose "Critical S2D issues found"
   $email.Subject = "Cluster: $ClusterName is in Critical Severity State! $($filedate)"
   $report +=  "<style>TH{background-color:Indigo}TR{background-color:$($errorColor)}</style>"
   # Get S2D Critical State details
   Foreach ($Critical in $DebugCritical) {
   $FaultingObjectType = ($Critical.FaultingObjectType) -replace "\."," "
   $FaultType = ($Critical.FaultType) -replace "\."," "
   $report +=  "<p style=""font-size:16px""><B>Storage Spaces Direct Cluster @ $ClusterName is in Critical Severity State! </B><br><br>" + ( $Critical | `
   Select-Object @{ Expression = { $Critical.PerceivedSeverity }; Label = "Severity" }, `
                 @{ Expression = { $Critical.FaultingObjectDescription }; Label = "Faulty Object Description" }, `
                 @{ Expression = { $Critical.FaultingObjectLocation }; Label = "Faulty Object Location" }, `
                 @{ Expression = { $FaultingObjectType }; Label = "Faulty Object Type" }, `
                 @{ Expression = { $Critical.FaultingObjectUniqueId }; Label = "Faulty Object" }, `
                 @{ Expression = { $FaultType }; Label = "Faulty Type" }, `
                 @{ Expression = { $Critical.Reason }; Label = "Reason" }, `
                 @{ Expression = { $Critical.RecommendedActions }; Label = "Action" } `
   | ConvertTo-HTML -Fragment ) + " <br>" 
   }
}
Else {
Write-Verbose "No Critical issues found"
}
  
If ($DebugMinor -and $DebugCritical) {
     $email.Subject = "Cluster: $ClusterName is in Critical and Minor Severity State! $($filedate)"
     Write-Verbose "Finalizing Report"
	 $report +=  "</body></html>"
     Write-Verbose "Sending e-mail"
     $email.body = $report 
     $smtp.Send($email)
    }
    Elseif ($DebugMinor -or $DebugCritical) {
     Write-Verbose "Finalizing Report"
	 $report +=  "</body></html>"
     Write-Verbose "Sending e-mail" 
     $email.body = $report
     $smtp.Send($email)
    }