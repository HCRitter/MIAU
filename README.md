# Managed Identity Automation Utilities

A PowerShell module for making day-to-day **Managed Identity operations in Azure a little easier**.

The Managed Identity Automation Utilities brings together Azure Resource Graph, Azure RBAC, and Microsoft Graph application permissions into a set of PowerShell commands that are designed to work naturally with the pipeline.

Whether you're looking for managed identities across a tenant, checking their permissions, or bringing those permissions back to a desired state, the goal is to make common identity operations simple, scriptable, and repeatable.

> **Note:** This README reflects the functionality currently implemented in the codebase.

## What You Can Do Today

With the current version you can:

* Build a tenant-wide inventory of resources that use managed identities, including system-assigned and user-assigned identities.
* Find and filter identities by name, resource group, and identity type.
* Read Microsoft Graph application permissions assigned to managed identities.
* Grant and revoke Microsoft Graph application permissions.
* Reconcile Graph application permissions to a desired state.
* Read, grant, and revoke Azure RBAC role assignments.
* Combine commands in pipeline-friendly workflows.

The idea is to keep things familiar for PowerShell users:

```powershell
Get-MIIdentity -Name func |
    Get-MIPermission
```

or:

```powershell
Get-MIIdentity -Name func-api-prod |
    Set-MIPermission -Type FunctionApp -Permission @(
        'User.Read.All'
        'Group.Read.All'
    )
```

## Where Things Stand

Managed Identity Automation Utilities is still growing, and there are a few areas that aren't implemented yet.

Currently:

* There are no advanced governance or reporting features such as orphan detection, over-privilege analysis, dashboards, or exports.
* Identity creation and deletion aren't part of the module yet.
* Inventory queries currently request up to 1000 resources per execution and don't implement pagination.
* Permission commands expose a `-Type` parameter, but currently only `FunctionApp` is supported and the value doesn't yet change the underlying behavior.

These are known gaps rather than hidden limitations, and they're good candidates for future improvements.

## Implemented Command Surface

### Identity

* `Get-MIInventory`
* `Get-MIIdentity`

### Microsoft Graph Application Permissions

* `Get-MIPermission`
* `Grant-MIPermission`
* `Set-MIPermission` — reconcile permissions by granting missing permissions and revoking unwanted ones.
* `Revoke-MIPermission`

### Azure RBAC

* `Get-MIRoleAssignment`
* `Grant-MIRoleAssignment`
* `Revoke-MIRoleAssignment`

### Internal Helpers

These commands support the implementation but aren't intended to be the primary workflow:

* `Get-MIGraphPermission` — retrieves available Microsoft Graph application roles.
* `Get-MIRoleDefinition`
* `Get-MIRoleScope`

## Prerequisites

The module currently targets **PowerShell 7+**.

You also need the following Az modules available:

* `Az.Accounts`
* `Az.Resources`
* `Az.ResourceGraph`

Start by connecting to Azure:

```powershell
Connect-AzAccount
```

Your account also needs sufficient permissions to read and modify the relevant Azure RBAC and Microsoft Graph application role assignments.

## Install / Import

From the repository root:

```powershell
Import-Module ./src/MIAU.psm1 -Force
```

## Quick Start

### 1. Take a look at your managed identities

Start with an inventory of identities across your environment:

```powershell
Get-MIInventory
```

### 2. Find specific identities

You can filter the inventory using the identity and resource properties:

```powershell
Get-MIIdentity -Name func

Get-MIIdentity -ResourceGroupName rg-apps-prod

Get-MIIdentity -SystemAssigned

Get-MIIdentity -UserAssigned
```

### 3. Check Microsoft Graph permissions

Because the commands are pipeline-friendly, you can go directly from identities to their permissions:

```powershell
Get-MIIdentity -Name func |
    Get-MIPermission
```

### 4. Grant a Graph application permission

For example:

