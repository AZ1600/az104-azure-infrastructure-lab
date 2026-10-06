# AZ-104 Azure Infrastructure Lab Troubleshooting Guide

This document records real issues encountered while building and validating the
AZ-104 Azure Infrastructure Lab.

The purpose is not only to record commands that fixed problems.

For each issue, the goal is to understand:

- what failed
- why it failed
- how the problem was diagnosed
- what fixed it
- why the fix worked
- what engineering lesson can be reused later

---

## 1. Local Repository Path Was Incorrect

### Symptom

The repository was initially assumed to exist at:

```text
~/az104-azure-infrastructure-lab
```

Running:

```bash
cd ~/az104-azure-infrastructure-lab
```

returned:

```text
cd: no such file or directory
```

Git commands executed from the parent directory also returned:

```text
fatal: not a git repository
```

### Diagnosis

The VS Code Explorer showed that the repository was nested under:

```text
~/az104-labs/
```

The correct location was verified using:

```bash
pwd
git rev-parse --show-toplevel
```

The actual repository was:

```text
~/az104-labs/az104-azure-infrastructure-lab
```

### Root Cause

The GitHub repository name had been incorrectly assumed to match a directory
directly under the home directory.

### Resolution

The existing local repository was entered using:

```bash
cd ~/az104-labs/az104-azure-infrastructure-lab
```

Then:

```bash
git checkout main
git pull --ff-only
git status
```

confirmed that the repository was synchronized.

### Why This Works

Git discovers repository metadata from the `.git` directory.

Running Git commands from a directory outside the working tree means Git
cannot find that metadata.

### Lesson

Before modifying a repository, verify:

```bash
pwd
git rev-parse --show-toplevel
git status
```

Do not infer local filesystem paths from GitHub repository names.

---

## 2. `cd..` Failed in zsh

### Symptom

Running:

```text
cd..
```

returned:

```text
zsh: command not found: cd..
```

### Root Cause

`cd` is the command.

`..` is the path argument.

The shell requires whitespace between them.

### Resolution

Use:

```bash
cd ..
```

### Lesson

Small shell syntax mistakes can look like environment or tooling problems.

Read the exact command before troubleshooting the broader system.

---

## 3. Microsoft.RecoveryServices Was Not Registered

### Symptom

Before deploying Azure Backup resources:

```bash
az provider show \
  --namespace Microsoft.RecoveryServices \
  --query registrationState \
  --output tsv
```

returned:

```text
NotRegistered
```

### Diagnosis

The Recovery Services provider had never been registered in the active Azure
subscription.

This was subscription state, not a Bicep syntax problem.

### Root Cause

Azure resource providers expose groups of resource types to a subscription.

A subscription can exist and successfully deploy other Azure resources while a
specific provider remains unregistered.

### Resolution

The provider was registered with:

```bash
az provider register \
  --namespace Microsoft.RecoveryServices \
  --wait
```

Registration was then verified.

### Why This Works

Registering the provider enables the subscription to create and manage:

```text
Microsoft.RecoveryServices/*
```

resources.

### Lesson

A valid infrastructure template does not guarantee the subscription is ready to
deploy every resource type.

Check:

```text
Template validity
Provider registration
Permissions
Region
Subscription state
```

as separate layers.

---

## 4. What-If Displayed 36 Existing Resources as `Ignore`

### Symptom

The backup What-If reported:

```text
Resource changes: 1 to create, 36 to ignore
```

The output included many existing resources from both the AZ-104 lab and
PropertyOps.

At first glance, the long resource list could look as though the backup
deployment was interacting with all of them.

### Diagnosis

The symbols in the What-If output were inspected.

The Recovery Services vault appeared as:

```text
+ Create
```

The other resources appeared as:

```text
* Ignore
```

### Root Cause

The deployment was scoped to an existing resource group containing many other
resources.

Azure could see those resources, but they were not declared in this deployment
and therefore were not being changed by it.

### Resolution

No fix was required.

The What-If was interpreted correctly:

```text
1 to create
36 to ignore
```

The only resource being changed was:

