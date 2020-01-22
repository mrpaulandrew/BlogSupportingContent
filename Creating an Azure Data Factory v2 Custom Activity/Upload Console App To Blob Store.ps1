

# Variables:
$storageAccountName = ""
$containerName = ""
$storageAccountKey = ""

# Find the local folder where this PowerShell script is stored.
$scriptPath = $PSScriptRoot
$projectFolder = (get-item $scriptPath ).parent.FullName + "\bin\Debug\"

$files = Get-ChildItem $projectFolder | where { !$_.PSIsContainer -and $_ -notlike "*.json" } #not folders or JSON files

#create blob context with key
$blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

#remove current container contents
Write-Host "Removing current container contents."

Get-AzureStorageBlob `
    -Container $containerName `
    -blob * `
    -Context $blobContext | ForEach-Object {Remove-AzureStorageBlob -Blob $_.Name -Container $containerName -Context $blobContext}

Write-Host "----------------------------------------"

Sleep -Seconds 5

#upload files
Write-Host "Uploading files."

foreach ($file in $files)
{
    $fileName = "$projectFolder\$file"
    $blobName = "$destfolder/$file"    
    
    Write-Host "Uploading" $file

    Set-AzureStorageBlobContent `
        -File $filename `
        -Container $containerName `
        -Blob $file `
        -Context $blobContext `
        -Force | Out-Null
}

Write-Host "----------------------------------------"
Write-Host "Upload complete."
