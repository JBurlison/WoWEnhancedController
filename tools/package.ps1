$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot
$addonRoot = Join-Path $projectRoot 'WoWEnhancedController'
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$packagePath = Join-Path $outputRoot 'WoWEnhancedController-0.1.0-forever.zip'
Compress-Archive -LiteralPath $addonRoot -DestinationPath $packagePath -Force
Write-Output $packagePath
