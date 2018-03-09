<#
//-----------------------------------------------------------------------

//     Copyright (c) {charbelnemnom.com}. All rights reserved.

//-----------------------------------------------------------------------

.SYNOPSIS
Create Azure AD User Account.

.DESCRIPTION
Azure AD Bulk User Creation.

.NOTES
File Name : Invoke-AzureADBulkUserCreation.ps1
Author    : Charbel Nemnom
Version   : 1.3
Date      : 27-February-2018
Update    : 08-March-2018
Requires  : PowerShell Version 3.0 or above
Module    : AzureAD Version 2.0.0.155 or above
Product   : Azure Active Directory

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
./Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username\Password> -Verbose
This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory.
The user will be asked to change his password at first log on.
#>

[CmdletBinding()]
Param(
    [Parameter(Position=0, Mandatory=$True, HelpMessage='Specify the path of the CSV file')]
    [Alias('CSVFile')]
    [string]$FilePath,
    [Parameter(Position=1, Mandatory=$True, HelpMessage='Specify Credentials')]
    [Alias('Cred')]
    [PSCredential]$Credential
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
    Connect-AzureAD -Credential $Credential -ErrorAction Stop | Out-Null
}
Catch {
    Write-Verbose "Cannot connect to Azure AD. Please check your credentials. Exiting!"
    Break
}

Foreach($Entry in $CSVData) {
    # Verify that mandatory properties are defined for each object
    $DisplayName = $Entry.DisplayName
    $MailNickName = $Entry.MailNickName
    $UserPrincipalName = $Entry.UserPrincipalName
    $Password = $Entry.PasswordProfile
    
If(!$DisplayName) {
    Write-Warning "$DisplayName is not provided. Continue to the next record"
    Continue
}

If(!$MailNickName) {
     Write-Warning "$MailNickName is not provided. Continue to the next record"
    Continue
}

If(!$UserPrincipalName) {
    Write-Warning "$UserPrincipalName is not provided. Continue to the next record"
    Continue
    }

If(!$Password) {
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
    } 
Catch {
    Write-Error "$DisplayName : Error occurred while creating Azure AD Account. $_"
    }
}