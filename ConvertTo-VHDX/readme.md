# ConvertTo-VHDX.ps1
## VHDX Conversion Tool

This script is written to convert a multiple virtual hard disks (VHD) to VHDX format.

Run the script as follows:

.\ConvertTo-VHDX.ps1 -SourcePath D:\VHDFolder\ -DestinationPath D:\ -Verbose

This example converts all VHD in a source path to VHDX in a destination path, and finally set the PhysicalSectorSizeBytes to 4096.
A converted VHDX file has a physical sector size of 512 Bytes. However, when you create a new VHDX file it has a physical sector size of 4K. 

Here is a screenshot showing the conversion is completed.
![posh-convert-vhd-to-vhdx-04](https://user-images.githubusercontent.com/13448198/36154255-431d3300-10ea-11e8-9fb2-c42613265d85.png)

---- Tested environment -----
- Windows Server Hyper-V Version 1709
- EN-US language OS

---- Tested environment -----
- Windows Server Hyper-V Version 1607 
- EN-US language OS

---- Tested environment -----
- Windows Server 2012 R2
- EN-US language OS