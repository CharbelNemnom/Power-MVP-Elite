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
Version   : 1.1
Date      : 27-February-2018
Update    : 06-March-2018
Requires  : PowerShell Version 5.0 or above
Module    : AzureADPreview Version 2.0.0.154 or above
Product   : Azure Active Directory

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
./Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username\Password> -Verbose
This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory.
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
    Install-Module -Name AzureADPreview -Force        
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
    Import-Module -Name AzureADPreview -ErroAction Stop | Out-Null
    }
Catch {
    Write-Verbose "Azure AD PowerShell Module not found..."
    Write-Verbose "Installing Azure AD PowerShell Module..."
    Install-AzureAD
    }

Write-Verbose "Connecting to Azure AD..."
Connect-AzureAD -Credential $Credential 

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
    Write-Warning "$PasswordProfile is not provided. Setting it to Random password"
    $Password = "Randompwd1$"
    }
Else {
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = $Password
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
                        
        Write-Verbose "$DisplayName : User Account is created successfully"    
                    
    
    } Catch {
        Write-Warning "$DisplayName : Error occurred while creating Azure AD Account. $_"
        }
}