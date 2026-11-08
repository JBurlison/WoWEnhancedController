param([Parameter(Mandatory=$true)][string[]]$Paths)
$ErrorActionPreference = 'Stop'
$sourcePin = '9dc84f0d3bbae1768ac3405b3716000bd93eda06'
$cacheRoot = Join-Path $PSScriptRoot '../.tools/forever-theme-source'
foreach ($sourcePath in $Paths) {
    $destination = Join-Path $cacheRoot $sourcePath
    if (!(Test-Path -LiteralPath $destination)) {
        New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Gethe/wow-ui-source/$sourcePin/$sourcePath" -OutFile $destination -TimeoutSec 20
    }
    Write-Output $destination
}
