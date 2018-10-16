<#
.SYNOPSIS
Enable Just In Time VM access.

.DESCRIPTION
Automate Just in time VM request access with PowerShell.

.NOTES
File Name : Request-JITVMAccess.ps1
Author    : Charbel Nemnom
Version   : 2.0
Date      : 20-August-2018
Updated   : 16-October-2018
Requires  : PowerShell Version 5.1 or later
Module    : AzureRM Version 6.10.0 or later
Module    : AzureRM.Security Version 0.2.0 (preview)
Module    : PowerShellGet Version 1.6.7 or later
Module    : PowerShell PackageManagement Version 1.1.7.2 or later

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE1
.\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from your current public IP address.
The management port will be set as specified including the number of hours. You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.
If the time specified is greater than the time set by the policy, the script will force you to enter the valid time, and then request VM access.

.EXAMPLE2
.\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Time [Hours] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port, source IP, and number of hours.
You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.
If the time specified is greater than the time set by the policy, the script will force you to enter the valid time, and then request VM access.

.EXAMPLE3
.\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM including the management port,and source IP address.
You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.

.EXAMPLE4
.\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -Verbose
This example will enable Just in Time VM Access for a particular Azure VM from your current public IP address.
The management port will be set as specified. You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.
#>

[CmdletBinding()]
Param(
    [Parameter(Position = 0, Mandatory = $True, HelpMessage = 'Specify the VM Name')]
    [Alias('VM')]
    [String]$VMName,
 
    [Parameter(Position = 1, Mandatory = $True, HelpMessage = 'Specify remote access port, must be a number between 1 and 65535.')]
    [Alias('AccessPort')]
    [ValidateRange(1, 65535)]
    [Int]$Port,
    
    [Parameter(Position = 2, HelpMessage = 'Source IP Address Prefix. (IP Address, or CIDR block) Default = Your IP')]
    [Alias('SourceIP')]
    [String]$AddressPrefix,

    [Parameter(Position = 3, HelpMessage = 'Specify time range in hours, valid range: 1-24 hours')]
    [Alias('Hours')]
    [ValidateRange(1, 24)]
    [Int]$Time
)

Function Install-PackageManagement {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PackageManagement  -RequiredVersion 1.1.7.2 -Confirm:$false -Verbose:$false
}

Function Install-PowerShellGet {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PowerShellGet -RequiredVersion 1.6.7 -Confirm:$false -Verbose:$false
}

Function Install-AzureRM {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM -RequiredVersion 6.10.0 -Confirm:$false -Verbose:$false
}

Function Install-AzureSecurity {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM.Security -AllowPrerelease -Confirm:$false -Verbose:$false
}

Function ExtractMaxDuration ([string]$InStr) {
    $Out = $InStr -replace ("[^\d]")
    try {return [int]$Out}
    catch {}
    try {return [uint64]$Out}
    catch {return 0}
}

Function Enable-JITVMAccess {
    $JitPolicy = (@{
            id    = "$($VMInfo.Id)"
            ports = (@{
                    number                     = $Port;
                    protocol                   = "*";
                    allowedSourceAddressPrefix = @("$AddressPrefix");
                    maxRequestAccessDuration   = "PT$($time)H"
                })   
        })
    $JitPolicyArr = @($JitPolicy)
    #! Enable Access to the VM including management Port, and Time Range in Hours
    Write-Verbose "Enabling Just in Time VM Access Policy for ($VMName) on port number $Port for maximum $time hours..."
    Set-AzureRmJitNetworkAccessPolicy -VirtualMachine $JitPolicyArr -ResourceGroupName $VMInfo.ResourceGroupName -Location $VMInfo.Location -Name "default" -Kind "Basic" | Out-Null
}

Function Invoke-JITVMAccess {
    $SubID = (Get-AzureRmContext).Subscription.Id
    $JitPolicy = (@{
            id    = "$($VMInfo.Id)"
            ports = (@{
                    number                     = $Port;
                    endTimeUtc                 = "$endTimeUtc";  
                    allowedSourceAddressPrefix = @("$AddressPrefix")
                })
             
        })
    $JitPolicyArr = @($JitPolicy)
    Write-Verbose "Enabling VM Request access for ($VMName) from IP $AddressPrefix on port number $Port for $Time hours..."
    Start-AzureRmJitNetworkAccessPolicy -ResourceId "/subscriptions/$SubID/resourceGroups/$($VMInfo.ResourceGroupName)/providers/Microsoft.Security/locations/$($VMInfo.Location)/jitNetworkAccessPolicies/default" -VirtualMachine $JitPolicyArr | Out-Null
}

#! Check PowerShell Package Management Module
Try {
    Import-Module -Name PackageManagement -RequiredVersion 1.1.7.2 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShell PackageManagement Module..."
}
Catch {
    Write-Warning "PowerShell PackageManagement Module requires update..."
    Write-Verbose "Installing the latest PowerShell PackageManagement Module..."
    Install-PackageManagement
}

