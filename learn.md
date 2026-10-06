# Learning Notes: Azure Infrastructure Lab

These notes capture what I learned while building and troubleshooting the AZ-104 Azure infrastructure lab.

The project uses a practical engineering workflow:

```text
Build → Validate → What-If → Deploy → Verify
```

Each phase produced a different lesson about Azure infrastructure, networking, identity, authorization, Private Link, and operational validation.

---

## 1. Infrastructure as Code Needs a Review Workflow

I followed this deployment sequence:

```text
Build
  ↓
Validate
  ↓
What-If
  ↓
Deploy
  ↓
Verify
```

Each stage answers a different question:

| Stage | Question |
|---|---|
| Build | Can Bicep compile the template? |
| Validate | What problems can Azure identify before deployment? |
| What-If | What resource changes does Azure predict? |
| Deploy | Can Azure apply the requested configuration? |
| Verify | Does the resulting environment match my intention? |

A successful build does not prove that deployment will succeed.

Subscription restrictions, resource availability, immutable properties, permissions, runtime dependencies, and existing resource state can still affect the deployment.

---

## 2. VM Availability Depends on the Deployment Context

My initial compute deployment in UK South encountered a VM SKU restriction.

I introduced a separate:

```text
computeLocation
```

parameter and successfully deployed the compute environment in Denmark East using:

```text
Standard_B1s
```

The lesson was to investigate the actual Azure error before changing infrastructure code.

A regional or subscription restriction is different from a Bicep syntax error.

The successful region and size are historical results from this lab and are not guarantees of future availability.

---

## 3. Separate Compute Location from Existing Infrastructure

Changing a shared location parameter could have affected resources that were already deployed.

Using:

```text
computeLocation
```

allowed the compute environment to be deployed in another Azure region without changing the intended location of earlier resources.

This made the infrastructure safer to evolve incrementally.

---

## 4. What-If Is an Important Review Step

Before deployment, I reviewed the proposed resource changes rather than relying only on successful validation.

What-If helped identify:

```text
Create
Modify
Delete
NoChange
Ignore
```

operations before Azure applied them.

What-If is still a prediction.

Azure-managed properties, unresolved expressions, default values, and nested deployment behaviour can produce output that requires interpretation.

It should be reviewed rather than blindly accepted.

---

## 5. Incremental Mode Does Not Mean Existing Resources Cannot Change

The deployments used incremental mode.

Resources omitted from a template are generally retained.

However, resources that remain inside the deployment can still be modified.

This became important later when the existing VM was unintentionally included in the Private Storage deployment.

Incremental deployment should not be treated as:

```text
Never modify existing resources
```

It means:

```text
Do not automatically delete resources merely because they are absent
```

Included resources still require careful review.

---

## 6. Warnings Need Interpretation

Bicep reported unused parameters while earlier modules were temporarily inactive.

These warnings did not prevent compilation, but they identified cleanup opportunities.

Validation diagnostics also demonstrated that an overall successful command does not necessarily mean every nested expression or resource was fully evaluated.

Warnings should be understood instead of automatically ignored.

---

## 7. Provisioning Success and Connectivity Are Separate

The compute deployment confirmed:

```text
VM: vm-az104-ubuntu
Region: Denmark East
Size: Standard_B1s
Provisioning state: Succeeded
Private IP: 10.20.1.4
Public IP: None
```

This proved that the VM existed.

It did not prove that the VM could be reached through the intended management path.

Provisioning and connectivity require separate evidence.

---

## 8. An NSG Rule Does Not Create a Network Path

The compute NSG included:

```text
Protocol: TCP
Destination port: 22
Source: VirtualNetwork
Priority: 100
```

An allow rule does not create connectivity by itself.

A valid path also requires:

```text
Addressing
Routing
Security rules
Listening service
Authentication
Client configuration
```

Network troubleshooting should therefore be performed layer by layer.

---

## 9. SSH Keys Have Different Roles

The VM receives an SSH public key.

