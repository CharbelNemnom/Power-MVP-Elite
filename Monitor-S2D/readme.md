# Monitor-S2D.ps1
## S2D Monitoring Tool

This script works on disaggregated and Hyper-Converged S2D infrastructure. This script is written to check the Health Service in Storage Spaces Direct Cluster across nodes. When the script detects any issue in your S2D cluster, you will receive an HTML e-mail alert. (see example in this repository).

To run Monitor-S2D.ps1 script once, update the following parameters:

$FromEmail = "fromemail@domain.com"

$ToEmail1 = "email1@domain.com"

$ToEmail2 = "email2@domain.com"

$smtpServer = "smtp.office365.com"

$smtpCreds = new-object Net.NetworkCredential("Username", "Password")

Then run the script as follows:

$Credential = Get-Credential

.\Monitor-S2D.ps1 -ClusterName "S2DCluster" -Credential $Credential

To run the script as recurring task, update the Cluster Name paramter in Monitor-S2D.ps1 script:

$ClusterName = "S2D-ClusterName"

Finally, save Monitor-S2D.ps1 script in a desired path, and then run the script named "Create-S2DRecurringTask.ps1" in this repository to create a recurring S2D PowerShell task. 

---- Tested environment -----
- Windows Server Version 1607
- Storage Spaces Direct in disaggregated and Hyper-Converged environment
- EN-US language OS

---- Not tested environment ----
- Windows Server Version 1709 or later
- Other OS language than EN-US

---- Not Working environment ----
- Windows Server 2012R2 or older release

Here is an automated e-mail generated for **Minor** issue. One physical disk is damaged, you can see all the details including what action you need to take:

![s2d-monitor-powershell-v1607-07](https://user-images.githubusercontent.com/13448198/34036424-8f12cc50-e19e-11e7-94cc-408f88c27951.jpg)

Here is another alert for **Critical** and **Minor** issue. One server is down and the network cable is disconnected:

![s2d-monitor-powershell-v1607-08](https://user-images.githubusercontent.com/13448198/34036439-9fa8402c-e19e-11e7-8c33-cd135b006bf5.jpg)

Here is another alert. The network cable is disconnected. And since I have a redundant network path, the severity is **Minor**.
![s2d-monitor-powershell-v1607-09](https://user-images.githubusercontent.com/13448198/34036440-a2613ec2-e19e-11e7-9864-673ea1def3c0.jpg)

This is still version 1.1. If you have any feedback or changes that everyone should receive, please feel free to update the source and create a pull request.

Thank You!