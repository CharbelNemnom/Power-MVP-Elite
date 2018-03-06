# Invoke-AzureADBulkUserCreation.ps1
## Azure Active Directory Bulk User Creation Tool

This tool is written to import list of users from a CSV file, and then create the corresponding user accounts in Azure Active Directory (AAD).

Run the script as follows:

.\Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username\Password> -Verbose

This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory.

Here is a screenshot showing the creation is completed.