The private key stays on the local workstation.

These files serve different purposes:

```text
Public key
    ↓
Installed on the VM

Private key
    ↓
Used by the administrator
    ↓
Must remain secret
```

A configured public key does not prove that a client is using the correct matching private key.

This became important during Bastion troubleshooting.

---

## 10. Verify Power State When Controlling Costs

After validation, I deallocated the VM.

Azure reported:

```text
VM deallocated
```

Provisioning state and power state are different.

A VM can remain fully provisioned while its compute allocation has been released.

Deallocation reduces compute charges but does not remove all associated costs.

Managed disks, Private Endpoints, networking resources, and other services can continue to incur charges.

---

## 11. Git Ignore Rules Are Not Retroactive

I added `.gitignore` after the project had already been created.

Ignore rules apply primarily to untracked files.

They do not automatically:

```text
Remove already tracked files
Erase previous commits
Remove historical secrets
```

Tracked content must be inspected separately.

---

## 12. Bastion Troubleshooting Should Be Layered

The first Bastion browser sessions failed even though the infrastructure had been successfully provisioned.

I investigated the problem in layers.

### SSH Listener

Azure Run Command confirmed that the SSH service was listening on port 22.

### SSH Key

The public-key fingerprint configured on the VM was compared with the local key fingerprint.

They matched.

### Effective NSG

The VM showed an effective allow rule for:

```text
TCP 22
Source: VirtualNetwork
```

### Effective Routes

The NIC route table showed:

```text
10.20.0.0/16
Next hop: VnetLocal
```

### Network Watcher

Connection Troubleshoot confirmed that the Bastion-to-VM TCP/22 path was healthy.

### Final Cause

The browser file picker had selected the wrong local SSH private key.

After selecting the correct private key, the Bastion SSH session succeeded.

The lesson was that a network problem should not be assumed just because a remote login fails.

---

## 13. Authentication and Authorization Are Different

The VM uses a system-assigned managed identity.

Managed identity answers:

```text
Who is making the request?
```

Azure RBAC answers:

```text
What is that identity allowed to do?
```

The VM identity receives:

```text
Storage Blob Data Reader
```

at the Storage account scope.

Authentication alone would not give the VM permission to read Blob data.

Authorization is a separate control.

---

## 14. Managed Identity Removes Stored Application Credentials

The VM requested an access token from Azure Instance Metadata Service:

```text
169.254.169.254
```

The token was used to authenticate to Azure Blob Storage.

The workload did not require:

```text
Storage account key
SAS token
Connection string
Password
Client secret
```

This demonstrated credential-free workload authentication.

Azure still manages credentials behind the scenes, but the workload does not need to store or rotate a long-lived application secret.

---

## 15. Deterministic RBAC Resource IDs Improve What-If

The first RBAC design based the role-assignment resource name on a managed identity principal ID that Azure could only determine at deployment time.

What-If could not fully calculate the resulting resource identity.

The role assignment was changed so its deterministic GUID used stable Azure resource IDs.

The managed identity principal ID remained the actual RBAC assignee.

After the change, What-If could identify the role assignment as a normal resource creation.

This improved preview quality and deployment predictability.

---

## 16. Private Endpoint Adds a Network Security Layer

Managed identity and RBAC secured authentication and authorization, but the Storage network path was still a separate concern.

A dedicated subnet was added:

```text
subnet-private-endpoints
10.20.3.0/27
```

The Storage Blob Private Endpoint was deployed into this subnet.

Its private IP was:

```text
10.20.3.4
```

Azure reported:

```text
ProvisioningState: Succeeded
ConnectionState: Approved
```

This established a Private Link path between the compute VNet and Azure Blob Storage.

---

## 17. Private DNS Is Essential to Private Endpoint Connectivity

Creating a Private Endpoint alone is not enough.

The workload must resolve the service hostname to the private endpoint IP.

The lab created:

```text
privatelink.blob.core.windows.net
```

and linked it to:

