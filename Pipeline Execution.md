# Pipeline Execution Guide

## Prerequisites

The operator needs:

- Access to the GitHub repository.
- Permission to run GitHub Actions workflows.
- A direct VWG Artifactory artifact URL.
- A Release/CW identifier when executing an Official transfer.
- Access to the Teams/Power Automate approval assigned to the operator.

## Run VWG to Scout Clone

1. Open the GitHub repository.
2. Select **Actions**.
3. Select **VWG to Scout Clone**.
4. Select **Run workflow**.
5. Complete the three inputs.

### Input: VWG JFrog artifact URL

Use a direct Artifactory URL in this format:

```text
https://jfrog.rivianvw.io/artifactory/<repository>/<artifact-path>
```

Do not use a JFrog UI URL containing:

```text
/ui/repos/tree/
```

### Input: Build type

Select one:

```text
nightly
official
```

### Input: Release/CW number

For Nightly:

```text
Leave blank
```

For Official:

```text
Enter the project release identifier, for example CW43, 221, or RVT_P1
```

## Expected Nightly execution

```text
VWG artifact
    -> runner temporary directory
    -> Scout Clone/Daily_Builds/<source-path>
    -> destination verification
    -> one Power Automate request for Daily_Builds
    -> local temporary data deleted
```

Approve the single Power Automate approval. The following workflow then runs:

```text
Scout Clone to FVP
```

Expected FVP destination:

```text
<SCOUT_FVP_REPO>/Daily_Builds/**
```

## Expected Official execution

For Release/CW `CW43`:

```text
VWG artifact
    -> runner temporary directory
    -> Scout Clone/Official_Release/CW43/<source-path>
    -> destination verification
    -> one Power Automate request for Official_Release/CW43
    -> local temporary data deleted
```

Approve the single Power Automate approval.

Expected FVP destination:

```text
<SCOUT_FVP_REPO>/Official_Release/CW43/**
```

## Reject behavior

A rejected request must:

```text
remain in Scout Clone
not dispatch fvp-promotion-approved
not start scout-to-fvp.yml
not change FVP
```

## Successful run validation

Verify all of the following:

1. `VWG to Scout Clone` completed successfully.
2. Exactly one Power Automate run was created.
3. Exactly one approval was generated.
4. The Power Automate `Artifact Path` output was `Daily_Builds` or `Official_Release/<Release-or-CW>`.
5. After approval, exactly one `Scout Clone to FVP` run started.
6. The complete approved root folder exists in FVP.
