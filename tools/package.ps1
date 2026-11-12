$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$addonRoot = Join-Path $projectRoot 'WoWEnhancedController'
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$versionLine = Get-Content -LiteralPath (Join-Path $addonRoot 'WoWEnhancedController.toc') | Where-Object { $_ -match '^## Version:' }
$addonVersion = ($versionLine -replace '^## Version:\s*', '').Trim()
$packagePath = Join-Path $outputRoot "WoWEnhancedController-$addonVersion-forever.zip"
Compress-Archive -LiteralPath $addonRoot -DestinationPath $packagePath -Force
Write-Output $packagePath