```text
vnet-az104-compute
```

From the VM:

```text
az104lab2uvqlnnpoiad6.blob.core.windows.net
```

resolved through the Private Link hostname to:

```text
10.20.3.4
```

This showed that DNS inside the VNet was directing Blob traffic toward the private endpoint.

---

## 18. Private Connectivity Should Be Tested from the Workload

Azure reporting a Private Endpoint as:

```text
Succeeded
Approved
```

proves that the Azure resource exists.

It does not prove that the workload can use it.

I therefore tested name resolution from:

```text
vm-az104-ubuntu
```

The VM resolved the Storage hostname to:

```text
10.20.3.4
```

This provided workload-level evidence that Private DNS and Private Link were working together.

---

## 19. Authentication, Authorization, and Networking Can Be Validated Together

After verifying private DNS, the VM requested an Azure Storage token through its managed identity.

The token was sent to the Blob endpoint.

Azure returned:

```text
HTTP/1.1 200 OK
```

and the request successfully listed:

```text
identity-test
```

This demonstrated the complete path:

```text
VM
 |
 | Managed Identity
 v
Microsoft Entra ID
 |
 | Storage Blob Data Reader
 v
Azure Storage
 ^
 |
 | Private Endpoint
 |
10.20.3.4
 ^
 |
Private DNS
```

The result proved:

```text
Authentication succeeded
Authorization succeeded
Private DNS succeeded
Private network connectivity succeeded
Blob API access succeeded
```

---

## 20. ARM Deployments Can Partially Succeed

The first Private Storage deployment reported an overall failure.

The failure occurred because the deployment also attempted to update the existing VM.

Azure rejected the change with:

```text
PropertyChangeNotAllowed
```

The specific immutable property was:

```text
linuxConfiguration.ssh.publicKeys
```

However, inspecting deployment operations showed:

```text
storagePrivateEndpointModule    Succeeded
computeNetworkModule            Succeeded
computeModule                   Failed
```

The overall deployment had failed, but some nested deployments had already completed successfully.

This was an important operational lesson.

After a deployment failure, inspect:

```text
Deployment operations
Individual resource state
Nested deployment state
Actual Azure resources
```

before deleting or retrying infrastructure.

---

## 21. Do Not Redeploy Unrelated Resources Unnecessarily

The Private Storage phase did not require a VM configuration change.

The VM only needed to exist inside the VNet and use its already configured managed identity.

Including the compute module caused Azure to compare the VM template with its existing immutable SSH configuration.

The root template was therefore narrowed so the active Private Storage deployment manages only:

```text
Compute VNet
Private Endpoint subnet
Storage Private Endpoint
Private DNS zone
VNet DNS link
Private DNS zone group
```

The already validated VM and RBAC resources remain outside the active root deployment.

This reduced risk and made the change easier to reason about.

---

## 22. Successful Resource State Is More Important Than a Single Command Exit

The first top-level deployment returned:

```text
Failed
```

but the Private Endpoint existed and was functional.

I verified its actual Azure state:

```text
ProvisioningState: Succeeded
ConnectionState: Approved
Private IP: 10.20.3.4
```

The Private DNS zone also existed and resolved correctly.

This reinforced that infrastructure troubleshooting should use multiple sources of evidence rather than relying on one command's final status.

---

## 23. Public and Private Storage Paths Should Be Treated Separately

This phase proved that the workload can reach Azure Blob Storage through Private Link.

It did not yet disable the Storage account's public network path.

That is an important distinction.

The correct sequence for this lab is:

```text
Create private path
        ↓
Verify private DNS
        ↓
Verify workload access
        ↓
Then review public-network restrictions
```

Disabling public access before proving the private path would make troubleshooting more difficult.

---

## 24. Verify the Local Repository Before Running Git Commands

At the beginning of the Backup and Recovery phase, I initially assumed the
repository existed directly under my home directory:

```text
~/az104-azure-infrastructure-lab
```

The actual repository was:

