# Learning Notes: Azure Infrastructure Lab

These notes capture what I learned while building and troubleshooting
the AZ-104 Azure infrastructure lab.

## 1. Infrastructure as code needs a review workflow

I followed this deployment sequence:

Build → Validate → What-If → Deploy → Verify

Each stage answers a different question:

| Stage | Question |
|---|---|
| Build | Can Bicep compile the template? |
| Validate | What problems can Azure identify before deployment? |
| What-If | What resource changes does Azure predict? |
| Deploy | Can Azure apply the requested configuration? |
| Verify | Does the resulting environment match my intention? |

A successful build does not prove that deployment will succeed.
Subscription restrictions, resource availability, and runtime dependencies
can still affect the outcome.

## 2. VM availability depends on the deployment context

My initial compute deployment in UK South encountered a VM SKU restriction.

I introduced a separate `computeLocation` parameter and successfully
deployed the compute environment in Denmark East using `Standard_B1s`.

The lesson was to investigate the specific failure before changing the
template. A regional or subscription restriction is different from a Bicep
syntax error.

The successful region and size are historical results from this lab,
not a guarantee of availability for another subscription or future run.

## 3. Separate compute location from existing infrastructure

Changing a shared location parameter could have affected resources that
were already deployed.

Using `computeLocation` let me place the new compute environment in a
different region while preserving the intended location of earlier resources.

I deployed a separate compute network alongside the VM and NIC.

## 4. What-If is an important review step

Before deployment, I reviewed the proposed changes rather than relying
only on successful validation.

The final reviewed preview showed:

- 4 resources to create.
- 0 resources to modify.
- 0 resources to delete.
- 15 resources to ignore.

This helped confirm that the active deployment focused on the new compute
environment.

What-If is a prediction. Warnings, unresolved expressions, and skipped
evaluation still need attention.

## 5. Incremental mode does not mean existing resources cannot change

The deployment used incremental mode.

Resources omitted from the template were retained. However, included
resources could still have their properties updated.

To protect earlier UK South resources, I commented out their module calls
and associated outputs from the active deployment path, then reviewed
What-If again.

This also means those omitted resources were no longer being actively
managed by that deployment.

## 6. Warnings need interpretation

After excluding earlier modules, Bicep reported unused parameters.

These warnings did not stop compilation, but they identified cleanup work:
the template still contained parameters for inactive module calls.

Validation also reported `NestedDeploymentShortCircuited`. This showed
that some nested resources were skipped because a parameter could not be
fully evaluated.

I learned to read diagnostic details rather than treating an overall
`Succeeded` result as proof that every resource had been checked.

## 7. Provisioning success and connectivity are separate

The deployment result confirmed:

- VM: `vm-az104-ubuntu`.
- Region: Denmark East.
- Size: `Standard_B1s`.
- Provisioning state: `Succeeded`.
- Observed private IP: `10.20.1.4`.
- No public IP.

This proved that the VM had been provisioned. It did not prove that I could
SSH to it from my laptop.

## 8. An NSG rule does not create a network path

The compute NSG included an inbound SSH rule with:

- Protocol: TCP.
- Destination port: 22.
- Source: `VirtualNetwork`.
- Priority: 100.

An allow rule alone does not make a private VM reachable from the internet.
A suitable network path and effective security rules are also required.

The `VirtualNetwork` service tag should not be interpreted as only one
local subnet; its scope depends on the network configuration.

Secure remote access remains a follow-up exercise.

## 9. SSH keys have different roles

The VM configuration uses an SSH public key.

The public key is installed on the VM. The corresponding private key stays
on my local machine and must not be committed to the repository.

Configuring key authentication and completing a successful SSH session are
separate milestones.

## 10. Verify power state when controlling costs

After checking the deployment, I deallocated the VM and verified that Azure
reported `VM deallocated`.

I learned to distinguish the VM's provisioning state from its power state.
A resource can remain successfully provisioned while its compute allocation
has been released.

Deallocation does not remove the managed disk or every associated charge.

## 11. Git ignore rules are not retroactive

I added `.gitignore` after the initial lab commit.

The key lesson is that ignore rules affect untracked files; they do not
automatically remove files already tracked by Git or erase earlier commits.

Before publishing, I should review tracked files as well as ignore rules.

## Current evidence

Completed and recorded in the lab conversation:

- Bicep build.
- Azure deployment validation, including diagnostic review.
- What-If review.
- Successful compute deployment.
- VM configuration and power-state checks.
- VM deallocation.

Still to complete or verify:

- Successful secure SSH access.
- Managed identity authorization through RBAC.
- Monitoring and log collection.
- Private connectivity exercises.
- Backup and restore testing.

## Reflection

The most useful part of this lab was troubleshooting a deployment while
protecting existing infrastructure.

I learned to separate compilation, validation, predicted changes, actual
deployment, connectivity, and operational verification. Each provides
different evidence that the environment is working as intended.