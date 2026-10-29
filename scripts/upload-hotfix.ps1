[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$LocalFolder,

    [Parameter(Mandatory = $true)]
    [string]$CWPath,

    [Parameter(Mandatory = $true)]
    [string]$HFName,

    [Parameter(Mandatory = $false)]
    [string]$AccessToken = ""
)

$ErrorActionPreference = "Stop"


# ============================================================
# CONFIGURATION
# ============================================================

$JFrogUrl = "https://artifactory.sctmtrs.xyz/artifactory"

$ScoutRepository = "rvtm-vw-rvt-scout-build-binaries-clone"


# ============================================================
# NORMALIZE INPUTS
# ============================================================

$LocalFolder = $LocalFolder.Trim()
$LocalFolder = $LocalFolder.TrimEnd('\')
$LocalFolder = $LocalFolder.TrimEnd('/')

$CWPath = $CWPath.Trim()
$CWPath = $CWPath.Trim('\')
$CWPath = $CWPath.Trim('/')
$CWPath = $CWPath.ToUpperInvariant()

$HFName = $HFName.Trim()
$HFName = $HFName.Trim('\')
$HFName = $HFName.Trim('/')
$HFName = $HFName.ToUpperInvariant()


# ============================================================
# NORMALIZE CW
#
# 11   -> CW11
# cw11 -> CW11
# Cw11 -> CW11
# CW11 -> CW11
# ============================================================

if ($CWPath -match '^[0-9]+$') {
    $CWPath = "CW$CWPath"
}


# ============================================================
# NORMALIZE HF
#
# 01   -> HF01
# hf01 -> HF01
# Hf01 -> HF01
# HF01 -> HF01
# ============================================================

if ($HFName -match '^[0-9]+$') {
    $HFName = "HF$HFName"
}


# ============================================================
# VALIDATE INPUTS
# ============================================================

if ($LocalFolder.Length -eq 0) {
    throw "Local Folder cannot be empty."
}

if (-not (Test-Path -LiteralPath $LocalFolder -PathType Container)) {
    throw "Local folder does not exist: $LocalFolder"
}

if ($CWPath.Length -eq 0) {
    throw "CW Path cannot be empty."
}

if ($CWPath -notmatch '^CW[0-9]+.*$') {
    throw "Invalid CW Path: $CWPath. Example: CW11"
}

if ($CWPath.Contains('/')) {
    throw "CW Path cannot contain /"
}

if ($CWPath.Contains('\')) {
    throw "CW Path cannot contain \"
}

if ($HFName.Length -eq 0) {
    throw "HF Name cannot be empty."
}

if ($HFName -notmatch '^HF.+$') {
    throw "Invalid HF Name: $HFName. Example: HF01"
}

if ($HFName.Contains('/')) {
    throw "HF Name cannot contain /"
}

if ($HFName.Contains('\')) {
    throw "HF Name cannot contain \"
}


# ============================================================
# REQUEST SCOUT JFROG TOKEN
# ============================================================

if ($AccessToken.Length -eq 0) {

    Write-Host ""
    Write-Host "Scout JFrog authentication required." -ForegroundColor Yellow
    Write-Host ""

    $SecureToken = Read-Host "Enter Scout JFrog Access Token" -AsSecureString

    $Credential = New-Object `
        System.Management.Automation.PSCredential `
        -ArgumentList "token", $SecureToken

    $AccessToken = $Credential.GetNetworkCredential().Password
}


if ($AccessToken.Length -eq 0) {
    throw "Scout JFrog Access Token cannot be empty."
}


# ============================================================
# GET LOCAL FOLDER NAME
# ============================================================

$FolderInfo = Get-Item -LiteralPath $LocalFolder

$FolderName = $FolderInfo.Name


if ($FolderName.Length -eq 0) {
    throw "Unable to determine local folder name."
}


# ============================================================
# BUILD SCOUT DESTINATION
#
# Example:
#
# Local:
# C:\Downloads\softwareartifact (1)
#
# CW:
# cw11
#
# HF:
# hf01
#
# Result:
#
# Official_Release/
#   CW11/
#     Hotfixes/
#       HF01/
#         softwareartifact (1)/
# ============================================================

$PromotionPath = "Official_Release/$CWPath/Hotfixes/$HFName"

$TargetRoot = "$PromotionPath/$FolderName"


# ============================================================
# FIND FILES
# ============================================================

$Files = @(
    Get-ChildItem `
        -LiteralPath $LocalFolder `
        -File `
        -Recurse `
        -Force
)


if ($Files.Count -eq 0) {
    throw "No files found inside: $LocalFolder"
}


# ============================================================
# DISPLAY CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host "SCOUT HOTFIX UPLOAD"
Write-Host "=============================================="
Write-Host ""
Write-Host "Local Folder : $LocalFolder"
Write-Host "Folder Name  : $FolderName"
Write-Host "CW           : $CWPath"
Write-Host "HF           : $HFName"
Write-Host "Files Found  : $($Files.Count)"
Write-Host ""
Write-Host "Scout Target:"
Write-Host "$ScoutRepository/$TargetRoot"
Write-Host ""
Write-Host "=============================================="
Write-Host ""


# ============================================================
# AUTHENTICATION
# ============================================================

$Headers = @{
    Authorization = "Bearer $AccessToken"
}


# ============================================================
# COUNTERS
# ============================================================

$UploadedCount = 0

$SkippedCount = 0

$FailedCount = 0

$FailedFiles = @()


# ============================================================
# UPLOAD EACH FILE
# ============================================================

foreach ($File in $Files) {

    # --------------------------------------------------------
    # Get path relative to selected local root
    # --------------------------------------------------------

    $RelativePath = [System.IO.Path]::GetRelativePath(
        $LocalFolder,
        $File.FullName
    )

    $RelativePath = $RelativePath.Replace('\', '/')


    # --------------------------------------------------------
    # Skip checksum sidecar files
    #
    # These caused JFrog 409 checksum errors previously.
    # --------------------------------------------------------

    $LowerFileName = $File.Name.ToLowerInvariant()

    $IsChecksum = $false

    if ($LowerFileName.EndsWith('.sha256')) {
        $IsChecksum = $true
    }

    if ($LowerFileName.EndsWith('.sha1')) {
        $IsChecksum = $true
    }

    if ($LowerFileName.EndsWith('.md5')) {
        $IsChecksum = $true
    }


    if ($IsChecksum) {

        Write-Host "SKIP    $RelativePath" -ForegroundColor Yellow

        $SkippedCount = $SkippedCount + 1

        continue
    }


    # --------------------------------------------------------
    # Construct artifact path
    # --------------------------------------------------------

    $ArtifactPath = "$ScoutRepository/$TargetRoot/$RelativePath"


    # --------------------------------------------------------
    # Encode each individual path component.
    #
    # This safely handles:
    #
    # spaces
    # parentheses
    # special characters
    # --------------------------------------------------------

    $PathParts = $ArtifactPath -split '/'

    $EncodedParts = @()


    foreach ($Part in $PathParts) {

        if ($Part.Length -gt 0) {

            $EncodedPart = [System.Uri]::EscapeDataString($Part)

            $EncodedParts += $EncodedPart
        }
    }


    $EncodedArtifactPath = $EncodedParts -join '/'


    # --------------------------------------------------------
    # Build complete upload URL
    # --------------------------------------------------------

    $UploadUrl = "$JFrogUrl/$EncodedArtifactPath"


    Write-Host "UPLOAD  $RelativePath"


    # --------------------------------------------------------
    # Upload artifact
    # --------------------------------------------------------

    try {

        Invoke-RestMethod `
            -Uri $UploadUrl `
            -Method Put `
            -Headers $Headers `
            -InFile $File.FullName `
            -ContentType "application/octet-stream" `
            -ErrorAction Stop |
            Out-Null


        Write-Host "SUCCESS $RelativePath" -ForegroundColor Green


        $UploadedCount = $UploadedCount + 1
    }

    catch {

        $FailedCount = $FailedCount + 1

        $FailedFiles += $RelativePath


        Write-Host "FAILED  $RelativePath" -ForegroundColor Red


        $ErrorMessage = $_.Exception.Message


        if ($null -ne $_.ErrorDetails) {

            if ($null -ne $_.ErrorDetails.Message) {

                if ($_.ErrorDetails.Message.Length -gt 0) {

                    $ErrorMessage = $_.ErrorDetails.Message
                }
            }
        }


        Write-Host $ErrorMessage -ForegroundColor Red
    }
}


# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host "UPLOAD SUMMARY"
Write-Host "=============================================="
Write-Host ""

Write-Host "Uploaded : $UploadedCount" -ForegroundColor Green

Write-Host "Skipped  : $SkippedCount" -ForegroundColor Yellow


if ($FailedCount -eq 0) {

    Write-Host "Failed   : 0" -ForegroundColor Green
}

else {

    Write-Host "Failed   : $FailedCount" -ForegroundColor Red
}


Write-Host ""
Write-Host "Scout Location:"
Write-Host "$ScoutRepository/$TargetRoot"

Write-Host ""
Write-Host "=============================================="


# ============================================================
# HANDLE FAILURES
# ============================================================

if ($FailedCount -gt 0) {

    Write-Host ""
    Write-Host "FAILED FILES:" -ForegroundColor Red


    foreach ($FailedFile in $FailedFiles) {

        Write-Host "  $FailedFile" -ForegroundColor Red
    }


    Write-Host ""


    throw "$FailedCount file(s) failed to upload."
}


# ============================================================
# MAKE SURE SOMETHING WAS ACTUALLY UPLOADED
# ============================================================

if ($UploadedCount -eq 0) {

    throw "No regular artifacts were uploaded."
}


# ============================================================
# SUCCESS
# ============================================================

Write-Host ""
Write-Host "=============================================="
Write-Host "HOTFIX UPLOAD SUCCESSFUL"
Write-Host "=============================================="

Write-Host ""
Write-Host "Scout Clone:"
Write-Host "$ScoutRepository/$TargetRoot"

Write-Host ""
Write-Host "Promotion Root:"
Write-Host "$PromotionPath"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green


exit 0