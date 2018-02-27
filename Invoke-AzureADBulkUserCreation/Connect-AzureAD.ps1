Install-Module -Name AzureADPreview -Verbose
Import-Module  -Name AzureADPreview
$Msg = "Enter the username and password that will connect to Azure AD";
$Cred = $Host.UI.PromptForCredential("Task username and password",$msg,"","")
Connect-AzureAD -Credential $cred
Get-AzureADUser