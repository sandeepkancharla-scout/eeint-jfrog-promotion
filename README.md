# eeint-jfrog-promotion

# JFrog Artifact Promotion Pipelines

## 1. Architecture

```text
                         DAILY BUILD

VWG JFrog
    |
    | vwg-to-scout.yml
    v
Scout Clone


                      OFFICIAL RELEASE

VWG JFrog
    |
    | vwg-to-scout.yml
    v
Scout Clone
    |
    | Validation / Testing
    v
Power Automate
    |
    v
Microsoft Teams Approval
    |
    +-- Rejected ----------------> STOP
    |
    +-- Approved
            |
            v
    GitHub repository_dispatch
            |
            | scout-to-fvp.yml
            v
        Scout FVP


                           HOTFIX

Local Windows Folder
        |
        | scripts/upload-hotfix.bat
        v
scripts/upload-hotfix.ps1
        |
        | Scout JFrog REST API
        v
Scout Clone
Official_Release/<CW>/Hotfixes/<HF>/<LOCAL_FOLDER_NAME>/...
        |
        | Validation / Testing
        v
Power Automate
        |
        v
Microsoft Teams Approval
        |
        +-- Rejected ------------> STOP
        |
        +-- Approved
                |
                v
        GitHub repository_dispatch
                |
                | scout-to-fvp.yml
                v
            Scout FVP
            <CW>/Hotfixes/<HF>/<LOCAL_FOLDER_NAME>/...
```

---

# 2. Pipeline: VWG → Scout Clone

## Workflow

```text
vwg-to-scout.yml
```

## Purpose

Copies **Official Release** or **Daily Build** content from VWG JFrog to Scout Clone.

## Runner Requirement

The VWG JFrog endpoint is currently not reachable from a standard GitHub-hosted `ubuntu-latest` runner.

The connectivity test failed during DNS resolution of the VWG JFrog hostname.

Therefore, `vwg-to-scout.yml` continues to use the Windows self-hosted runner that has access to the required VWG network and DNS environment.

## Inputs

| Input | Value |
|---|---|
| **Folder URL** | Full VWG JFrog source folder URL |
| **Build Type** | `Official` or `Daily` |
| **Calendar Week / Date** | Official: `CW29`; Daily: `2026-10-29` |
| **Official Type** | `Release` for Official builds |

## Official Example

```text
Folder URL:
<VWG JFrog source folder URL>

Build Type:
Official

Calendar Week:
CW29

Official Type:
Release
```

Destination:

```text
Official_Release/
└── CW29/
    └── Release/
        └── vw-group-commit-vault/
            └── <original source hierarchy>
```

## Daily Example

```text
Folder URL:
<VWG JFrog source folder URL>

Build Type:
Daily

Calendar Week / Date:
2026-10-29
```

Destination:

```text
Daily_Builds/
└── 2026-10-29/
    └── vw-group-commit-vault/
        └── <original source hierarchy>
```

## Execution Steps

1. Open the GitHub repository.
2. Go to **Actions**.
3. Select **VWG to Scout Clone**.
4. Click **Run workflow**.
5. Select the required branch.
6. Enter the complete VWG JFrog **Folder URL**.
7. Select the **Build Type**:
   - `Official`
   - `Daily`
8. Enter the **Calendar Week / Date**:
   - Official: `CW29`
   - Daily: `2026-10-29`
9. For an Official build, use:

   ```text
   Official Type = Release
   ```

10. Click **Run workflow**.
11. Wait until the workflow completes.
12. Verify the package in Scout Clone.
13. Confirm `vw-group-commit-vault` and the complete hierarchy were preserved.

---

# 3. Pipeline: Scout Clone → FVP

## Workflow

```text
scout-to-fvp.yml
```

## Purpose

Promotes an approved package from **Scout Clone → Scout FVP**.

## Trigger Architecture

```text
Power Automate
      |
      v
Microsoft Teams Approval
      |
      +-- Rejected ----> STOP
      |
      +-- Approved
              |
              v
      GitHub repository_dispatch
              |
              | event_type = scout-to-fvp
              v
      scout-to-fvp.yml
              |
              v
      Scout FVP
```

## Trigger

`scout-to-fvp.yml` is triggered by:

```yaml
repository_dispatch:
  types:
    - scout-to-fvp
```

There are no manual GitHub Actions inputs for this workflow.