```text
rsv-az104-backup-denmarkeast
```

### Why This Matters

The difference between:

```text
Create
Modify
Delete
Ignore
```

is critical when reviewing infrastructure changes.

### Lesson

Do not judge a What-If result only by how many resources are displayed.

Inspect the action associated with each resource.

---

## 5. Backup Infrastructure Was Separated from the Existing Root Template

### Problem

An earlier project phase had demonstrated that redeploying unrelated resources
can introduce unnecessary risk.

During Private Endpoint work, the deployment also attempted to redeploy the
existing VM.

Azure then compared an immutable SSH configuration and rejected the update.

### Design Decision

The Backup and Recovery phase therefore uses:

```text
backup.bicep
backup.dev.bicepparam
modules/recovery-vault.bicep
```

instead of adding Recovery Services directly to the active Private Storage root
deployment.

### Why This Works

The backup deployment has a smaller management boundary.

Changes to backup infrastructure do not require Azure to reevaluate unrelated
VM, Bastion, networking, Storage, or RBAC resources.

### Lesson

Prefer deployment boundaries that reflect the change being made.

Smaller deployment scope improves:

```text
Safety
What-If readability
Troubleshooting
Rollback reasoning
Change isolation
```

---

## 6. VM Protection Initially Reported `IRPending`

### Symptom

After enabling Azure Backup, the protected VM reported:

```text
ProtectionState: IRPending
Health:          Passed
LastBackupTime:  2001-01-01T00:00:00+00:00
```

### Initial Question

The ConfigureBackup job had completed, so it could appear that backup itself
was already complete.

### Root Cause

Backup configuration and backup data creation are separate operations.

`IRPending` indicated that the VM had been configured for protection but the
initial recovery point had not yet completed.

### Resolution

An on-demand backup was triggered and monitored until completion.

### Why This Works

The protection relationship tells Azure:

```text
Protect this VM using this policy.
```

The backup operation actually creates:

```text
snapshot
backup data
recovery point
```

### Lesson

These are different states:

```text
ConfigureBackup Completed
        !=
Backup Completed
```

Do not claim a workload is recoverable until a recovery point exists.

---

## 7. First VM Backup Took Time to Complete

### Symptom

The backup remained:

```text
InProgress
```

for several minutes.

Repeated calls to:

```bash
az backup job list
```

continued to show the same running backup.

### Diagnosis

No failure status or error details were present.

The job was simply still processing.

### Resolution

The active backup job ID was captured and Azure CLI was allowed to wait for it:

```bash
az backup job wait \
  --resource-group rg-az104-arm-lab \
  --vault-name rsv-az104-backup-denmarkeast \
  --name "$BACKUP_JOB" \
  --timeout 3600
```

The job eventually reported:

```text
Status: Completed
Progress: 100%
```

### Internal Tasks

The completed backup included:

```text
Take Snapshot
Transfer data to vault
Validate Backup
```

### Lesson

Long-running cloud operations should not be treated as failures simply because
they are not immediate.

Check:

```text
Status
Progress
Error details
Job tasks
```

before changing configuration.

---

## 8. Backup Completion Was Verified with a Recovery Point

### Problem

A green backup job alone is useful, but stronger evidence was required.

### Verification

Recovery points were listed explicitly.

Azure returned:

```text
RecoveryPoint:
9138012723089140609

Type:
CrashConsistent
```

The VM also reported:

```text
ProtectionState:  Protected
Health:           Passed
LastBackupStatus: Completed
```

### Why This Matters

There are several distinct claims:

```text
Backup configured
Backup job completed
Recovery point exists
```

Each should be verified independently.

### Lesson

Prefer evidence from the actual resource state rather than relying only on the
command that initiated the operation.

---

## 9. Recovery Was Tested Without Replacing the Source VM

### Risk

A restore test can become destructive if it replaces the original VM or its
disks.

### Design Decision

The restore used:

```text
AlternateLocation
```

and restored only the OS disk.

A temporary resource group was created:

```text
rg-az104-restore-lab
```

### Result

Azure produced:

```text
vmaz104ubuntu-osdisk-20261006-153823
```

