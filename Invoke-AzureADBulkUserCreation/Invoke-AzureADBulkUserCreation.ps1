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
Version   : 1.0
Date      : 27-February-2018
Update    : 28-February-2018
Requires  : PowerShell Version 5.0 or above
Module    : AzureADPreview Version 2.0.0.154 or above
Product   : Azure Active Directory

.LINK
To provide feedback or for further assistance please visit:
https://charbelnemnom.com

.EXAMPLE
./Invoke-AzureADBulkUserCreation -CSVFilePath <FilePath> -Verbose
This example will import all users from a CSV File and then create Azure AD account.
#>

[CmdletBinding()]
Param(
	[Parameter(Position=0)]
	[ValidateScript({Test-Path $_})]
	[string[]]$CSVFilePath = "F:\BulkAzureADUserCreation.csv"
)

Try {
	$CSVData = @(Import-CSV -Path $CSVFilePath -ErrorAction Stop)
    Write-Verbose "Successfully imported entries from $CSVFilePath"
    Write-Verbose "Total no. of entries in CSV are : $($CSVData.count)"
} Catch {
    Write-Verbose "Failed to read from the CSV file $CSVFilePath. Script exiting"
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
                        -Mobile $Entry.Mobile
                        
        Write-Verbose "$DisplayName : Azure AD User Account created successfully"    
                    
    
    } Catch {
        Write-Warning "$DisplayName : Error occurred while creating Azure AD Account. $_"
        }
}