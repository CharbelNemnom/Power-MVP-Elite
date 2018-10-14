# Request-JITVMAccess.ps1
## Automate Just In Time VM Access Request With PowerShell 

This tool is written to automate the entire Just In Time VM Access process. The script will connect to Azure Security Center endpoint, and then will open the requested port temporarily. If Just in Time VM Access is not enabled for that VM, the script will enable it, and then request VM access on your behalf. Additionally, the script will automatically install Azure Resource Manager and Azure Security Center PowerShell modules if they are not installed on your machine.

I have updated this tool to create a role definition with least privilege (just enough permissions), so the users will be able to enable and request access without having to wait for support calls to enable access. When a user requests access to a VM, Azure Security Center checks that the user has Role-Based Access Control (RBAC) permissions that provide write access for the VM. If they have write permissions, the request is approved.
You need to run .\Create-JitRBACRole.ps1 script only one time.

You can run this tool in multiple scenarios as follows:

### EXAMPLE -1-
* .\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -Time [Hours] -Verbose

This example will enable Just in Time VM Access for a particular Azure VM from your current public IP address.
The management port will be set as specified including the number of hours. You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.
If the time specified is greater than the time set by the policy, the script will force you to enter the valid time, and then request VM access.

### EXAMPLE -2-
* .\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Time [Hours] -Verbose

This example will enable Just in Time VM Access for a particular Azure VM including the management port, source IP, and number of hours.
You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.
If the time specified is greater than the time set by the policy, the script will force you to enter the valid time, and then request VM access.

### EXAMPLE -3-
* .\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -AddressPrefix [AllowedSourceIP] -Verbose

This example will enable Just in Time VM Access for a particular Azure VM including the management port,and source IP address.
You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.

### EXAMPLE -4-
* .\Request-JITVMAccess.ps1 -VMName [VMName] -Port [PortNumber] -Verbose

This example will enable Just in Time VM Access for a particular Azure VM from your current public IP address.
The management port will be set as specified. You will be prompted to login to your Azure account.
If Just in Time VM Access is not enabled, the tool will enable the policy for the VM, you need to provide the maximum requested time in hours.
If Just in Time VM Access is already enabled, the tool will automatically extract the maximum requested time set by the policy, and then request VM access.
If the specified management port is not set by the policy previously, the script will enable that port, and then request VM access.

Here are a couple of screenshots showing you how to use this tool.

### Output EXAMPLE -1-
![asc-jit-vm-access-posh-v2-04](https://user-images.githubusercontent.com/13448198/46915702-59588500-cfaf-11e8-8611-c9ff728d3e1a.jpg)

### Output EXAMPLE -2-
![asc-jit-vm-access-posh-v2-05](https://user-images.githubusercontent.com/13448198/46915704-5cec0c00-cfaf-11e8-901a-8a19172694d5.jpg)

### Output EXAMPLE -3-
![asc-jit-vm-access-posh-v2-06](https://user-images.githubusercontent.com/13448198/46915706-5eb5cf80-cfaf-11e8-8b85-4c416bb99033.jpg)

### Output EXAMPLE -4-
![asc-jit-vm-access-posh-v2-07](https://user-images.githubusercontent.com/13448198/46915707-607f9300-cfaf-11e8-8ef3-b608f1a1b45f.jpg)

#### ---- Tested environment -----
- Windows Server 2016, Version 1607 / 1709 / 1803 / 1809
- EN-US language OS

#### ---- Tested environment -----
- Windows 10, Version 1607 / 1703 / 1709 / 1803 / 1809
- EN-US language OS

If you have any feedback or changes that everyone should receive, please feel free to leave a comment, update the source code and create a pull request.

Thank You!

-Charbel Nemnom-