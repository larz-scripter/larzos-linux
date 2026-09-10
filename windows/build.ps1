#requires -Version 5
<#
    Build LarzOS.exe (the LarzOS WSL launcher) locally.

    Needs Visual Studio 2022 with the "Desktop development with C++" workload
    and a Windows 10/11 SDK. Output: build\<platform>\LarzOS.exe

    Usage:
        .\build.ps1                 # x64, Release
        .\build.ps1 -Platform ARM64
        .\build.ps1 -Configuration Debug
        .\build.ps1 -Appx           # also build the MSIX (needs the UWP workload)
#>
param(
    [ValidateSet('x64', 'ARM64')]   [string]$Platform = 'x64',
    [ValidateSet('Release', 'Debug')] [string]$Configuration = 'Release',
    [switch]$Appx
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found - install Visual Studio 2022." }
$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe |
    Select-Object -First 1
if (-not $msbuild) { throw "MSBuild not found." }

$project = if ($Appx) { "$here\LarzOS.sln" } else { "$here\DistroLauncher\LarzOS.vcxproj" }
$out = "$here\build\$Platform\"

& $msbuild $project /p:Configuration=$Configuration /p:Platform=$Platform `
    /p:OutDir=$out /m /nologo
if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host "Built: $out`LarzOS.exe" -ForegroundColor Green
Write-Host "Put the LarzOS rootfs tarball beside it as 'install.tar.gz', then run LarzOS.exe."