```text
~/az104-labs/az104-azure-infrastructure-lab
```

Running Git commands from the wrong directory produced:

```text
fatal: not a git repository
```

The correct repository location was verified with:

```bash
pwd
git rev-parse --show-toplevel
git status
```

This reinforced an important operational habit:

```text
Repository name
    !=
Guaranteed local filesystem path
```

Before making changes, verify the actual working directory and Git root.

---

## 25. Azure Resource Provider Registration Is Subscription State

Before creating Recovery Services resources, I checked:

```bash
az provider show \
  --namespace Microsoft.RecoveryServices \
  --query registrationState \
  --output tsv
```

Azure returned:

```text
NotRegistered
```

The Bicep template was not the problem.

The Azure subscription had not yet registered:

```text
Microsoft.RecoveryServices
```

The provider was registered using:

```bash
az provider register \
  --namespace Microsoft.RecoveryServices \
  --wait
```

After registration Azure returned:

```text
Registered
```

This demonstrated that infrastructure deployment depends on more than valid
template syntax.

The dependency chain is:

```text
Valid Bicep
    |
    v
Registered Azure resource provider
    |
    v
Correct permissions and subscription state
    |
    v
Resource deployment
```

A valid Bicep template can still fail when the subscription is not enabled for
the required resource type.

---

## 26. Backup Infrastructure Was Isolated from the Existing Deployment

An earlier project phase demonstrated the risk of redeploying unrelated
resources together.

During the Private Endpoint work, the root deployment also attempted to modify
the existing VM and Azure rejected an immutable SSH-key change.

For Backup and Recovery I therefore created a separate deployment path:

```text
backup.bicep
backup.dev.bicepparam
modules/recovery-vault.bicep
```

The backup deployment does not manage:

```text
VM configuration
Bastion
Storage
Private Endpoint
Private DNS
RBAC
```

This reduces blast radius and makes each infrastructure change easier to
understand.

---

## 27. What-If Confirmed the Backup Deployment Scope

Before deploying the Recovery Services vault I ran:

```bash
az deployment group what-if \
  --resource-group rg-az104-arm-lab \
  --template-file backup.bicep \
  --parameters backup.dev.bicepparam
```

Azure reported:

```text
Resource changes: 1 to create, 36 to ignore
```

The only resource to be created was:

```text
Microsoft.RecoveryServices/vaults/rsv-az104-backup-denmarkeast
```

The existing resources displayed as `Ignore` because they existed in the
resource group but were outside this deployment's management scope.

The important distinction was:

```text
Ignore
    !=
Modify
```

The What-If evidence showed that the deployment would not change the existing
VM, networking, PropertyOps resources, Storage resources, or Private
Endpoints.

---

## 28. Recovery Services Vault Deployment

The Recovery Services vault was created as:

```text
rsv-az104-backup-denmarkeast
```

in:

```text
denmarkeast
```

This matches the region containing:

```text
vm-az104-ubuntu
```

Verification showed:

```text
ProvisioningState:   Succeeded
PublicNetworkAccess: Enabled
Location:            denmarkeast
```

The vault exposed two Azure IaaS VM policies:

```text
DefaultPolicy
EnhancedPolicy
```

This exercise used:

```text
DefaultPolicy
```

---

## 29. Backup Protection and Recovery Points Are Different States

Before protection was enabled:

```bash
az backup protection check-vm \
  --resource-group rg-az104-arm-lab \
  --vm vm-az104-ubuntu
```

returned no Recovery Services vault.

Protection was then enabled using:

```bash
az backup protection enable-for-vm \
  --resource-group rg-az104-arm-lab \
  --vault-name rsv-az104-backup-denmarkeast \
  --vm vm-az104-ubuntu \
  --policy-name DefaultPolicy
```

The ConfigureBackup job completed successfully.

However, the protected item initially reported:

```text
ProtectionState: IRPending
Health:          Passed
LastBackupTime:  2001-01-01T00:00:00+00:00
```

This showed that:

