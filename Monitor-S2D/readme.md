# Monitor-S2D.ps1
## S2D Monitoring Tool

This script works on disaggregated and Hyper-Converged S2D infrastructure. This script is written to check the Health Service in Storage Spaces Direct Cluster across nodes. When the script detects any issue in your S2D cluster, you will receive an HTML e-mail alert. (see example in this repository).

To run Monitor-S2D.ps1 script once, run the following commands:

$Credential = Get-Credential
.\Monitor-S2D.ps1 -ClusterName "S2DCluster" -Credential $Credential

To run the script as recurring task, update the following paramters in Monitor-S2D.ps1 script:

$ClusterName = "S2D-ClusterName"

Finally, save the script in a desired path, and then run the script named "Create-S2DRecurringTask.ps1" in this repository. 

---- Tested environment -----
- Windows Server Version 1607
- Storage Spaces Direct in disaggregated and Hyper-Converged environment
- EN-US language OS

---- Not tested environment ----
- Windows Server Version 1709 or later
- Other OS language than EN-US

---- Not Working environment ----
- Windows Server 2012R2 or older release