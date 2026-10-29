[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$LocalFolder,

    [Parameter(Mandatory = $true)]
    [string]$CWPath,

    [Parameter(Mandatory = $true)]
    [string]$HFName,

    [Parameter(Mandatory = $false)]
    [string]$Repository = "sandeepkancharla-scout/eeint-jfrog-promotion",

    [Parameter(Mandatory = $false)]
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

$stagingTag = "hotfix-staging"

# ============================================================
# Validate local requirements
# ============================================================

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw @"
GitHub CLI is not installed or is not available in PATH.

Install GitHub CLI, then authenticate using:

gh auth login
"@
}

& gh auth status

if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

$LocalFolder = $LocalFolder.Trim().TrimEnd("\", "/")
$CWPath = $CWPath.Trim().Trim("/", "\")
$HFName = $HFName.Trim().Trim("/", "\")

if ([string]::IsNullOrWhiteSpace($LocalFolder)) {
    throw "LocalFolder cannot be empty."
}

if (-not (Test-Path -LiteralPath $LocalFolder -PathType Container)) {
    throw "Local folder does not exist: $LocalFolder"
}

if ([string]::IsNullOrWhiteSpace($CWPath)) {
    throw "CWPath cannot be empty."
}

if ($CWPath -notmatch "^CW.+$") {
    throw "CWPath must start with CW. Received: $CWPath"
}

if ($CWPath.Contains("/") -or $CWPath.Contains("\")) {
    throw "CWPath must be one folder name. Received: $CWPath"
}

if ([string]::IsNullOrWhiteSpace($HFName)) {
    throw "HFName cannot be empty."
}

if ($HFName -notmatch "^HF.+$") {
    throw "HFName must start with HF. Received: $HFName"
}

if ($HFName.Contains("/") -or $HFName.Contains("\")) {
    throw "HFName must be one folder name. Received: $HFName"
}

$folderItem = Get-Item -LiteralPath $LocalFolder
$folderName = $folderItem.Name

$files = @(
    Get-ChildItem `
        -LiteralPath $LocalFolder `
        -File `
        -Recurse
)

if ($files.Count -eq 0) {
    throw "The selected folder contains no files: $LocalFolder"
}

# ============================================================
# Create a unique temporary ZIP
# ============================================================

$uploadId = [Guid]::NewGuid().ToString("N")
$safeFolderName = $folderName -replace '[^a-zA-Z0-9._-]', '_'
$assetName = "$uploadId-$safeFolderName.zip"
$zipPath = Join-Path $env:TEMP $assetName

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Write-Host ""
Write-Host "============================================"
Write-Host "HOTFIX SUBMISSION"
Write-Host "============================================"
Write-Host "Repository   : $Repository"
Write-Host "Branch       : $Branch"
Write-Host "Local Folder : $LocalFolder"
Write-Host "Folder Name  : $folderName"
Write-Host "File Count   : $($files.Count)"
Write-Host "CW Path      : $CWPath"
Write-Host "HF Name      : $HFName"
Write-Host "Upload ID    : $uploadId"
Write-Host "ZIP Asset    : $assetName"
Write-Host "============================================"
Write-Host ""

try {
    Write-Host "Creating ZIP package..."

    Compress-Archive `
        -LiteralPath $LocalFolder `
        -DestinationPath $zipPath `
        -CompressionLevel Optimal `
        -Force

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw "ZIP package was not created: $zipPath"
    }

    # ========================================================
    # Create the private staging release if it does not exist
    # ========================================================

    & gh release view `
        $stagingTag `
        --repo $Repository `
        *> $null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating private draft staging release..."

        & gh release create `
            $stagingTag `
            --repo $Repository `
            --title "Hotfix staging" `
            --notes "Temporary assets used by the Hotfix to Scout workflow." `
            --draft `
            --target $Branch

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to create the GitHub staging release."
        }
    }

    # ========================================================
    # Upload ZIP to the private draft release
    # ========================================================

    Write-Host "Uploading ZIP to private GitHub staging release..."

    & gh release upload `
        $stagingTag `
        $zipPath `
        --repo $Repository `
        --clobber

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to upload the ZIP to the GitHub staging release."
    }

    # ========================================================
    # Start the Ubuntu Hotfix workflow
    # ========================================================

    Write-Host "Starting Hotfix to Scout workflow..."

    & gh workflow run `
        "hotfix-to-scout.yml" `
        --repo $Repository `
        --ref $Branch `
        -f "staging_asset=$assetName" `
        -f "original_folder_name=$folderName" `
        -f "cw_path=$CWPath" `
        -f "hf_name=$HFName"

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to start hotfix-to-scout.yml."
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "HOTFIX SUBMITTED SUCCESSFULLY"
    Write-Host "============================================"
    Write-Host "Scout destination:"
    Write-Host "Official_Release/$CWPath/Hotfixes/$HFName/$folderName"
    Write-Host ""
    Write-Host "The Ubuntu workflow will:"
    Write-Host "1. Download and extract the ZIP."
    Write-Host "2. Upload the complete folder to Scout Clone."
    Write-Host "3. Trigger one Power Automate approval."
    Write-Host "4. Remove the temporary GitHub ZIP."
    Write-Host "============================================" `
        -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item `
            -LiteralPath $zipPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
