[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$LocalFolder,

    [Parameter(Mandatory = $true)]
    [string]$CWPath,

    [Parameter(Mandatory = $true)]
    [string]$HFName,

    [Parameter(Mandatory = $false)]
    [string]$AccessToken
)

$ErrorActionPreference = "Stop"

# ============================================================
# SCOUT CONFIGURATION
# ============================================================

$JFROG_URL = "https://artifactory.sctmtrs.xyz/artifactory"
$SCOUT_REPO = "rvtm-vw-rvt-scout-build-binaries-clone"


# ============================================================
# FUNCTION: URL-ENCODE ARTIFACTORY PATH
# ============================================================

function ConvertTo-ArtifactoryPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $segments = $Path.Replace("\", "/").Split(
        "/",
        [System.StringSplitOptions]::RemoveEmptyEntries
    )

    $encodedSegments = foreach ($segment in $segments) {
        [System.Uri]::EscapeDataString($segment)
    }

    return ($encodedSegments -join "/")
}


# ============================================================
# FUNCTION: READ TOKEN SECURELY
# ============================================================

function Read-AccessToken {
    $secureToken = Read-Host `
        "Enter Scout JFrog Access Token" `
        -AsSecureString

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $secureToken
    )

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
            $pointer
        )
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $pointer
        )
    }
}


# ============================================================
# NORMALIZE INPUTS
# ============================================================

