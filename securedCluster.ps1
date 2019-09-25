param(
    [string] [parameter(Mandatory=$true)] $Name
)

."$PSScriptRoot\Common.ps1";

$ResourceGroupName ="RG-$Name";
$Location ="UK South"
$KeyVaultName ="$Name-Vault"

CheckLoggedIn

EnsureResourceGroup $ResourceGroupName $Location 

$KeyVault = EnsureKeyVault $KeyVaultName $ResourceGroupName $Location

$certThumbPrint, $certPassword, $certPath= CreateSelfSignedCertificate $Name

$kvCert=ImportCertificateIntoKeyVault $KeyVaultName $Name $certPath $certPassword

Write-Host "Deploying cluster with ARM template . . . "
$armParameters = @{
    namePart=$Name;
    certificateThumbprint=$certThumbPrint;
    sourceVaultResourceId=$KeyVault.ResourceId;
    certificateUrlValue=$kvCert.SecretId;
    rdpPassword=GeneratePassword;
}

New-AzureRmResourceGroupDeployment `
-ResourceGroupName $ResourceGroupName `
-TemplateFile "$PSScriptRoot\minimal.json" `
-Mode Incremental `
-TemplateParameterObject $armParameters `
-Verbose

