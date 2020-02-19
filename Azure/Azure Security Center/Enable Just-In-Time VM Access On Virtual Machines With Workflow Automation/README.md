# Logic App Workflow Automation to remediate Just-in-Time VM Access in Azure Security Center

This logic app will run only when Azure Security Center fire up a new recommendation for "Just-In-Time network access control should be applied on virtual machine" and create access policies for each VM for ports 22 and 3389 for maximum 3 hours.

You need to create a Workflow automation and select this Logic App as an action.
For more information, please check the <a
href="https://charbelnemnom.com/2020/02/enable-just-in-time-vm-access-on-virtual-machines-with-workflow-automation-in-azure-security-center" target="_blank">following step-by-step guide</a>.

The playbook leverages a "Managed Identity" which needs to be configured after deployment. This "Managed Identity" also requires the appropriate subscription permissions on the resources (subscriptions, tasks, and VMs) that you would like to remediate.

<a
href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCharbelNemnom%2FPower-MVP-Elite%2Fmaster%2FAzure%2FAzure%20Security%20Center%2FEnable%20Just-In-Time%20VM%20Access%20On%20Virtual%20Machines%20With%20Workflow%20Automation%2FASC-WA-EnableJIT.json" target="_blank">
    <img src="https://azuredeploy.net/deploybutton.png"/>
</a>

