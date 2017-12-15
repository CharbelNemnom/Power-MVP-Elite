# Monitor-S2D.ps1
## S2D Monitoring Tool

This script works on disaggregated and Hyper-Converged S2D infrastructure. This script is written to check the Health Service in Storage Spaces Direct Cluster across nodes. When the script detects if there is an issue in your cluster, you will receive an HTML e-mail alert. (see example in this repository).

To run the script, run the following commands:

$Credential = Get-Credential
.\Monitor-S2D.ps1 -ClusterName "S2DCluster" -Credential $Credential

---- Tested environment -----
- Windows Server Version 1607
- Storage Spaces Direct in disaggregated and Hyper-Converged environment
- EN-US language OS

---- Not tested environment ----
- Windows Server Version 1709 or later
- Other OS language than EN-US

---- Not Working environment ----
Windows Server 2012R2 or older release