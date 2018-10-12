<#
.SYNOPSIS
Enable Just In Time VM access.

.DESCRIPTION
Automate Just in time VM request access with PowerShell.

.NOTES
File Name : Request-JITVMAccess.ps1
Author    : Charbel Nemnom
Version   : 1.0
Date      : 20-August-2018
Update    : 27-August-2018
Requires  : PowerShell Version 5.1 or later
Module    : AzureRM Version 6.7.0
Module    : Azure-Security-Center Version 0.0.22

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from any source IP. The management port will be set as specified including the number of hours.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.

.EXAMPLE
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port, source IP, and number of hours.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.

.EXAMPLE
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port, and source IP address.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.

.EXAMPLE
.\Request-JITVMAccess.ps1 -VMName [VMName] -Credential [AzureUser@domain.com] -Port [PortNumber] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from any source IP. The management port will be set as specified.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
#>

[CmdletBinding()]
Param(
    [Parameter(Position = 0, Mandatory = $True, HelpMessage = 'Specify the VM Name')]
    [Alias('VM')]
    [String]$VMName,

    [Parameter(Position = 1, Mandatory = $True, HelpMessage = 'Specify Azure Credentials')]
    [Alias('AzureCred')]
    [PSCredential]$Credential,
    
    [Parameter(Position = 2, Mandatory = $True, HelpMessage = 'Specify remote access port, must be a number between 1 and 65535.')]
    [Alias('AccessPort')]
    [ValidateRange(1, 65535)]
    [Int]$Port,
    
    [Parameter(Position = 3, HelpMessage = 'Source IP Address Prefix. (IP Address, CIDR block, or *) Default = * (Any)')]
    [Alias('SourceIP')]
    [String]$AddressPrefix = '*',

    [Parameter(Position = 4, HelpMessage = 'Specify time range in hours, valid range: 1-24 hours')]
    [Alias('Hours')]
    [ValidateRange(1, 24)]
    [Int]$Time    

)
Function Install-AzureRM {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM -AllowClobber -Confirm:$false -Verbose:$false
}
Function Install-ASC {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name Azure-Security-Center -AllowClobber -Confirm:$false -Verbose:$false
}
Function ExtractMaxDuration ([string]$InStr) {
    $Out = $InStr -replace ("[^\d]")
    try {return [int]$Out}
    catch {}
    try {return [uint64]$Out}
    catch {return 0}
}

#! Check AzureRM PowerShell Module
Try {
    Import-Module -Name AzureRM -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure RM PowerShell Module..."
}
Catch {
    Write-Warning "Azure Resource Manager PowerShell Module not found..."
    Write-Verbose "Installing Azure Resource Manager PowerShell Module..."
    Install-AzureRM
}

#! Check Azure Security Center PowerShell Module
Try {
    Import-Module -Name Azure-Security-Center -WarningAction SilentlyContinue -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure Security Center PowerShell Module..."
}
Catch {
    Write-Warning "Azure Security Center PowerShell Module not found..."
    Write-Verbose "Installing Azure Security Center PowerShell Module..."
    Install-ASC
}

#! Check Azure Cloud Connection
Try {
    Write-Verbose "Connecting to Azure Cloud..."
    Login-AzureRmAccount -Environment AzureCloud -Credential $Credential -ErrorAction Stop | Out-Null
}
Catch {
    Write-Warning "Cannot connect to Azure environment. Please check your credentials. Exiting!"
    Break
}

#! Get Azure Virtual Machine Info
$VMInfo = Get-AzureRMVM | ? {$_.Name -eq "$VMName"}

If (!$VMInfo) {
    Write-Warning "Azure virtual machine ($VMName) cannot be found. Please check your virtual machine name. Exiting!"
    Break
}

$VMAccessPolicy = Get-ASCJITAccessPolicy | Select -ExpandProperty Properties | Select -ExpandProperty VirtualMachines | Where-Object {$_.id -like "*$VMName*"} | Select -Property Ports

If (!$VMAccessPolicy) {
    Write-Warning "Just in Time VM Access is not enabled for Azure VM ($VMName)"
    if (-Not $time) {
        Try {
            $time = Read-Host "`nEnter Max Requested Time in Hours, valid range: 1-24 hours"
        }
        Catch {
            Write-Warning "The maximum requested time entered is not in the valid range: 1-24 hours" 
            Break
        }
    }
    #! Enable Access to the VM including management Port, and Time Range in Hours
    Write-Verbose "Enabling Just in Time VM Access Policy for ($VMName)"
    Set-ASCJITAccessPolicy -VM $VMInfo.Name -ResourceGroupName $VMInfo.ResourceGroupName -Port $Port -Protocol * -AllowedSourceAddressPrefix $AddressPrefix -MaxRequestHour $time   
}

#! Request Access to the VM including management Port, Source IP and Time Range in Hours
if (-Not $time) {
    $VMAccessPolicy.PSObject.Properties | foreach-object {
        $value = $_.Value
    }
    $MaxRequest = $value | where-object {$_.Number -eq "$Port"}
    $Time = ExtractMaxDuration $MaxRequest.maxRequestAccessDuration
    Invoke-ASCJITAccess -VM $VMInfo.Name -ResourceGroupName $VMInfo.ResourceGroupName -Port $Port -AddressPrefix $AddressPrefix -Hours $Time
}
Else {
    Invoke-ASCJITAccess -VM $VMInfo.Name -ResourceGroupName $VMInfo.ResourceGroupName -Port $Port -AddressPrefix $AddressPrefix -Hours $Time
}