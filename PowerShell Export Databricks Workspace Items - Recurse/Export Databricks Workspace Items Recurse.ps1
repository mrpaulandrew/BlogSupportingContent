#As required, first use:
#Install-Module -Name DatabricksPS -Scope CurrentUser
#Import-Module -Name DatabricksPS 

#Local variables
$Token = "dapi59e2096f88f91a2233784e2f8d1b5dd5" ## << ADD YOUR ACCESS TOKEN 
$Url = "https://northeurope.azuredatabricks.net" ## << SET YOUR SERVICE URL
$OutputPath = "C:\Users\pja\Desktop\Test" ## << SET A LOCAL OUTPUT PATH
$WorkspacePath = "/" ## << SET THE WORKSPACE PATH. '/' FOR ROOT OR A LOWER LEVEL IF NEEDED

#Boiler plate code
function Get-AllDatabricksItems ([hashtable] $Params) {
    $AllFiles = @()
    recurseDatabricksItem -AllFiles $AllFiles -Params $Params
    $AllFiles
}

function recurseDatabricksItem ($AllFiles, [hashtable] $Params) {
    
    $ChildItems = Get-DatabricksWorkspaceItem @Params;
    
    foreach ($ChildItem in $ChildItems) {
        
        switch ($ChildItem.object_type) {
            "NOTEBOOK" {
                $AllFiles += @{Path = $ChildItem.path; Language = $ChildItem.language; Type = $ChildItem.object_type}
            }
            "LIBRARY" {
                $AllFiles += @{Path = $ChildItem.path; Language = $ChildItem.language; Type = $ChildItem.object_type} 
            }
            "DIRECTORY" {
                $Params.Remove("Path");
                $Params.Add("Path", $ChildItem.path);
                recurseDatabricksItem -AllFiles $AllFiles -Params $Params;
            }
        }
    }
    
    $AllFiles | ForEach-Object { new-object PSObject -Property $_}
}

function lazyMKDir ([string] $path){
    $Dir = split-path $path -Parent
    if (!(Test-Path -Path $Dir)) {
        New-Item -ItemType directory -Path $Dir | Out-Null
    }
}

Write-Host "Setting Databricks environment."

Set-DatabricksEnvironment -AccessToken "$Token" -ApiRootUrl "$Url" | Out-Null

Write-Host "Getting list of Workspace items."

#Get items
$DBItems = Get-AllDatabricksItems `
    -Params @{ 'Path' = $WorkspacePath }

Write-Host "Exporting Workspace items."

#Export items
ForEach ($DBItem in $DBItems)
{   
    
    if($DBItem.Type -eq "LIBRARY"){
        $Info = "Export of libraries is not currently supported by the Databricks Workspace API. See Libraries API for more information https://docs.databricks.com/api/latest/libraries.html. Could not export: " + $DBItem.Path
        Write-Warning $Info
    }
    else
    {
    Write-Host "Exporting:" $DBItem.Path
    }
    
    switch($DBItem.Language){
        "SCALA"{
            $FullOutputPath = $OutputPath + $DBItem.Path + ".scala"
            lazyMKDir -path $FullOutputPath
            
            Export-DatabricksWorkspaceItem `
                -Path $DBItem.Path `
                -LocalPath $FullOutputPath `
                -Format SOURCE
        }
        "PYTHON"{
            $FullOutputPath = $OutputPath + $DBItem.Path + ".ipynb"
            lazyMKDir -path $FullOutputPath

            Export-DatabricksWorkspaceItem `
                -Path $DBItem.Path `
                -LocalPath $FullOutputPath `
                -Format JUPYTER
        }
        "SQL" {
            $FullOutputPath = $OutputPath + $DBItem.Path + ".sql"
            lazyMKDir -path $FullOutputPath

            Export-DatabricksWorkspaceItem `
                -Path $DBItem.Path `
                -LocalPath $FullOutputPath `
                -Format SOURCE
        }
        "R" {
            $FullOutputPath = $OutputPath + $DBItem.Path + ".r"
            lazyMKDir -path $FullOutputPath

            Export-DatabricksWorkspaceItem `
                -Path $DBItem.Path `
                -LocalPath $FullOutputPath `
                -Format SOURCE
        }
    }
    
}

Write-Host "Export complete."