Power Automate sends the exact approved Scout Clone folder as:

```text
client_payload.folder_path
```

### Official Release Example

```json
{
  "folder_path": "Official_Release/CW11/Release"
}
```

### Hotfix Example

```json
{
  "folder_path": "Official_Release/CW11/Hotfixes/HF01"
}
```

## Path Mapping

For Official content, only the leading:

```text
Official_Release/
```

is removed when constructing the FVP destination.

### Official Release

Scout Clone:

```text
Official_Release/
└── CW11/
    └── Release/
        └── vw-group-commit-vault/
            └── ...
```

FVP:

```text
CW11/
└── Release/
    └── vw-group-commit-vault/
        └── ...
```

The following duplicated path is incorrect and must never be created:

```text
CW11/
└── Release/
    └── Official_Release/
        └── CW11/
            └── Release/
```

### Hotfix

Scout Clone:

```text
Official_Release/
└── CW11/
    └── Hotfixes/
        └── HF01/
            └── ...
```

FVP:

```text
CW11/
└── Hotfixes/
    └── HF01/
        └── ...
```

### Daily

When a Daily package is explicitly approved for FVP promotion, the Daily hierarchy is preserved:

Scout Clone:

```text
Daily_Builds/
└── 2026-10-29/
    └── ...
```

FVP:

```text
Daily_Builds/
└── 2026-10-29/
    └── ...
```

## Execution Steps

1. Verify the package exists in Scout Clone.
2. Complete the required validation/testing.
3. Power Automate sends one Microsoft Teams approval.
4. The approver reviews the request.
5. If **Rejected**:

   ```text
   STOP
   ```

6. If **Approved**, Power Automate sends:

   ```text
   repository_dispatch
   ```

   with:

   ```text
   event_type = scout-to-fvp
   ```

7. Power Automate supplies:

   ```text
   folder_path
   ```

8. `scout-to-fvp.yml` verifies the Scout Clone source.
9. The complete contents of the approved folder are copied recursively.
10. Verify the package in Scout FVP.
11. Confirm the hierarchy matches the expected FVP structure.

---

# 4. Hotfix Upload: Local Windows PC → Scout Clone

## Purpose

Hotfix upload is separate from the normal VWG Official Release workflow.

A Hotfix package can exist on any Windows computer that:

- can reach Scout JFrog;
- has PowerShell 7;
- has a valid Scout JFrog access token.

The Hotfix upload does **not require a GitHub Actions runner**.

The flow is:

```text
Local Windows Folder
        |
        | upload-hotfix.bat
        v
upload-hotfix.ps1
        |
        | JFrog REST PUT
        v
Scout Clone
Official_Release/<CW>/Hotfixes/<HF>/<LOCAL_FOLDER_NAME>/...
```

## Files

The Hotfix utility contains:

```text
scripts/
├── upload-hotfix.bat
└── upload-hotfix.ps1
```

Both files must remain together in the same directory.

Users can copy/download the `scripts` directory to a Windows computer and run the BAT file.

---

## Prerequisites

The computer requires:

- Windows
- PowerShell 7
- Network access to Scout Artifactory
- A valid Scout JFrog access token
- Deploy permission for the Scout Clone repository
- Local access to the Hotfix folder

Verify PowerShell 7:

```powershell
pwsh --version
```

The Hotfix uploader does not require:

- GitHub CLI
- GitHub Actions
- GitHub-hosted Ubuntu
- A self-hosted GitHub runner
- GitHub Actions secrets
- SharePoint synchronization

---

## User Inputs

The BAT asks for:

| Input | Example |
|---|---|
| **Local Folder Path** | `C:\Users\User\Downloads\softwareartifact (1)` |
| **Calendar Week** | `CW11`, `cw11`, or `11` |
| **Hotfix Name** | `HF01`, `hf01`, or `01` |

The PowerShell script then securely requests:

```text
Scout JFrog Access Token
```

---

## CW and HF Normalization

Calendar Week and Hotfix identifiers are normalized automatically.

| Entered | Normalized |
|---|---|
| `cw11` | `CW11` |
| `Cw11` | `CW11` |
| `CW11` | `CW11` |
| `11` | `CW11` |
| `hf01` | `HF01` |
| `Hf01` | `HF01` |
| `HF01` | `HF01` |
| `01` | `HF01` |

