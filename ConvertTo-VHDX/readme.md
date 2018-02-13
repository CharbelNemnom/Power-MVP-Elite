# ConvertTo-VHDX.ps1
## VHDX Conversion Tool

This script is written to convert a multiple virtual hard disks (VHD) to VHDX format.

Run the script as follows:

.\ConvertTo-VHDX.ps1 -SourcePath D:\VHDFolder\ -DestinationPath D:\ -Verbose

This example converts all VHD in a source path to VHDX in a destination path, and finally set the PhysicalSectorSizeBytes to 4096.
Note: When you create a new VHDX file, it has a physical sector size of 4K by default. However, a converted VHDX file has a physical sector size of 512 Bytes. This step is very important, because the data storage industry will be transitioning the physical format of hard disk drives from 512-byte sectors to 4,096-byte sectors (also known as 4K or 4KB sectors). This transition is driven by several factors. These include increases in storage density and reliability.

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

If you have any feedback or changes that everyone should receive, please feel free to update the source and create a pull request.

Thank You!