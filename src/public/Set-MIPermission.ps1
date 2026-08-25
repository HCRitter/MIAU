function Set-MIPermission {

    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('FunctionApp')]
        [string]$Type,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Permission,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId
    )

    process {

        Write-Verbose "Retrieving current permissions for '$PrincipalId'."

        $getMIPermissionSplat = @{
            PrincipalId = $PrincipalId
        }

        $currentPermissions = @(
            Get-MIPermission @getMIPermissionSplat
        )

        $currentPermissionNames = @(
            $currentPermissions.Permission
        )

        $desiredPermissionNames = @(
            $Permission |
                Sort-Object -Unique
        )

        # Permissions that need to be granted.
        $permissionsToGrant = @(
            $desiredPermissionNames |
                Where-Object {
                    $_ -notin $currentPermissionNames
                }
        )

        # Permissions that need to be revoked.
        $permissionsToRevoke = @(
            $currentPermissionNames |
                Where-Object {
                    $_ -notin $desiredPermissionNames
                }
        )

        Write-Verbose (
            "Permissions to grant: $($permissionsToGrant -join ', ')"
        )

        Write-Verbose (
            "Permissions to revoke: $($permissionsToRevoke -join ', ')"
        )

        # Grant missing permissions.
        if ($permissionsToGrant.Count -gt 0) {

            $grantMIPermissionSplat = @{
                Type        = $Type
                Permission  = $permissionsToGrant
                PrincipalId = $PrincipalId
            }

            if ($PSCmdlet.ShouldProcess(
                $PrincipalId,
                "Grant permissions: $($permissionsToGrant -join ', ')"
            )) {

                Grant-MIPermission @grantMIPermissionSplat
            }
        }

        # Revoke permissions which are not part of the desired state.
        if ($permissionsToRevoke.Count -gt 0) {

            $revokeMIPermissionSplat = @{
                Type        = $Type
                Permission  = $permissionsToRevoke
                PrincipalId = $PrincipalId
            }

            if ($PSCmdlet.ShouldProcess(
                $PrincipalId,
                "Revoke permissions: $($permissionsToRevoke -join ', ')"
            )) {

                Revoke-MIPermission @revokeMIPermissionSplat
            }
        }

        # Nothing to change.
        if (
            $permissionsToGrant.Count -eq 0 -and
            $permissionsToRevoke.Count -eq 0
        ) {

            Write-Verbose (
                "Permissions for '$PrincipalId' already match the desired state."
            )

            foreach ($permissionName in $desiredPermissionNames) {

                $existingPermission = @(
                    $currentPermissions |
                        Where-Object {
                            $_.Permission -eq $permissionName
                        }
                )

                foreach ($permission in $existingPermission) {

                    [PSCustomObject]@{
                        PrincipalId  = $permission.PrincipalId
                        Permission   = $permission.Permission
                        AppRoleId    = $permission.AppRoleId
                        ResourceId   = $permission.ResourceId
                        AssignmentId = $permission.AssignmentId
                        Status       = 'Unchanged'
                    }
                }
            }
        }
    }
}