This prevents separate paths such as:

```text
cw11
CW11
Cw11
```

from being created.

The normalized Scout folder is always:

```text
CW11
```

and the normalized Hotfix is always:

```text
HF01
```

for those examples.

---

## Dynamic Destination

The Scout destination is generated dynamically:

```text
Official_Release/<CW>/Hotfixes/<HF>/<LOCAL_FOLDER_NAME>/...
```

Nothing is hardcoded to a specific:

```text
CW
HF
Local Folder
```

### Example

User selects:

```text
C:\Users\SandeepKancharla\Downloads\softwareartifact (1)
```

and provides:

```text
CW:
cw11

HF:
hf01
```

The uploader normalizes the inputs and creates:

```text
rvtm-vw-rvt-scout-build-binaries-clone/
└── Official_Release/
    └── CW11/
        └── Hotfixes/
            └── HF01/
                └── softwareartifact (1)/
                    └── <complete local hierarchy>
```

---

## Existing HF Folder Behavior

An existing `HFxx` folder is **not deleted**.

For example, Scout may already contain:

```text
Official_Release/
└── CW11/
    └── Hotfixes/
        └── HF01/
            ├── ECU_A/
            └── ECU_B/
```

A user then uploads:

```text
softwareartifact (1)/
```

The result becomes:

```text
Official_Release/
└── CW11/
    └── Hotfixes/
        └── HF01/
            ├── ECU_A/
            ├── ECU_B/
            └── softwareartifact (1)/
```

The complete `HF01` directory is not replaced.

Existing unrelated Hotfix content remains unchanged.

If a file already exists at the exact same destination path, Artifactory handles the deployment according to repository permissions and overwrite policy.

---

## Recursive Upload

The PowerShell script discovers files recursively.

Example local source:

```text
softwareartifact (1)/
├── file1.bin
├── config/
│   └── settings.json
└── artifacts/
    └── package.tar.zst
```

Scout result:

```text
Official_Release/CW11/Hotfixes/HF01/softwareartifact (1)/
├── file1.bin
├── config/
│   └── settings.json
└── artifacts/
    └── package.tar.zst
```

The hierarchy below the selected local folder is preserved.

Folder names containing spaces and parentheses are supported.

---

## Checksum Sidecar Handling

The current uploader skips:

```text
.sha256
.sha1
.md5
```

These sidecars previously produced Artifactory HTTP `409` checksum deployment errors when uploaded as normal artifacts.

Example:

```text
SKIP    package.tar.zst.sha256
```

The actual artifact:

```text
package.tar.zst
```

continues to upload normally.

---

## Running the Hotfix Uploader

From the repository:

```powershell
.\scripts\upload-hotfix.bat
```

Or double-click:

```text
upload-hotfix.bat
```

### Example session

```text
Enter Local Folder Path:
C:\Users\SandeepKancharla\Downloads\softwareartifact (1)

Enter CW Path:
cw11

Enter HF Name:
hf01
```

The BAT starts:

```text
upload-hotfix.ps1
```

PowerShell then displays:

```text
Scout JFrog authentication required.

Enter Scout JFrog Access Token:
```

---

## Scout Token Entry

The token prompt is secure.

While entering/pasting the token:

```text
no characters appear
no *
no dots
```

This is expected.

Paste the token and press:

```text
Enter
```

Do not interpret the blank prompt as the token not being entered.

---

## Upload Output

Each artifact shows its status.

Example:

```text
UPLOAD  config/settings.json
SUCCESS config/settings.json
```

Checksum sidecars:

```text
SKIP    package.tar.zst.sha256
```

Failure:

```text
FAILED  artifacts/package.tar.zst
```

At completion:

```text
==============================================
UPLOAD SUMMARY
==============================================

Uploaded : 25
Skipped  : 3
Failed   : 0
```

The PS1 exits with a non-zero exit code when one or more normal artifacts fail.

---

## Initial Validation

Use a small folder before testing with large ECU artifacts.

Create:

```text
C:\Temp\hotfix-test/
├── test1.txt
└── config/
    └── test2.txt
```

Run:

```text
Local Folder:
C:\Temp\hotfix-test

CW:
cw11

HF:
hf01
```

Expected Scout result:

```text
Official_Release/
└── CW11/
    └── Hotfixes/
        └── HF01/
            └── hotfix-test/
                ├── test1.txt
                └── config/
                    └── test2.txt
```

