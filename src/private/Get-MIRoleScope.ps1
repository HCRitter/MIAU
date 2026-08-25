function Get-MIRoleScope {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleDefinitionName
    )

    $getAzRoleDefinitionSplat = @{
        Name        = $RoleDefinitionName
        ErrorAction = 'Stop'
        WarningAction = 'SilentlyContinue'
    }

    $role = Get-AzRoleDefinition @getAzRoleDefinitionSplat

    if (-not $role) {

        throw (
            "Azure RBAC role '$RoleDefinitionName' was not found."
        )
    }

    $actions = @(
        foreach ($permission in @($role.Permissions)) {

            @($permission.Actions)
            @($permission.DataActions)
        }
    )

    if ($actions.Count -eq 0) {

        $actions = @(
            $role.Actions
            $role.DataActions
        )
    }

    $resourceTypes = @(
        $actions |
            Where-Object {
                $_ -and
                $_ -match '^Microsoft\.[^/]+/'
            } |
            ForEach-Object {

                $parts = $_ -split '/'

                if ($parts.Count -ge 2) {

                    "$($parts[0])/$($parts[1])"
                }
            } |
            Sort-Object -Unique
    )

    foreach ($resourceType in $resourceTypes) {

        $getAzResourceSplat = @{
            ResourceType = $resourceType
            ErrorAction  = 'SilentlyContinue'
        }

        foreach ($resource in @(Get-AzResource @getAzResourceSplat)) {

            [PSCustomObject]@{
                RoleDefinitionName = $role.Name
                RoleDefinitionId   = $role.Id
                ResourceName       = $resource.Name
                ResourceType       = $resource.ResourceType
                ResourceId         = $resource.ResourceId
                Location           = $resource.Location
            }
        }
    }
}