```powershell
$grantMIPermissionSplat = @{
    Type = 'FunctionApp'
    Permission = 'User.Read.All'
}

Get-MIIdentity -Name func-api-prod |
    Grant-MIPermission @grantMIPermissionSplat
```

### 5. Reconcile permissions to a desired state

`Set-MIPermission` is intended for declarative-style workflows.

Give it the permissions you want, and it will grant missing permissions and revoke permissions that aren't part of the desired state:

```powershell
$setMIPermissionSplat = @{
    Type = 'FunctionApp'
    Permission = @(
        'User.Read.All'
        'Group.Read.All'
    )
}

Get-MIIdentity -Name func-api-prod |
    Set-MIPermission @setMIPermissionSplat
```

This also works naturally with multiple identities:

```powershell
$setMIPermissionSplat = @{
    Type = 'FunctionApp'
    Permission = @(
        'User.Read.All'
        'Group.Read.All'
    )
}

Get-MIIdentity -Name func |
    Set-MIPermission @setMIPermissionSplat
```

### 6. Read and manage RBAC assignments

Read existing assignments:

```powershell
Get-MIIdentity -Name func-api-prod |
    Get-MIRoleAssignment
```

Grant a role:

```powershell
$grantMIRoleAssignmentSplat = @{
    RoleDefinitionName = 'Reader'
    Scope = '/subscriptions/<subId>'
}

Get-MIIdentity -Name func-api-prod |
    Grant-MIRoleAssignment @grantMIRoleAssignmentSplat
```

Revoke a role:

```powershell
$revokeMIRoleAssignmentSplat = @{
    RoleDefinitionName = 'Reader'
    Scope = '/subscriptions/<subId>'
}

Get-MIIdentity -Name func-api-prod |
    Revoke-MIRoleAssignment @revokeMIRoleAssignmentSplat
```

## A Note About the Output

Identity commands return a custom PowerShell object with:

```text
PSTypeName = MI.Identity
```

The object contains the information needed to continue working with the identity through the pipeline.

### Identity information

* `Name`
* `IdentityType`
* `PrincipalId`
* `TenantId`

### Resource information

* `ResourceName`
* `ResourceType`
* `ResourceId`
* `ResourceKind`
* `ResourceGroupName`

### Subscription and location

* `SubscriptionId`
* `SubscriptionName`
* `Location`

### Tags

Resource tags are normalized into simple name/value objects, making them easier to consume from PowerShell:

```text
Name         Value
----         -----
AZFun        Second
Environment  Production
```

## Safe by Default

Commands that modify permissions and role assignments support PowerShell's standard safety features:

```powershell
-WhatIf
-Confirm
```

So before making changes, you can preview what would happen:

```powershell
$setMIPermissionSplat = @{
    Type = 'FunctionApp'
    Permission = 'User.Read.All'
    WhatIf = $true
}

Get-MIIdentity -Name func |
    Set-MIPermission @setMIPermissionSplat
```

This is particularly useful when working against multiple identities through the pipeline.

## What's Next?

There are plenty of directions this project can take.

Some of the obvious next steps include:

* Implementing `Get-MIOverview`.
* Improving inventory scalability with paging.
* Adding richer governance and reporting capabilities.
* Detecting orphaned or potentially over-privileged identities.
* Adding automated tests and command help.
* Adding an explicit module manifest and dependency declarations.
* Cleaning up command/file naming inconsistencies.

The intention is to grow Managed Identity Automation Utilities incrementally while keeping the commands useful for real-world PowerShell automation.

## Contributing

Issues and pull requests are welcome.

When reporting an issue, it helps to include:

* Expected behavior
* Actual behavior
* Reproduction command(s)
* Redacted sample output, where possible

The more context you can provide, the easier it is to reproduce and fix an issue.

## Disclaimer

This is an independent project and is **not affiliated with or endorsed by Microsoft**.
This README and parts of the source code were created with the help of AI.