with:

```text
State:              Unattached
ProvisioningState:  Succeeded
```

### Why This Works

An alternate-location disk restore proves that Azure can recover backup data
without modifying the original VM.

### Lesson

Recovery tests should minimize risk to the source environment.

Use isolated resources when destructive validation is unnecessary.

---

## 10. Restore Job Completion Was Not the Final Verification

### Symptom

The restore job reported:

```text
Status: Completed
```

### Additional Verification

The target resource group was queried for managed disks.

The restored disk was confirmed as:

```text
Location:           denmarkeast
SKU:                Standard_LRS
State:              Unattached
ProvisioningState:  Succeeded
```

### Why This Matters

A control-plane job saying `Completed` is useful evidence.

But stronger evidence comes from checking the resulting resource itself.

### Lesson

Use both:

```text
Operation status
        +
Resulting resource state
```

when validating infrastructure workflows.

---

## 11. Original VM Was Verified After Restore

### Purpose

The restore was intended to be non-destructive.

The source VM therefore needed to be checked after the recovery operation.

### Verification

Azure reported:

```text
Name:               vm-az104-ubuntu
Location:           denmarkeast
ProvisioningState:  Succeeded
PowerState:         VM deallocated
PrivateIP:          10.20.1.4
PublicIP:           None
```

### Conclusion

The source VM remained unchanged.

The restore created a separate disk rather than replacing the original
workload.

### Lesson

When validating non-destructive recovery, verify both:

```text
Recovered resource
        +
Original resource
```

---

## 12. `ResourceGroupNotFound` After Cleanup Was Expected

### Symptom

After deleting:

```text
rg-az104-restore-lab
```

the first status check showed:

```text
Deleting
```

A later command returned:

```text
(ResourceGroupNotFound)
Resource group 'rg-az104-restore-lab' could not be found.
```

The output appeared in red.

### Root Cause

There was no problem.

The resource group had finished deleting between the two checks.

### Resolution

No corrective action was required.

`ResourceGroupNotFound` was accepted as evidence that cleanup had completed.

### Why This Is Important

An error-shaped response must be interpreted relative to the desired state.

The desired state was:

```text
rg-az104-restore-lab does not exist
```

Azure reporting that it could not find the resource group therefore confirmed
the desired outcome.

### Lesson

Troubleshooting should ask:

```text
What state was I trying to prove?
```

before deciding whether an error message represents failure.

---

# Backup and Recovery Troubleshooting Model

This phase demonstrated the following diagnostic sequence:

```text
Verify local repository
        |
        v
Verify Azure subscription
        |
        v
Verify resource provider registration
        |
        v
Build Bicep
        |
        v
Validate template
        |
        v
Review What-If
        |
        v
Deploy Recovery Services vault
        |
        v
Verify vault
        |
        v
Inspect policy
        |
        v
Enable protection
        |
        v
Interpret IRPending
        |
        v
Trigger first backup
        |
        v
Wait for completion
        |
        v
Verify recovery point
        |
        v
Perform alternate-location restore
        |
        v
Verify restored disk
        |
        v
Verify source VM
        |
        v
Clean up temporary resources
```

---

# General Engineering Lessons

1. Verify local state before changing infrastructure.
2. Do not assume a GitHub repository name equals its local filesystem path.
3. Azure resource-provider registration is independent of Bicep validity.
4. Use What-If to understand exactly what a deployment will manage.
5. Treat `Ignore` differently from `Modify` or `Delete`.
6. Separate unrelated deployment concerns to reduce blast radius.
7. Backup configuration and recovery-point creation are different operations.
8. Long-running cloud operations should be monitored before being treated as failures.
9. Verify recovery points explicitly.
10. Test restores rather than assuming backups are recoverable.
11. Prefer non-destructive restore exercises when learning.
12. Verify both operation status and resulting resource state.
13. Verify the original resource after an alternate-location restore.
14. Clean up temporary cloud resources after validation.
15. Interpret errors in the context of the state being tested.
16. Record why a fix works so troubleshooting knowledge becomes reusable.
