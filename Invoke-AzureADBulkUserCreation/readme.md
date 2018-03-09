# Invoke-AzureADBulkUserCreation.ps1
## Azure Active Directory Bulk User Creation Tool

This tool is written to import list of users from a CSV file, and then create the corresponding user accounts in Azure Active Directory (AAD). A sample of the CSV file is included with this tool.

Run the script as follows:

.\Invoke-AzureADBulkUserCreation -FilePath <FilePath> -Credential <Username@customdomain.com> -Verbose

This example will import all users from a CSV File and then create the corresponding account in Azure Active Directory. If Azure AD PowerShell module is not present on your system, then the module will be installed automatically, and the users will be created in Azure AD. If the user password is not defined in the CSV file, you will be asked to type a random password in secure format. This tool will also force the user to change the password at next login.

Here are a couple of screenshots showing how to use this tool.

### Output 1
![invoke-azureadbulkusercreation-01](https://user-images.githubusercontent.com/13448198/37186860-7456f266-22fc-11e8-99f9-3c40e8f97970.png)

### Output 2
![invoke-azureadbulkusercreation-02](https://user-images.githubusercontent.com/13448198/37186901-9cc8cc56-22fc-11e8-9466-cb4d336e0225.png)

### Output 3
![invoke-azureadbulkusercreation-03](https://user-images.githubusercontent.com/13448198/37186915-ab02f008-22fc-11e8-903e-1eecd00dcb69.png)

### Output 4
![invoke-azureadbulkusercreation-05](https://user-images.githubusercontent.com/13448198/37186937-bd95be8a-22fc-11e8-9427-868c76643841.jpg)

### Output 5
![invoke-azureadbulkusercreation-04](https://user-images.githubusercontent.com/13448198/37186947-c84d2246-22fc-11e8-8a4f-e0d0a1434b18.png)

---- Tested environment -----
- Windows Server 2016, Version 1607 / 1709
- EN-US language OS

---- Tested environment -----
- Windows 10, Version 1607 / 1703 / 1709
- EN-US language OS

If you have any feedback or changes that everyone should receive, please feel free to leave a comment, update the source and create a pull request.

Thank You!

-Charbel