```text
Backup configuration exists
        !=
Recovery point exists
```

The VM had been registered for protection, but no initial recovery point had
completed yet.

---

## 30. `IRPending` Identified the Missing Initial Recovery Point

The state:

```text
IRPending
```

meant the initial backup had not completed.

The placeholder timestamp:

```text
2001-01-01T00:00:00+00:00
```

was another indication that there was not yet a successful backup.

This prevented me from treating:

```text
Protection enabled
```

as equivalent to:

```text
Recoverable backup exists
```

---

## 31. On-Demand Backup Created the First Recovery Point

An on-demand backup was triggered for:

```text
vm-az104-ubuntu
```

The backup job initially reported:

```text
Backup
InProgress
```

Rather than repeatedly checking manually, the active job was identified and
Azure CLI was used to wait for completion.

The final job reported:

```text
Operation: Backup
Status:    Completed
Progress:  100%
Backup Size: 3521 MB
```

Its internal stages included:

```text
Take Snapshot        Completed
Transfer data        Completed
Validate Backup      Completed
```

This was stronger evidence than simply seeing backup configuration in the
vault.

---

## 32. The Recovery Point Was Verified Directly

After the backup completed, recovery points were queried.

Azure returned:

```text
RecoveryPoint:
9138012723089140609

Time:
2026-10-06T15:02:00.270798+00:00

Type:
CrashConsistent
```

The protected item reported:

```text
ProtectionState:  Protected
Health:           Passed
LastBackupStatus: Completed
LastBackupTime:   2026-10-06T15:01:51.998475+00:00
```

The recovery point type observed in this exercise was:

```text
CrashConsistent
```

I recorded the actual consistency type rather than assuming application
consistency.

---

## 33. Backup Success Is Not the Same as Restore Validation

A successful backup proves that Azure stored a recovery point.

It does not prove that the restore workflow has been tested.

The next validation therefore used an isolated temporary resource group:

```text
rg-az104-restore-lab
```

A temporary staging Storage account was also created in:

```text
denmarkeast
```

The latest recovery point was selected programmatically instead of manually
copying its identifier.

The restore used:

```text
AlternateLocation
```

and:

```text
restore-only-osdisk
```

This allowed recovery testing without replacing the original VM.

---

## 34. Alternate-Location Disk Restore Completed Successfully

The restore job reported:

```text
Operation: Restore
Status:    Completed
Duration:  approximately 1 minute 7 seconds
```

The restored managed disk was:

```text
vmaz104ubuntu-osdisk-20261006-153823
```

Azure reported:

```text
Location:           denmarkeast
SKU:                Standard_LRS
State:              Unattached
ProvisioningState:  Succeeded
```

The `Unattached` state was useful evidence.

It confirmed that the restore had created an independent disk instead of
silently replacing or attaching it to the source VM.

---

## 35. The Original VM Was Verified After the Restore

After restoring the OS disk, the original VM was checked again.

Azure reported:

```text
Name:               vm-az104-ubuntu
Location:           denmarkeast
ProvisioningState:  Succeeded
PowerState:         VM deallocated
PrivateIP:          10.20.1.4
PublicIP:           None
```

This demonstrated:

```text
Recovery point exists
        +
Restore completed
        +
Restored disk exists
        +
Original VM unchanged
        =
Non-destructive recovery validation
```

---

## 36. Temporary Restore Resources Were Cleaned Up

After validation, the temporary restore resource group was deleted:

```bash
az group delete \
  --name rg-az104-restore-lab \
  --yes \
  --no-wait
```

The first status check showed:

```text
Deleting
```

A later check returned:

```text
ResourceGroupNotFound
```

In this context, `ResourceGroupNotFound` was the expected success condition.

It proved that:

```text
rg-az104-restore-lab
```

had been fully removed.

This is an important troubleshooting principle:

```text
An error-looking response
    !=
Always a failure
```

The result must be interpreted in the context of the operation being verified.

When the desired state is:

