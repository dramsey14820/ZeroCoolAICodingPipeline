<#
.SYNOPSIS
    Deploys the ZeroCool AI Coding Pipeline templates into a target repository.

.DESCRIPTION
    Creates the required .agents and .ai folder structure in the target repository
    and copies AGENTS.md, coding rules, feature-slice skill, constitution.md, and
    slice-template.md into place without overwriting existing slice-01.md+ files.

.PARAMETER TargetRepoPath
    Path to the target repository root directory.

.PARAMETER Force
    Overwrites an existing .ai\constitution.md if present. Existing slice-XX.md
    files (e.g., slice-01.md, slice-02.md) are NEVER overwritten.

.EXAMPLE
    .\deploy-pipeline.ps1 -TargetRepoPath "C:\_GIT\MyDotNetApp"

.EXAMPLE
    .\deploy-pipeline.ps1 -TargetRepoPath "C:\_GIT\MyDotNetApp" -Force
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRepoPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$templatesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'templates'

if (-not (Test-Path -Path $templatesRoot -PathType Container)) {
    throw "Templates directory not found at '$templatesRoot'."
}

if (-not (Test-Path -Path $TargetRepoPath -PathType Container)) {
    throw "Target repository path '$TargetRepoPath' does not exist or is not a directory."
}

$resolvedTarget = (Resolve-Path -Path $TargetRepoPath).Path

$directoriesToCreate = @(
    '.agents\rules',
    '.agents\skills\feature-slice',
    '.ai\slices'
)

$createdDirs = [System.Collections.Generic.List[string]]::new()
$copiedFiles = [System.Collections.Generic.List[string]]::new()
$skippedFiles = [System.Collections.Generic.List[string]]::new()

Write-Host "Deploying ZeroCool AI Coding Pipeline to: $resolvedTarget" -ForegroundColor Cyan

# 1. Ensure required directories exist
foreach ($relDir in $directoriesToCreate) {
    $fullDir = Join-Path -Path $resolvedTarget -ChildPath $relDir
    if (-not (Test-Path -Path $fullDir -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($fullDir, 'Create directory')) {
            New-Item -Path $fullDir -ItemType Directory -Force | Out-Null
            $createdDirs.Add($relDir)
        }
    }
}

# 2. Define exact template files to deploy (never touches existing slice-01.md+ files)
$filesToDeploy = @(
    @{ RelativePath = 'AGENTS.md';                                 PreserveIfExists = $false },
    @{ RelativePath = '.agents\rules\csharp-standards.md';         PreserveIfExists = $false },
    @{ RelativePath = '.agents\rules\blazor-maui-ui.md';           PreserveIfExists = $false },
    @{ RelativePath = '.agents\skills\feature-slice\SKILL.md';     PreserveIfExists = $false },
    @{ RelativePath = '.ai\constitution.md';                       PreserveIfExists = $true  },
    @{ RelativePath = '.ai\slices\slice-template.md';              PreserveIfExists = $false }
)

foreach ($entry in $filesToDeploy) {
    $relPath = $entry.RelativePath
    $srcPath = Join-Path -Path $templatesRoot -ChildPath $relPath
    $dstPath = Join-Path -Path $resolvedTarget -ChildPath $relPath

    if (-not (Test-Path -Path $srcPath -PathType Leaf)) {
        throw "Required template file is missing: '$srcPath'."
    }

    # Explicit safety guard: never overwrite numbered slice files (slice-01.md, slice-02.md, etc.)
    $leafName = Split-Path -Path $dstPath -Leaf
    if ($leafName -match '^slice-\d+.*\.md$' -and (Test-Path -Path $dstPath -PathType Leaf)) {
        $skippedFiles.Add("$relPath (protected existing slice)")
        continue
    }

    if ($entry.PreserveIfExists -and -not $Force -and (Test-Path -Path $dstPath -PathType Leaf)) {
        $skippedFiles.Add("$relPath (already exists; use -Force to overwrite)")
        continue
    }

    if ($PSCmdlet.ShouldProcess($dstPath, "Copy template '$relPath'")) {
        Copy-Item -Path $srcPath -Destination $dstPath -Force
        $copiedFiles.Add($relPath)
    }
}

# 3. Print deployment summary
Write-Host ""
Write-Host "Deployment complete." -ForegroundColor Green

if ($createdDirs.Count -gt 0) {
    Write-Host "Created directories:" -ForegroundColor Yellow
    foreach ($d in $createdDirs) { Write-Host "  + $d" }
}

if ($copiedFiles.Count -gt 0) {
    Write-Host "Copied files:" -ForegroundColor Yellow
    foreach ($f in $copiedFiles) { Write-Host "  + $f" }
}

if ($skippedFiles.Count -gt 0) {
    Write-Host "Preserved existing files:" -ForegroundColor DarkGray
    foreach ($s in $skippedFiles) { Write-Host "  - $s" }
}

$existingSlices = Get-ChildItem -Path (Join-Path -Path $resolvedTarget -ChildPath '.ai\slices') -Filter 'slice-*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^slice-\d+.*\.md$' }

if ($existingSlices) {
    Write-Host "Preserved numbered slices:" -ForegroundColor DarkGray
    foreach ($slice in $existingSlices) { Write-Host "  - .ai\slices\$($slice.Name)" }
}

