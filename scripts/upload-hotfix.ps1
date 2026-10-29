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
# HELPER - URL ENCODE ARTIFACTORY PATH
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
# NORMALIZE INPUTS
# ============================================================

$LocalFolder = $LocalFolder.Trim().TrimEnd("\", "/")

$CWPath = $CWPath.Trim().Trim("\", "/").ToUpperInvariant()

$HFName = $HFName.Trim().Trim("\", "/").ToUpperInvariant()


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
    throw "CW Path must be one folder name."
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
    throw "HF Name must be one folder name."
}


# ============================================================
# REQUEST JFROG TOKEN SECURELY
# ============================================================

if ([string]::IsNullOrWhiteSpace($AccessToken)) {

    Write-Host ""
    Write-Host "Scout JFrog authentication required." `
        -ForegroundColor Yellow
    Write-Host ""

    $secureToken = Read-Host `
        "Enter Scout JFrog Access Token" `
        -AsSecureString

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $secureToken
    )

    try {
        $AccessToken =
            [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                $ptr
            )
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
            $ptr
        )
    }
}

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Scout JFrog Access Token cannot be empty."
}


# ============================================================
# GET LOCAL ROOT FOLDER NAME
# ============================================================

$folderItem = Get-Item -LiteralPath $LocalFolder
$folderName = $folderItem.Name


# ============================================================
# BUILD DYNAMIC TARGET
#
# Example:
#
# Local:
# C:\Downloads\SACID F220
#
# CW:
# cw11
#
# HF:
# hf01
#
# Normalized result:
#
# Official_Release/
# CW11/
# Hotfixes/
# HF01/
# SACID F220/
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
        -Recurse
)

if ($files.Count -eq 0) {
    throw "No files found inside: $LocalFolder"
}


# ============================================================
# SHOW CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "        SCOUT HOTFIX UPLOAD"
Write-Host "============================================"
Write-Host ""
Write-Host "Local Folder:"
Write-Host "  $LocalFolder"

Write-Host ""
Write-Host "Local Folder Name:"
Write-Host "  $folderName"

Write-Host ""
Write-Host "Calendar Week:"
Write-Host "  $CWPath"

Write-Host ""
Write-Host "Hotfix:"
Write-Host "  $HFName"

Write-Host ""
Write-Host "Files:"
Write-Host "  $($files.Count)"

Write-Host ""
Write-Host "Scout Target:"
Write-Host "  $SCOUT_REPO/$targetRoot"

Write-Host ""
Write-Host "============================================"
Write-Host ""


# ============================================================
# AUTHENTICATION
# ============================================================

$headers = @{
    Authorization = "Bearer $AccessToken"
}


# ============================================================
# COUNTERS
# ============================================================

$uploaded = 0
$skipped = 0
$failed = 0

$failedFiles =
    New-Object System.Collections.Generic.List[string]


# ============================================================
# UPLOAD FILES
# ============================================================

foreach ($file in $files) {

    $relativePath =
        [System.IO.Path]::GetRelativePath(
            $LocalFolder,
            $file.FullName
        )

    $relativePath =
        $relativePath.Replace("\", "/")


    # ========================================================
    # SKIP CHECKSUM SIDECAR FILES
    #
    # JFrog interprets these as checksum deployments and
    # previously returned HTTP 409 for mismatched sidecars.
    # ========================================================

    $isChecksumSidecar = (
        $file.Name.EndsWith(
            ".sha256",
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $file.Name.EndsWith(
            ".sha1",
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $file.Name.EndsWith(
            ".md5",
            [System.StringComparison]::OrdinalIgnoreCase
        )
    )

    if ($isChecksumSidecar) {

        Write-Host "SKIP    $relativePath" `
            -ForegroundColor Yellow

        $skipped++

        continue
    }


    # ========================================================
    # BUILD ARTIFACTORY PATH
    # ========================================================

    $artifactPath =
        "$SCOUT_REPO/$targetRoot/$relativePath"

    $encodedArtifactPath =
        ConvertTo-ArtifactoryPath `
            -Path $artifactPath

    $uploadUrl =
        "$JFROG_URL/$encodedArtifactPath"


    Write-Host "UPLOAD  $relativePath"


    # ========================================================
    # REST UPLOAD
    # ========================================================

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

        $failedFiles.Add(
            $relativePath
        )

        Write-Host "FAILED  $relativePath" `
            -ForegroundColor Red

        if (
            $null -ne $_.ErrorDetails -and
            -not [string]::ssage
            )
        ) {

            Write-Host `
                $_.ErrorDetails.Message `
                -ForegroundColor Red
        }
        else {

            Write-Host `
                $_.Exception.Message `
                -ForegroundColor Red
        }
    }
}


# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "            UPLOAD SUMMARY"
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
Write-Host "       HOTFIX UPLOAD SUCCESSFUL"
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
