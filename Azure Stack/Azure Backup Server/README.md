# Azure Backup Server

This Template deploys Azure Backup Server on Azure Stack.

The original template is posted by Microsoft here: https://github.com/Azure/AzureStack-QuickStart-Templates/blob/master/AzureBackupServer/azuredeploy.json

## Requirements

### Azure Stack

To automate the deployment of Azure Backup Server on Azure Stack, you need to have the following requirements in place:

- Azure Stack Integrated System (multi-nodes). At the time of this writing, the automate deployment does not work on Azure Stack Development Kit.
- Existing Active Directory in the tenant space where you plan to deploy Azure Backup Server.
- Exiting virtual network and at least one subnet.
- As an Azure Stack operator, you need to download the following marketplace items:
    - Windows Server 2016 Full Image
    - PowerShell Desired State Configuration Extension
    - Microsoft Antimalware ExtensionCustom Script Extension for Windows
    - Microsoft Azure Diagnostic Extension for Windows Virtual Machines
    - Azure Performance Diagnostics

### Azure Backup Server

For Azure Backup Server, you need to have the following:

- Azure Subscription
- Create Azure Recovery Services Vault
- Download the Vault Credentials File from the Vault in Azure
- Download Azure Backup Server Version 3 setup files

You can find more information on how to deploy Azure Backup Server on Azure Stack here: