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

Manual Hotfix Upload
        |
        | Hotfix Pipeline
        v
Scout Clone / Hotfix
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
        scout-to-fvp.yml
                |
                v
            Scout FVP
```

---

## 2. Pipeline: VWG -> Scout Clone

### Workflow

```text
vwg-to-scout.yml
```

### Purpose

Copies **Official Release** or **Daily Build** content from VWG JFrog to Scout Clone.

### Inputs

| Input | Value |
|---|---|
| **Folder URL** | Full VWG JFrog source folder URL |
| **Build Type** | `Official` or `Daily` |
| **Calendar Week** | Official: `CW29` style value. Daily: build date entered as text |
| **Official Type** | `Release` for Official builds |

### Official Example

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

Destination structure:

```text
Official_Release/
└── CW29/
    └── Release/
        └── vw-group-commit-vault/
            └── <original source hierarchy>
```

### Daily Example

```text
Folder URL:
<VWG JFrog source folder URL>

Build Type:
Daily

Calendar Week / Date:
2026-10-29
```

Conceptual destination:

```text
Daily_Builds/
└── 2026-10-29/
    └── vw-group-commit-vault/
        └── <original source hierarchy>
```

### Execution Steps

1. Open the GitHub repository.
2. Go to **Actions**.
3. Select **VWG to Scout Clone**.
4. Click **Run workflow**.
5. Select the required branch.
6. Enter the **Folder URL**.
7. Select **Build Type**:
   - `Official`
   - `Daily`
8. Enter **Calendar Week / Date**:
   - Official: `CW29`
   - Daily: `2026-10-29`
9. For an Official build, select:
   ```text
   Official Type = Release
   ```
10. Click **Run workflow**.
11. Wait until the workflow completes.
12. Verify the package in **Scout Clone** and confirm that `vw-group-commit-vault` and the underlying hierarchy were preserved.

---

## 3. Pipeline: Scout Clone -> FVP

### Workflow

```text
scout-to-fvp.yml
```

### Purpose

Promotes a validated package from **Scout Clone -> Scout FVP** after approval.

### Trigger Architecture

```text
Power Automate
      |
      v
Teams Approval
      |
      v
Approved
      |
      v
GitHub repository_dispatch
      |
      v
scout-to-fvp.yml
      |
      v
Scout FVP
```

### Inputs

| Input | Description |
|---|---|
| **Source Folder** | Exact Scout Clone folder to promote |
| **Calendar Week** | Example: `CW29` |
| **Release Type** | `Release` or `Hotfix` |
| **Approval Status** | Must be `Approved` before promotion |

The exact Power Automate JSON property names must match the fields expected by `github.event.client_payload` in the final workflow.

### Execution Steps

1. Verify that the package exists in **Scout Clone**.
2. Complete the required validation/testing.
3. Start the **Power Automate** approval flow.
4. Provide:
   ```text
   Source Folder
   Calendar Week
   Release Type
   ```
5. Power Automate sends the approval request to **Microsoft Teams**.
6. The approver reviews the request.
7. If **Rejected**:
   ```text
   STOP
   ```
8. If **Approved**:
   ```text
   Power Automate
        |
        v
   GitHub repository_dispatch
        |
        v
   scout-to-fvp.yml
   ```
9. Monitor the workflow in **GitHub Actions**.
10. Verify the package in **Scout FVP**.
11. Confirm the Calendar Week, Release/Hotfix folder, and source hierarchy are correct.

---

## 4. Pipeline: Hotfix -> Scout Clone

### Purpose

Used for **manually uploaded Hotfix packages**. Hotfix is separate from the VWG Official Release workflow.

### Inputs

| Input | Value |
|---|---|
| **Folder URL** | Full manually uploaded Hotfix folder URL |
| **Calendar Week** | Text input such as `CW29` |
| **Overwrite** | Use the configured option if exposed by the workflow |

**Hotfix number is not required.**

### Example

```text
Folder URL:
<Hotfix source folder URL>

Calendar Week:
CW29
```

Destination concept:

```text
CW29/
└── Hotfix/
    └── vw-group-commit-vault/
        └── <hotfix folder>
```

### Execution Steps

1. Manually upload the Hotfix package.
2. Verify the upload has completed.
3. Copy the complete Hotfix **Folder URL**.
4. Open the GitHub repository.
5. Go to **Actions**.
6. Select the **Hotfix** workflow.
7. Click **Run workflow**.
8. Select the required branch.
9. Enter the **Folder URL**.
10. Enter the **Calendar Week**, for example:
    ```text
    CW29
    ```
11. Select overwrite behavior if the pipeline exposes that input.
12. Click **Run workflow**.
13. Verify the package under the correct **Hotfix** location in Scout Clone.
14. Perform the required validation/testing.
15. Start the **Power Automate approval**.
16. Once approved, Power Automate triggers:
    ```text
    scout-to-fvp.yml
    ```
17. Verify the Hotfix under the corresponding FVP Hotfix path.

---

## 5. Quick Reference

| Pipeline | Source | Inputs | Execution |
|---|---|---|---|
| **VWG -> Scout Clone** | VWG JFrog | Folder URL, Build Type, CW/Date, Official Type | Manual GitHub Actions |
| **Scout Clone -> FVP** | Scout Clone | Source Folder, CW, Release Type, Approval | Power Automate -> Teams Approval -> GitHub Dispatch |
| **Hotfix -> Scout Clone** | Manual Hotfix Upload | Folder URL, CW | Manual GitHub Actions, then approval for FVP |

## Final Flow

```text
DAILY
VWG -> Scout Clone

OFFICIAL RELEASE
VWG -> Scout Clone
    -> Validate
    -> Power Automate
    -> Teams Approval
    -> scout-to-fvp.yml
    -> FVP

HOTFIX
Manual Upload
    -> Hotfix Pipeline
    -> Scout Clone
    -> Validate
    -> Power Automate
    -> Teams Approval
    -> scout-to-fvp.yml
    -> FVP
```