$LocalFolder = $LocalFolder.Trim().TrimEnd("\", "/")

$CWPath = $CWPath.Trim().Trim("\", "/").ToUpperInvariant()

$HFName = $HFName.Trim().Trim("\", "/").ToUpperInvariant()


# ============================================================
# NORMALIZE OPTIONAL SHORT INPUTS
#
# User can enter:
#   11   -> CW11
#   cw11 -> CW11
#
# User can enter:
#   01   -> HF01
#   hf01 -> HF01
# ============================================================

if ($CWPath -match "^\d+$") {
    $CWPath = "CW$CWPath"
}

if ($HFName -match "^\d+$") {
    $HFName = "HF$HFName"
}


# ============================================================
# VALIDATE LOCAL FOLDER
# ============================================================

if ([string]::IsNullOrWhiteSpace($LocalFolder)) {
    throw "Local Folder cannot be empty."
}

if (-not (Test-Path -LiteralPath $LocalFolder -PathType Container)) {
    throw "Local folder does not exist: $LocalFolder"
}


# ============================================================
# VALIDATE CW
# ============================================================

if ([string]::IsNullOrWhiteSpace($CWPath)) {
    throw "CW Path cannot be empty."
}

if ($CWPath -notmatch "^CW.+$") {
    throw "CW Path must start with CW. Example: CW11"
}

if ($CWPath.Contains("/") -or $CWPath.Contains("\")) {
    throw "CW Path must be one folder name. Example: CW11"
}


# ============================================================
# VALIDATE HOTFIX NAME
# ============================================================

if ([string]::IsNullOrWhiteSpace($HFName)) {
    throw "HF Name cannot be empty."
}

if ($HFName -notmatch "^HF.+$") {
    throw "HF Name must start with HF. Example: HF01"
}

if ($HFName.Contains("/") -or $HFName.Contains("\")) {
    throw "HF Name must be one folder name. Example: HF01"
}


# ============================================================
# REQUEST SCOUT JFROG TOKEN
# ============================================================

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host ""
    Write-Host "Scout JFrog authentication required." `
        -ForegroundColor Yellow
    Write-Host ""

    $AccessToken = Read-AccessToken
}

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Scout JFrog Access Token cannot be empty."
}


# ============================================================
# DETERMINE LOCAL ROOT FOLDER
# ============================================================

$folderItem = Get-Item -LiteralPath $LocalFolder
$folderName = $folderItem.Name

if ([string]::IsNullOrWhiteSpace($folderName)) {
    throw "Unable to determine the local root folder name."
}


# ============================================================
# BUILD DYNAMIC SCOUT TARGET
#
# Example:
#
# Local:
# C:\Downloads\SACID F220
#
# Inputs:
# cw11
# hf01
#
# Result:
# Official_Release/CW11/Hotfixes/HF01/SACID F220
# ============================================================

$promotionPath = "Official_Release/$CWPath/Hotfixes/$HFName"

$targetRoot = "$promotionPath/$folderName"


# ============================================================
# FIND LOCAL FILES
# ============================================================

$files = @(
    Get-ChildItem `
        -LiteralPath $LocalFolder `
        -File `
        -Recurse `
        -Force
)

if ($files.Count -eq 0) {
    throw "No files were found inside: $LocalFolder"
}


# ============================================================
# DISPLAY NORMALIZED CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "SCOUT HOTFIX UPLOAD"
Write-Host "============================================"
Write-Host ""
Write-Host "Local Folder : $LocalFolder"
Write-Host "Folder Name  : $folderName"
Write-Host "CW           : $CWPath"
Write-Host "HF           : $HFName"
Write-Host "Files        : $($files.Count)"
Write-Host ""
Write-Host "Scout Target:"
Write-Host "$SCOUT_REPO/$targetRoot"
Write-Host ""
Write-Host "============================================"
Write-Host ""


# ============================================================
# AUTHENTICATION HEADER
# ============================================================

$headers = @{
    Authorization = "Bearer $AccessToken"
}


# ============================================================
# UPLOAD COUNTERS
# ============================================================

$uploaded = 0
$skipped = 0
$failed = 0
$failedFiles = @()


# ============================================================
# UPLOAD ALL FILES
# =========================================================[System.IO.Path]::GetRelativePath(
        $LocalFolder,
        $file.FullName
    )

    $relativePath = $relativePath.Replace("\", "/")


    # --------------------------------------------------------
    # Skip checksum sidecar files
    #
    # Artifactory interprets these as checksum deployments.
    # These previously caused HTTP 409 checksum errors.
    # --------------------------------------------------------

    $lowerName = $file.Name.ToLowerInvariant()

    $isChecksumFile = (
        $lowerName.EndsWith(".sha256") -or
        $lowerName.EndsWith(".sha1") -or
        $lowerName.EndsWith(".md5")
    )

    if ($isChecksumFile) {
        Write-Host "SKIP    $relativePath" `
            -ForegroundColor Yellow

        $skipped++
        continue
    }


    # --------------------------------------------------------
    # Build Artifactory destination URL
    # --------------------------------------------------------

    $artifactPath = "$SCOUT_REPO/$targetRoot/$relativePath"

    $encodedArtifactPath = ConvertTo-ArtifactoryPath `
        -Path $artifactPath

    $uploadUrl = "$JFROG_URL/$encodedArtifactPath"


    Write-Host "UPLOAD  $relativePath"


    # --------------------------------------------------------
    # Upload file
    # --------------------------------------------------------

    try {
        Invoke-RestMethod `
            -Uri $uploadUrl `
            -Method Put `
            -Headers $headers `
            -InFile $file.FullName `
            -ContentType "application/octet-stream" `
            -ErrorAction Stop |
            Out-Null

        Write-Host "SUCCESS $relativePath" `
            -ForegroundColor Green

        $uploaded++
    }
    catch {
        $failed++
        $failedFiles += $relativePath

        Write-Host "FAILED  $relativePath" `
            -ForegroundColor Red

        $errorMessage = $_.Exception.Message

        if (
            $null -ne $_.ErrorDetails -and
            -not :IsNullOrWhiteSpace($_.ErrorDetails.Message)
        ) {
            $errorMessage = $_.ErrorDetails.Message
        }

        Write-Host $errorMessage `
            -ForegroundColor Red
    }
}


# ============================================================
# UPLOAD SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "UPLOAD SUMMARY"
Write-Host "============================================"
Write-Host ""

Write-Host "Uploaded : $uploaded" `
    -ForegroundColor Green

Write-Host "Skipped  : $skipped" `
    -ForegroundColor Yellow

if ($failed -eq 0) {
    Write-Host "Failed   : 0" `
        -ForegroundColor Green
}
else {
    Write-Host "Failed   : $failed" `
        -ForegroundColor Red
}

Write-Host ""
Write-Host "Scout Location:"
Write-Host "$SCOUT_REPO/$targetRoot"
Write-Host ""
Write-Host "============================================"


# ============================================================
# FAIL IF ANY UPLOAD FAILED
# ============================================================

if ($failed -gt 0) {

    Write-Host ""
    Write-Host "FAILED FILES:" `
        -ForegroundColor Red

    foreach ($failedFile in $failedFiles) {
        Write-Host "  $failedFile" `
            -ForegroundColor Red
    }

    Write-Host ""

    throw "$failed file(s) failed to upload."
}

if ($uploaded -eq 0) {
    throw "No regular artifacts were uploaded."
}


# ============================================================
# SUCCESS
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "HOTFIX UPLOAD SUCCESSFUL"
Write-Host "============================================"
Write-Host ""
Write-Host "Scout Clone:"
Write-Host "$SCOUT_REPO/$targetRoot"
Write-Host ""
Write-Host "Promotion Root:"
Write-Host "$promotionPath"
Write-Host ""
Write-Host "============================================" `
    -ForegroundColor Green

exit 0