```text
resource no longer exists
```

then:

```text
ResourceGroupNotFound
```

is valid evidence of successful cleanup.

---

## 37. Backup and Recovery Require Multiple Layers of Evidence

This exercise demonstrated several distinct states:

```text
Vault exists
    !=
VM protected

VM protected
    !=
Recovery point exists

Recovery point exists
    !=
Restore works

Restore completed
    !=
Restored resource verified
```

The full validation path was:

```text
Register Microsoft.RecoveryServices
        |
        v
Build Bicep
        |
        v
Validate deployment
        |
        v
What-If
        |
        v
Deploy Recovery Services vault
        |
        v
Inspect backup policies
        |
        v
Enable VM protection
        |
        v
Observe IRPending
        |
        v
Trigger on-demand backup
        |
        v
Wait for Backup Completed
        |
        v
Verify recovery point
        |
        v
Restore OS disk to alternate location
        |
        v
Verify restored managed disk
        |
        v
Verify original VM unchanged
        |
        v
Delete temporary restore environment
```

The important engineering lesson is:

```text
Backup configured
        !=
Recovery proven
```

Recovery is only meaningfully validated after restore behaviour is tested.

---

# Current Evidence

The project has now recorded successful validation for:

```text
Bicep compilation
Azure deployment validation
Azure What-If review
Private Linux VM deployment
No-public-IP compute design
NSG configuration
Azure Bastion connectivity
Bastion SSH authentication
Network Watcher connectivity
System-assigned managed identity
Scoped Storage RBAC
Credential-free Blob access
Private Endpoint subnet
Blob Storage Private Endpoint
Private Endpoint approval
Private IP allocation
Private DNS zone
VNet DNS linking
Private Blob name resolution
Managed identity access through Private Link
HTTP 200 Blob API response
ARM partial-deployment investigation
VM deallocation
Microsoft.RecoveryServices provider registration
Recovery Services vault deployment
VM backup policy inspection
VM backup protection
IRPending state investigation
On-demand VM backup
Completed initial backup
Crash-consistent recovery point
Recovery-point inspection
Alternate-location OS disk restore
Restored managed disk verification
Original VM post-restore verification
Temporary restore-resource cleanup
```

Still to explore:

```text
Microsoft Entra users and groups
External users
Self-service password reset
Azure Policy assignment and compliance
Resource locks
Management groups
Budgets and cost alerts
Azure Advisor
Storage SAS
Stored access policies
Storage access keys
Azure Files
Storage redundancy options
AzCopy
Storage Explorer
Blob lifecycle management
Blob versioning
Blob soft delete
VM availability options
VM Scale Sets
Azure Container Instances
Azure App Service
VNet peering
User-defined routes
Application Security Groups
Service Endpoints
Azure Load Balancer
Connection Monitor
Azure Monitor Agent
Data Collection Rules
Azure Monitor alerts
Action Groups
Backup alerts and reporting
Azure Site Recovery
Bicep CI
Pull Request What-If
GitHub OIDC
```

---

# Reflection

The most useful part of this lab has been learning to separate different layers
of infrastructure evidence.

A successful deployment does not automatically prove connectivity.

Connectivity does not prove authentication.

Authentication does not prove authorization.

A Private Endpoint does not prove DNS resolution.

A configured backup does not prove that a recovery point exists.

A recovery point does not prove that a restore works.

The strongest evidence comes from validating each layer independently:

```text
Template compilation
        |
        v
Azure validation
        |
        v
What-If
        |
        v
Resource deployment
        |
        v
Network reachability
        |
        v
Name resolution
        |
        v
Authentication
        |
        v
Authorization
        |
        v
Application-level request
        |
        v
Backup configuration
        |
        v
Recovery point
        |
        v
Restore
        |
        v
Restored-resource verification
```

This made the lab more useful than simply deploying resources.

The project now demonstrates how Azure infrastructure can be reviewed,
troubleshot, secured, backed up, restored, and independently verified.
