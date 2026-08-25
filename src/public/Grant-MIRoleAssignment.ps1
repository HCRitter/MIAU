function Grant-MIRoleAssignment {

    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Medium'
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

        $getAzRoleDefinitionSplat = @{
            Name        = $RoleDefinitionName
            ErrorAction = 'Stop'
            WarningAction = 'SilentlyContinue'
        }

        $roleDefinition = Get-AzRoleDefinition @getAzRoleDefinitionSplat

        if (-not $roleDefinition) {

            throw "Azure RBAC role '$RoleDefinitionName' was not found."
        }

        $getAzRoleAssignmentSplat = @{
            ObjectId           = $PrincipalId
            RoleDefinitionName = $roleDefinition.Name
            Scope              = $Scope
            ErrorAction        = 'SilentlyContinue'
        }

        $existingAssignments = @(
            Get-AzRoleAssignment @getAzRoleAssignmentSplat
        )

        if ($existingAssignments.Count -gt 0) {

            foreach ($assignment in $existingAssignments) {

                [PSCustomObject]@{
                    PrincipalId        = $assignment.ObjectId
                    PrincipalName      = $assignment.DisplayName
                    RoleDefinitionName = $assignment.RoleDefinitionName
                    RoleDefinitionId   = $assignment.RoleDefinitionId
                    Scope              = $assignment.Scope
                    AssignmentId       = $assignment.RoleAssignmentId
                    Status             = 'AlreadyExists'
                }
            }

            return
        }

        $operation = "Grant role '$($roleDefinition.Name)' at scope '$Scope'"

        if (
            -not $PSCmdlet.ShouldProcess(
                $PrincipalId,
                $operation
            )
        ) {

            [PSCustomObject]@{
                PrincipalId        = $PrincipalId
                PrincipalName      = $null
                RoleDefinitionName = $roleDefinition.Name
                RoleDefinitionId   = $roleDefinition.Id
                Scope              = $Scope
                AssignmentId       = $null
                Status             = 'WhatIf'
            }

            return
        }

        $newAzRoleAssignmentSplat = @{
            ObjectId           = $PrincipalId
            RoleDefinitionName = $roleDefinition.Name
            Scope              = $Scope
            ErrorAction        = 'Stop'
        }

        $assignment = New-AzRoleAssignment @newAzRoleAssignmentSplat

        [PSCustomObject]@{
            PrincipalId        = $assignment.ObjectId
            PrincipalName      = $assignment.DisplayName
            RoleDefinitionName = $assignment.RoleDefinitionName
            RoleDefinitionId   = $assignment.RoleDefinitionId
            Scope              = $assignment.Scope
            AssignmentId       = $assignment.RoleAssignmentId
            Status             = 'Granted'
        }
    }
}