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
Version   : 1.7
Date      : 27-February-2018
Update    : 30-July-2019
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
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = 'Specify the path of the CSV file')]
    [Alias('CSVFile')]
    [string]$FilePath="AzureADBulkUserCreation.csv",
    [Parameter(Position = 1, Mandatory = $false, HelpMessage = 'Specify Credentials')]
    [Alias('Cred')]
    [PSCredential]$Credential,
    #MFA Account for Azure AD Account
    [Parameter(Position = 2, Mandatory = $false, HelpMessage = 'Specify if account is MFA enabled')]
    [Alias('2FA')]
    [Switch]$MFA
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
        Write-Warning '$DisplayName is not provided. Continuing to the next record'
        Continue
    }

    If (!$MailNickName) {
        Write-Warning '$MailNickName is not provided. Continuing to the next record'
        Continue
    }

    If (!$UserPrincipalName) {
        Write-Warning '$UserPrincipalName is not provided. Continuing to the next record'
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
    
    #See if the user exists.
    Try{
        $ADuser = Get-AzureADUser -Filter "userPrincipalName eq '$UserPrincipalName'"
        }
    Catch{}

    #If so then movea along, otherwise create the user.
    If ($ADuser)
    {
        Write-Verbose "$UserPrincipalName already exists. User will be added to group if specified."
    }
    Else
    {

        Try {    
            New-AzureADUser -DisplayName $DisplayName `
                -GivenName $Entry.GivenName `
                -Surname $Entry.Surname `
                -AccountEnabled $true `
                -MailNickName $MailNickName `
                -UserPrincipalName $UserPrincipalName `
                -PasswordProfile $PasswordProfile `
                -City $Entry.City `
                -State $Entry.State `
                -Country $Entry.Country `
                -Department $Entry.Department `
                -JobTitle $Entry.JobTitle `
                -Mobile $Entry.Mobile | Out-Null
                } 
        Catch {
            Write-Error "$DisplayName : Error occurred while creating Azure AD Account. $_"
            Break;
        }

        #Make sure the user exists now.
        Try{
            $ADuser = Get-AzureADUser -Filter "userPrincipalName eq '$UserPrincipalName'"
        }
        Catch{
            Write-Warning "$DisplayName : Newly created account could not be found.  Continuing to next user. $_"
            break;
        }

        Write-Verbose "$DisplayName : AAD Account is created successfully!"     
    }

    #Add the user to a group, creating it if necessary.
    If ($Entry.GroupNames) {
        $GroupNames = ($Entry.GroupNames).Split(";")

        Foreach ($GroupName in $GroupNames)
        {
            Try {   
                $AadGroup = Get-AzureADGroup -SearchString "$GroupName"
            }
            Catch {                
            }

            If (!$AadGroup)
            {
                Try {   
                $AadGroup = New-AzureADGroup -DisplayName "$GroupName" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
                }
                Catch {                
                    Write-Warning "Failed to create group $GroupName. Continuing to the next group."
                    Break;
                }
            }

            #Determine if user is already part of the group
            $GroupMembers = (Get-AzureADGroupMember -ObjectId $AadGroup.ObjectID | Select ObjectId)            
            If ($GroupMembers -Match $ADuser.ObjectID){
                Write-Verbose "$UserPrincipalName is already a member of Azure AD Group $GroupName"
            }
            Else
            {

                Try {   
                        #$ADuser = Get-AzureADUser -ObjectId "$UserPrincipalName"
                        Add-AzureADGroupMember -ObjectId $AadGroup.ObjectID -RefObjectId $ADuser.ObjectID 
                        Write-Verbose "Assigning the user $DisplayName to Azure AD Group $GroupName"    
                    }
                    Catch {                
                        Write-Warning "Failed to add $DisplayName to Azure AD Group $GroupName. Continuing to the next group."
                        Break;
                    }
            }
        }
    }         
    
}
