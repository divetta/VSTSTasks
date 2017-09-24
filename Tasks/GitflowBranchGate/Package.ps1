#Install-Module -Name newtonsoft.json
#Install tfx-cli using npm
#npm install -g tfx-cli
$ErrorActionPreference = "Stop"

$taskJson = Get-Content -Path "Task\task.json" -raw | ConvertFrom-JsonNewtonsoft
Write-Host "Updating Task: $($taskJson.name)" -ForegroundColor Yellow
Write-Host "Current Version: $($taskJson.version.Major).$($taskJson.version.Minor).$($taskJson.version.Patch)"
$taskJson.version.Patch = "$([System.Convert]::ToInt32($taskJson.version.Patch) + 1)"

[string]$newVersionNumber = "$($taskJson.version.Major).$($taskJson.version.Minor).$($taskJson.version.Patch)"
Write-Host "New Version: $newVersionNumber"
$taskJson | ConvertTo-JsonNewtonsoft | set-content ".\Task\task.json"

$extensionJson = Get-Content -Path "vss-extension.json" -raw | ConvertFrom-JsonNewtonsoft
Write-Host "Updating VSS-Extension: $($extensionJson.name)" -ForegroundColor Yellow
Write-Host "Current Version: $($taskJson.version)"
Write-Host "New Version: $newVersionNumber"
$extensionJson.version = "$newVersionNumber"
$extensionJson | ConvertTo-JsonNewtonsoft | set-content "vss-extension.json"

tfx extension create --manifest vss-extension.json --output-path .\build\
