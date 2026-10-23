# eeint-jfrog-promotion

# VWG to Scout Clone to FVP

## Purpose

This repository transfers an artifact from VWG JFrog to Scout Clone, requests one root-folder approval through Power Automate, and promotes the approved root folder from Scout Clone to FVP.

## End-to-end flow

```text
Manual GitHub workflow
    -> VWG JFrog download
    -> Windows self-hosted runner temporary directory
    -> Scout Clone upload and verification
    -> Local temporary data removed
    -> One Power Automate webhook request
    -> One approval
    -> One repository_dispatch event
    -> Scout Clone to FVP promotion
```

## Build types

### Nightly

```text
Scout Clone: Daily_Builds/<source-path>
Approval root: Daily_Builds
FVP: Daily_Builds/**
```

The Release/CW input is ignored for Nightly.

### Official

```text
Scout Clone: Official_Release/<Release-or-CW>/<source-path>
Approval root: Official_Release/<Release-or-CW>
FVP: Official_Release/<Release-or-CW>/**
```

The Release/CW input is mandatory for Official.

## Workflow files

```text
.github/workflows/vwg-to-scout.yml
.github/workflows/scout-to-fvp.yml
```

## Required GitHub secrets

```text
VWG_JFROG_URL
VWG_JFROG_ACCESS_TOKEN
SCOUT_JFROG_URL
SCOUT_JFROG_ACCESS_TOKEN
SCOUT_CLONE_REPO
SCOUT_FVP_REPO
FVP_APPROVAL_WEBHOOK_URL
```

## Runner labels

```yaml
runs-on:
  - self-hosted
  - Windows
  - X64
```

## Important operating rule

During pipeline-first testing, disable the Scout Clone artifact-level JFrog webhook. The workflow itself calls Power Automate once after transfer verification. Leaving the artifact webhook enabled can create one approval per deployed artifact.
