<#
//-----------------------------------------------------------------------

//     Copyright (c) {charbelnemnom.com}. All rights reserved.

//-----------------------------------------------------------------------

.SYNOPSIS
Create Azure AD User Account.

.DESCRIPTION
Azure AD Bulk user creation and assign the new users to an Azure AD group.

.NOTES
File Name : Invoke-AzureADBulkUserCreation.ps1
Author    : Charbel Nemnom
Version   : 1.6
Date      : 27-February-2018
Update    : 08-May-2019
Requires  : PowerShell Version 3.0 or above
Module    : AzureAD Version 2.0.0.155 or above
Product   : Azure Active Directory

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE-1
./Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username\Password> -Verbose
This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory.
The user will be asked to change his password at first log on.

.EXAMPLE-2
./Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username\Password> -AadGroupName <AzureAD-GroupName> -Verbose
This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory.
The user will be a member of the specified Azure AD Group Name.
The user will be asked to change his password at first log on.
#>

[CmdletBinding()]
Param(
    [Parameter(Position = 0, Mandatory = $True, HelpMessage = 'Specify the path of the CSV file')]
    [Alias('CSVFile')]
    [string]$FilePath,
    [Parameter(Position = 1, Mandatory = $false, HelpMessage = 'Specify Credentials')]
    [Alias('Cred')]
    [PSCredential]$Credential,
    #MFA Account for Azure AD Account
    [Parameter(Position = 2, Mandatory = $false, HelpMessage = 'Specify if account is MFA enabled')]
    [Alias('2FA')]
    [Switch]$MFA,
    [Parameter(Position = 3, Mandatory = $false, HelpMessage = 'Specify Azure AD Group Name')]
    [Alias('AADGN')]
    [string]$AadGroupName
)
Function Install-AzureAD {
    Set-PSRepository -Name PSGallery -Installation Trusted -Verbose:$false
    Install-Module -Name AzureAD -AllowClobber -Verbose:$false
}

Try {
    $CSVData = @(Import-CSV -Path $FilePath -ErrorAction Stop)
    Write-Verbose "Successfully imported entries from $FilePath"
    Write-Verbose "Total no. of entries in CSV are : $($CSVData.count)"
} 
Catch {
    Write-Verbose "Failed to read from the CSV file $FilePath Exiting!"
    Break
}

Try {
    Import-Module -Name AzureAD -ErrorAction Stop -Verbose:$false | Out-Null
}
Catch {
    Write-Verbose "Azure AD PowerShell Module not found..."
    Write-Verbose "Installing Azure AD PowerShell Module..."
    Install-AzureAD
}

Try {
    Write-Verbose "Connecting to Azure AD..."
    if ($MFA) {
        Connect-AzureAD -ErrorAction Stop | Out-Null
    }
    Else {
        Connect-AzureAD -Credential $Credential -ErrorAction Stop | Out-Null
    }
}
Catch {
    Write-Verbose "Cannot connect to Azure AD. Please check your credentials. Exiting!"
    Break
}

Foreach ($Entry in $CSVData) {
    # Verify that mandatory properties are defined for each object
    $DisplayName = $Entry.DisplayName
    $MailNickName = $Entry.MailNickName
    $UserPrincipalName = $Entry.UserPrincipalName
    $Password = $Entry.PasswordProfile
    
    If (!$DisplayName) {
        Write-Warning '$DisplayName is not provided. Continue to the next record'
        Continue
    }

    If (!$MailNickName) {
        Write-Warning '$MailNickName is not provided. Continue to the next record'
        Continue
    }

    If (!$UserPrincipalName) {
        Write-Warning '$UserPrincipalName is not provided. Continue to the next record'
        Continue
    }

    If (!$Password) {
        Write-Warning "Password is not provided for $DisplayName in the CSV file!"
        $Password = Read-Host -Prompt "Enter desired Password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
        $PasswordProfile.Password = $Password
        $PasswordProfile.EnforceChangePasswordPolicy = 1
        $PasswordProfile.ForceChangePasswordNextLogin = 1
    }
    Else {
        $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
        $PasswordProfile.Password = $Password
        $PasswordProfile.EnforceChangePasswordPolicy = 1
        $PasswordProfile.ForceChangePasswordNextLogin = 1
    }   
    
    Try {    
        New-AzureADUser -DisplayName $DisplayName `
            -AccountEnabled $true `
            -MailNickName $MailNickName `
            -UserPrincipalName $UserPrincipalName `
            -PasswordProfile $PasswordProfile `
            -City $Entry.City `
            -Country $Entry.Country `
            -Department $Entry.Department `
            -JobTitle $Entry.JobTitle `
            -Mobile $Entry.Mobile | Out-Null
        Write-Verbose "$DisplayName : AAD Account is created successfully!"     
        If ($AadGroupName) {
            Try {   
                $AadGroupID = Get-AzureADGroup -SearchString "$AadGroupName"
            }
            Catch {
                Write-Error "$AadGroupName : does not exist. $_"
                Break
            }
        $ADuser = Get-AzureADUser -ObjectId "$UserPrincipalName"
        Add-AzureADGroupMember -ObjectId $AadGroupID.ObjectID -RefObjectId $ADuser.ObjectID 
        Write-Verbose "Assigning the user $DisplayName to Azure AD Group $AadGroupName"    
        }         
    } 
    Catch {
        Write-Error "$DisplayName : Error occurred while creating Azure AD Account. $_"
    }
}
