param (
    [string] [Parameter(Mandatory=$true)] $Name,
    [string] $TemplateName ="silver.json", # name of the cluster ARM template
    [string] $Location ="UK South"
)

. "$PSScriptRoot\..\Common.ps1"

$ResourceGroupName ="ASF-$Name" # Resource group everything will be created in 
$KeyVaultName ="$Name-vault" # name of the Key vault
$rdpPassword="Password00;;"

# Check that your're logged in to Azure before running anything at all, the call will
# exit the script if you are not
CheckLoggedIn

# Ensure resource group we are deploying to exists
EnsureResourceGroup $ResourceGroupName $Location

# Ensure that the Key Vault resource exists. 
$keyVault = EnsureKeyVault $KeyVaultName $ResourceGroupName $Location

# Ensure that self-signed certificate is created and imported into key Vault. 
$cert = EnsureSelfSignedCertificate $KeyVaultName $Name

Write-Host "Applying cluster template $TemplateName. . ."
$armParameters =@{
    namePart=$Name;
    certificateThumbprint = $cert.Thumbprint;
    sourceVaultResourceId=$keyVault.ResourceId;
    certificateUrlValue = $cert.SecretId;
    rdpPassword =$rdpPassword;
    vmInstanceCount=1;
}

New-AzureRmResourceGroupDeployment `
-ResourceGroupName $ResourceGroupName `
-TemplateFile "$PSScriptRoot\$TemplateName" `
-Mode Incremental `
-TemplateParameterObject $armParameters `
-Verbose
