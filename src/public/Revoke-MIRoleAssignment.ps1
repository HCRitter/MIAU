function Revoke-MIRoleAssignment {

    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High'
    )]
    param (

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleDefinitionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Scope
    )

    process {

        $getAzRoleAssignmentSplat = @{
            ObjectId           = $PrincipalId
            RoleDefinitionName = $RoleDefinitionName
            Scope              = $Scope
            ErrorAction        = 'SilentlyContinue'
        }

        $assignments = @(
            Get-AzRoleAssignment @getAzRoleAssignmentSplat
        )

        if (-not $assignments) {

            [PSCustomObject]@{
                PrincipalId        = $PrincipalId
                PrincipalName      = $null
                RoleDefinitionName = $RoleDefinitionName
                RoleDefinitionId   = $null
                Scope              = $Scope
                AssignmentId       = $null
                Status             = 'NotFound'
            }

            return
        }

        foreach ($assignment in $assignments) {

            $operation = @(
                "Revoke role '$($assignment.RoleDefinitionName)'"
                "from '$($assignment.ObjectId)'"
                "at scope '$($assignment.Scope)'"
            ) -join ' '

            if (
                -not $PSCmdlet.ShouldProcess(
                    $assignment.ObjectId,
                    $operation
                )
            ) {

                [PSCustomObject]@{
                    PrincipalId        = $assignment.ObjectId
                    PrincipalName      = $assignment.DisplayName
                    RoleDefinitionName = $assignment.RoleDefinitionName
                    RoleDefinitionId   = $assignment.RoleDefinitionId
                    Scope              = $assignment.Scope
                    AssignmentId       = $assignment.RoleAssignmentId
                    Status             = 'WhatIf'
                }

                continue
            }

            $removeAzRoleAssignmentSplat = @{
                ObjectId           = $assignment.ObjectId
                RoleDefinitionName = $assignment.RoleDefinitionName
                Scope              = $assignment.Scope
                ErrorAction        = 'Stop'
            }

            Remove-AzRoleAssignment @removeAzRoleAssignmentSplat

            [PSCustomObject]@{
                PrincipalId        = $assignment.ObjectId
                PrincipalName      = $assignment.DisplayName
                RoleDefinitionName = $assignment.RoleDefinitionName
                RoleDefinitionId   = $assignment.RoleDefinitionId
                Scope              = $assignment.Scope
                AssignmentId       = $assignment.RoleAssignmentId
                Status             = 'Revoked'
            }
        }
    }
}