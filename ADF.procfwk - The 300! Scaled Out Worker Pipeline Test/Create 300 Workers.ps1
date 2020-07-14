# Set global variables as required:
$resourceGroupName = "ADF.procfwk"
$dataFactoryName = "WorkersFactory"

#SPN for deploying ADF:
$tenantId = [System.Environment]::GetEnvironmentVariable('AZURE_TENANT_ID')
$spId = [System.Environment]::GetEnvironmentVariable('AZURE_CLIENT_ID')
$spKey = [System.Environment]::GetEnvironmentVariable('AZURE_CLIENT_SECRET')

#Modules
Import-Module -Name "Az"
#Update-Module -Name "Az"

Import-Module -Name "Az.DataFactory"
#Update-Module -Name "Az.DataFactory"

# Login as a Service Principal
$passwd = ConvertTo-SecureString $spKey -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential($spId, $passwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -TenantId $tenantId | Out-Null

#Create array of 300 items
$a = 1..300

#Template pipeline
$scriptPath = (Get-Item -Path ".\").FullName #+ "\Desktop\Temp\"
$deploymentFilePath = $scriptPath + "\TemplatePipeline.json"
$body = (Get-Content -Path $deploymentFilePath | Out-String)        
$json = $body | ConvertFrom-Json

#Deploy pipelines
foreach ($element in $a) {
  
    $pipelineName = "Wait " + $element.ToString()
    $json.name = $pipelineName

    Write-Host "Deploying pipeline... "$pipelineName
    
    New-AzResource `
        -ResourceType 'Microsoft.DataFactory/factories/pipelines' `
        -ResourceGroupName $resourceGroupName `
        -Name "$dataFactoryName/$pipelineName" `
        -ApiVersion "2018-06-01" `
        -Properties $json `
        -IsFullObject -Force | Out-Null
}
