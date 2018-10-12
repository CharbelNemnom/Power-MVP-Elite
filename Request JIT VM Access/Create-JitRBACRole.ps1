<#
.SYNOPSIS
Create an Azure RBAC Role.

.DESCRIPTION
Create an Azure RBAC Role definition for JIT users.

.NOTES
File Name : Create-JitRBACRole.ps1
Author    : Charbel Nemnom
Version   : 1.0
Date      : 13-October-2018
Updated   : 15-October-2018
Requires  : PowerShell Version 5.1 or later
Module    : AzureRM Version 6.7.0 or later
Module    : PowerShellGet Version 1.6.7 or later
Module    : PowerShell PackageManagement Version 1.1.7.2 or later

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
.\Create-JitRBACRole.ps1
This example will create an Azure JIT Role Based Access Control (RBAC) with least privilege and assign that role to all Azure subscriptions. 
#>

Function Install-PackageManagement {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PackageManagement -Force -Confirm:$false -Verbose:$false
}

Function Install-PowerShellGet {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name PowerShellGet -Force -Confirm:$false -Verbose:$false
}

Function Install-AzureRM {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureRM -Confirm:$false -Verbose:$false
}

#! Check PowerShell Package Management Module
Try {
    Import-Module -Name PackageManagement -MinimumVersion 1.1.7.2 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShell PackageManagement Module..."
    }
Catch {
    Write-Warning "PowerShell PackageManagement Module was not found..."
    Write-Verbose "Installing the latest PowerShell PackageManagement Module..."
    Install-PackageManagement
}

#! Check PowerShellGet Module
Try {
    Import-Module -Name PowerShellGet -MinimumVersion 1.6.7 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing PowerShellGet Module..."
    }
Catch {
    Write-Warning "PowerShellGet Module was not found..."
    Write-Verbose "Installing the latest PowerShellGet Module..."
    Install-PowerShellGet
}

#! Check AzureRM PowerShell Module
Try {
    Import-Module -Name AzureRM -MinimumVersion 6.7.0 -ErrorAction Stop -Verbose:$false | Out-Null
    Write-Verbose "Importing Azure RM PowerShell Module..."
    }
Catch {
    Write-Warning "Azure RM Module was not found..."
    Write-Verbose "Installing Azure RM Module..."
    Install-AzureRM
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

#! Get all Azure Subscriptions
$AzureSubscriptions = Get-AzureRmSubscription | Where-Object {$_.Name -notlike "*Azure Active Directory*"}

#! Get Virtual Machine Contributor Role Definition 
$role = Get-AzureRmRoleDefinition "Virtual Machine Contributor"
$role.Id = $null
$role.Name = "Just In Time VM access User"
$role.Description = "Users that can enable access to Azure Virtual Machines."
$role.Actions.Clear()
$role.Actions.Add("Microsoft.Security/locations/jitNetworkAccessPolicies/read")
$role.Actions.Add("Microsoft.Security/locations/jitNetworkAccessPolicies/initiate/action")
$role.Actions.Add("Microsoft.Compute/*/read")
$role.Actions.Add("Microsoft.Compute/virtualMachines/write")
$role.AssignableScopes.Clear()
Foreach ($AzureSubscription in $AzureSubscriptions) {
$role.AssignableScopes.Add("/subscriptions/$AzureSubscription")
}
New-AzureRmRoleDefinition -Role $role