Validate:

- JFrog token prompt appears.
- `cw11` becomes `CW11`.
- `hf01` becomes `HF01`.
- Local root-folder name is preserved.
- Nested folders are preserved.
- Existing `HF01` content remains.
- Summary reports `Failed : 0`.

---

## Hotfix Troubleshooting

### `upload-hotfix.ps1` Not Found

The directory must contain:

```text
scripts/
├── upload-hotfix.bat
└── upload-hotfix.ps1
```

The BAT determines the PS1 location relative to itself.

---

### `pwsh.exe` Not Found

Run:

```powershell
pwsh --version
```

Install PowerShell 7 if unavailable.

---

### Local Folder Not Found

Run:

```powershell
Test-Path -LiteralPath "C:\path\to\hotfix-folder"
```

Expected:

```text
True
```

---

### Token Reported as Empty

The secure prompt displays nothing.

At:

```text
Enter Scout JFrog Access Token:
```

paste the token and press Enter.

---

### HTTP 401 / 403

Verify that the token:

- is valid;
- has not expired;
- is authorized for Scout Artifactory;
- has deploy permission to:

```text
rvtm-vw-rvt-scout-build-binaries-clone
```

---

### JFrog URL Corruption

The PowerShell script must contain:

```powershell
$JFrogUrl = "https://artifactory.sctmtrs.xyz/artifactory"
```

It must **not** contain HTML such as:

```html
<a href="...">
```

---

### PowerShell Parser Errors

Validate the PS1 before uploading:

```powershell
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    "$PWD\scripts\upload-hotfix.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null

$errors
```

No output means the file has no PowerShell parser errors.

---

## Power Automate Integration for Hotfix

Power Automate integration is intentionally held until the direct Hotfix upload is stable.

The next phase will be:

```text
Complete Hotfix upload
        |
        | ONE webhook request
        v
Power Automate
        |
        v
ONE Microsoft Teams Approval
        |
        +-- Rejected ----> STOP
        |
        +-- Approved
                |
                v
        GitHub repository_dispatch
                |
                | event_type = scout-to-fvp
                v
        scout-to-fvp.yml
                |
                v
            Scout FVP
```

The Hotfix approval root will be:

```text
Official_Release/<CW>/Hotfixes/<HF>
```

Example:

```text
Official_Release/CW11/Hotfixes/HF01
```

After approval:

```text
Scout Clone:
Official_Release/CW11/Hotfixes/HF01/softwareartifact (1)/...

FVP:
CW11/Hotfixes/HF01/softwareartifact (1)/...
```

Only the outer:

```text
Official_Release/
```

is removed for the FVP destination.

---

# 5. Quick Reference

| Pipeline / Tool | Source | Inputs | Execution |
|---|---|---|---|
| **VWG → Scout Clone** | VWG JFrog | Folder URL, Build Type, CW/Date, Official Type | GitHub Actions on Windows self-hosted runner |
| **Scout Clone → FVP** | Scout Clone | `folder_path` from Power Automate | Teams Approval → `repository_dispatch` |
| **Hotfix → Scout Clone** | Local Windows folder | Local Folder, CW, HF, Scout Token | BAT → PowerShell → JFrog REST |

---

# 6. Final Flow

```text
DAILY

VWG JFrog
    |
    | vwg-to-scout.yml
    v
Scout Clone
Daily_Builds/<date>/...


OFFICIAL RELEASE

VWG JFrog
    |
    | vwg-to-scout.yml
    v
Scout Clone
Official_Release/<CW>/Release/...
    |
    v
Validation / Testing
    |
    v
Power Automate
    |
    v
Teams Approval
    |
    v
scout-to-fvp.yml
    |
    v
Scout FVP
<CW>/Release/...


HOTFIX

Local Windows Folder
    |
    | upload-hotfix.bat
    v
upload-hotfix.ps1
    |
    | Scout JFrog REST
    v
Scout Clone
Official_Release/<CW>/Hotfixes/<HF>/<folder>/...
    |
    v
Validation / Testing
    |
    v
Power Automate
[enabled after local uploader validation]
    |
    v
Teams Approval
    |
    v
scout-to-fvp.yml
    |
    v
Scout FVP
<CW>/Hotfixes/<HF>/<folder>/...