#! Check PowerShellGet Module
Try {
    Import-Module -Name PowerShellGet -RequiredVersion 1.6.7 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShellGet Module..."
}
Catch {
    Write-Warning "PowerShellGet Module requires update..."
    Write-Verbose "Installing the latest PowerShellGet Module..."
    Install-PowerShellGet
}

#! Check AzureRM PowerShell Module
Try {
    Import-Module -Name AzureRM -RequiredVersion 6.10.0 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure RM PowerShell Module..."
}
Catch {
    Write-Warning "Azure RM Module requies update..."
    Write-Verbose "Installing the latest Azure RM Module..."
    Install-AzureRM
}

#! Check Azure Security PowerShell Module
Try {
    Import-Module -Name AzureRM.Security -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure RM Security PowerShell Module..."
}
Catch {
    Write-Warning "Azure RM Security PowerShell Module was not found..."
    Write-Verbose "Installing Azure RM Security PowerShell Module..."
    Install-AzureSecurity
}

#! Check Azure Cloud Connection
Try {
    Write-Verbose "Connecting to Azure Cloud..."
    Login-AzureRmAccount -Environment AzureCloud -ErrorAction Stop | Out-Null
}
Catch {
    Write-Warning "Cannot connect to Azure environment. Please check your credentials. Exiting!"
    Break
}

#! Get Azure Virtual Machine Info
Write-Verbose "Get all Azure Subscriptions..."
$AzureSubscriptions = Get-AzureRmSubscription | Where-Object {$_.Name -notlike "*Azure Active Directory*"}
$MaxSub = ($AzureSubscriptions.Count) - 1
$Sub = 0
do {
    Set-AzureRmContext -SubscriptionId $AzureSubscriptions[$Sub].Id | Out-Null
    $VMInfo = Get-AzureRMVM | Where-Object {$_.Name -eq "$VMName"} 
    $Sub++ 
} Until ($VMInfo.Name -eq "$VMName" -or $Sub -gt $MaxSub)
   
If (!$VMInfo) {
    Write-Warning "Azure virtual machine ($VMName) cannot be found. Please check your virtual machine name. Exiting!"
    Break
}

$VMAccessPolicy = (Get-AzureRmJitNetworkAccessPolicy).VirtualMachines | Where-Object {$_.Id -like "*$VMName*"} | Select -ExpandProperty Ports

If (!$AddressPrefix) {
    $AddressPrefix = Invoke-RestMethod 'http://ipinfo.io/json' -Verbose:$false | Select-Object -ExpandProperty IP
}

#! Check if Just in Time VM Access is enabled
If (!$VMAccessPolicy) {
    Write-Warning "Just in Time VM Access is not enabled for ($VMName)..."
    if (-Not $Time) {
        do {
            $Time = Read-Host "`nEnter Max Requested Time in Hours, valid range: 1-24 hours"
        } Until ($Time -le 24)
    }
    Enable-JITVMAccess    
}
Else {
    #! Check if the specified Port is enabled in Azure Security Center
    $AccessPolicy = $VMAccessPolicy | Where-Object {$_.Number -eq "$Port"}
    If (!$AccessPolicy) {
        Write-Warning "The Specified management port $Port for ($VMName) is not enabled in Azure Security Center..."
        do {
            $Time = Read-Host "`nEnter Max Requested Time in Hours, valid range: 1-24 hours"
        } Until ($Time -le 24)
        Enable-JITVMAccess
    }
}

#! Request Access to the VM including management Port, Source IP and Time range in Hours
#! If time is NOT specified, then extract max time and request VM access
If (!$Time) {
    $AccessPolicy = $VMAccessPolicy | Where-Object {$_.Number -eq "$Port"}
    $Time = ExtractMaxDuration $AccessPolicy.MaxRequestAccessDuration
    $Date = (Get-Date).ToUniversalTime().AddHours($Time) 
    $endTimeUtc = Get-Date -Date $Date -Format o
    Invoke-JITVMAccess
}
#! If time is specified, then Extract Max Time and validate
Else {
    $AccessPolicy = $VMAccessPolicy | Where-Object {$_.Number -eq "$Port"}
    $TimeSet = ExtractMaxDuration $AccessPolicy.MaxRequestAccessDuration
    #! If the time specified is greater than the time set by the policy
    If ($AccessPolicy -and $Time -gt $TimeSet) {
        do {
            Write-Warning "The requested access time for ($VMName) is not within the allowed time policy..."
            $Time = Read-Host "`nEnter access request Time in Hours, valid range: 1-$TimeSet hours"
        } until ($Time -le $TimeSet)
        $Date = (Get-Date).ToUniversalTime().AddHours($Time) 
        $endTimeUtc = Get-Date -Date $Date -Format o
        Invoke-JITVMAccess
    }
    Else {
        $Date = (Get-Date).ToUniversalTime().AddHours($Time) 
        $endTimeUtc = Get-Date -Date $Date -Format o
        Invoke-JITVMAccess
    }
}