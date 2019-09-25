$ErrorActionPreference='Stop'
$t=[Reflection.Assembly]::LoadWithPartialName("System.Web")
Write-Host "Loaded $($t.FullName)."

function CheckLoggedIn()
{
    $rmContext=Get-AzureRmContext

    if ($null -eq $rmContext.Account){
        Write-host "You are not logged into Azure. User Login-AzureRMAccount to log in first and optionally select a subscription" -ForegroundColor Yellow
        exit

        #Login-AzureRMAccount
    }

    Write-Host "You are running as '$($rmContext.Account.Id)' in subscription '$($rmContext.Subscription.Name)'"
};

function EnsureResourceGroup ([string]$Name, [string]$Location)
{
    #Prepare resource group
    Write-host "Checking if resource group '$Name' exists . . .";
    $resourceGroup =Get-AzureRMResourceGroup -Name $Name $Location -ErrorAction Ignore
    if ($null -eq $resourceGroup)
    {
        Write-Host " resource group doesn't exist, creating a new one . . ."
        $resourceGroup =New-AzureRmResourceGroup -Name $Name -Location $Location
        Write-Host " resourcegroup created"
    }
    else
    {
        write-host " resource group already exists"
    }
}

function EnsureKeyVault([string]$Name, [string]$resourceGroupName,[string]$Location )
{
    # Properly create a new KeyVault 
    # KV must be enabled for deployment (last parameter)

    Write-Host "Checking if Key Vault '$Name' exists . . ."
    $keyVault = Get-AzureRmKeyVault -VaultName $Name -ErrorAction Ignore

    if ($null -eq $KeyVault)
    {
        Write-host " key vault doesnot exist, creating a new one . . ."
        $KeyVault = New-AzureRmKeyVault -VaultName $Name -ResourceGroupName $resourceGroupName -Location $Location -EnabledForDeployment
    write-host " Key Vault created and enabled for deployment."
    }
    else {
        Write-Host " key vault already exists"
    }

    $keyVault
}


function CreateSelfSignedCertificate ([string]$DnsName)
{
    Write-host "Creating self-signed certificate with dns name $DnsName"

    $filePath ="$PSScriptRoot\$DnsName.pfx"

    Write-Host " generating password. . ." -NoNewline
    $certPassword = GeneratePassword
    Write-Host "$certPassword"

    Write-Host " generating certificates . . ." -NoNewline
    $securePassword = ConvertTo-SecureString $certPassword -AsPlainText -Force
    $thumbprint =(New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
    Write-Host "$thumbprint"

    Write-Host "exporting to $filePath"
    $certContent = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
    $t=Export-PfxCertificate -Cert $certContent -FilePath $filePath -Password $securePassword
    Set-Content -Path "$PSScriptRoot\$DnsName.thumb.txt" -Value $thumbprint
    Set-Content -Path "$PSScriptRoot\$DnsName.pwd.txt" -Value $certPassword
    Write-Host " exported."

    $thumbprint
    $certPassword
    $filePath
}

function ImportCertificateIntoKeyVault([string]$KeyVaultName, [string]$CertName, [string]$CertFilePath, [string]$CertPassword)
{
    Write-Host "Importing certificates. . ."
    Write-Host " generating secure password"
    $securePassword = ConvertTo-SecureString $CertPassword -AsPlainText -Force
    Write-Host " uploading to KeyVault . . ."
    Import-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $CertName -FilePath $CertFilePath -Password $securePassword
    Write-Host " imported."
}


function GeneratePassword(){
    [System.Web.Security.Membership]:: GeneratePassword(15,2);
}


function EnsureSelfSignedCertificate ([string]$KeyVaultName, [string]$CertName)
{
    $localPath= "$PSScriptRoot\$CertName.pfx"
    $existLocally =Test-Path $localPath

    # create of read certificate 
    if ($existLocally)
    {
        Write-host "Certificate exist locally."
        $thumbprint =Get-Content "$PSScriptRoot\$CertName.thumb.txt"
        $password =Get-Content  "$PSScriptRoot\$CertName.pwd.txt"
        Write-Host " thumb: $thumbprint, pass: $password"
    }else{
        $thumbprint, $password, $localPath = CreateSelfSignedCertificate $CertName
    }

    # import into vault if needed
    Write-host "Checking certificate in key vault . . . "
    $kvCert=Get-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $CertName
    if ($null -eq $kvCert)
    {
        Write-Host " importing. . ."
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $kvCert=Import-AzureKeyVaultCertificate -VaultName $KeyVaultName -Name $CertName -FilePath  $localPath -Password $securePassword  
    } else {
        Write-Host " certificate already imported."
    }

    return $kvCert;

}



