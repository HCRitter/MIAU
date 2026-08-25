function Get-MIRoleAssignment {

    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId,

        [string]$Scope
    )

    process {

        $getAzRoleAssignmentSplat = @{
            ErrorAction = 'Stop'
        }

        if ($PrincipalId) {
            $getAzRoleAssignmentSplat.ObjectId = $PrincipalId
        }

        if ($Scope) {
            $getAzRoleAssignmentSplat.Scope = $Scope
        }

        Write-Verbose "Retrieving Azure RBAC role assignments."

        $assignments = @(
            Get-AzRoleAssignment @getAzRoleAssignmentSplat
        )

        foreach ($assignment in $assignments) {

            $scopeType = switch -Regex ($assignment.Scope) {

                '^/subscriptions/[^/]+$' {
                    'Subscription'
                    break
                }

                '^/subscriptions/[^/]+/resourceGroups/[^/]+$' {
                    'ResourceGroup'
                    break
                }

                default {
                    'Resource'
                }
            }

            [PSCustomObject]@{
                PrincipalId        = $assignment.ObjectId
                PrincipalName      = $assignment.DisplayName
                RoleDefinitionName = $assignment.RoleDefinitionName
                RoleDefinitionId   = $assignment.RoleDefinitionId
                Scope              = $assignment.Scope
                ScopeType          = $scopeType
                ObjectType         = $assignment.ObjectType
                AssignmentId       = $assignment.RoleAssignmentId
                SubscriptionId     = $assignment.Scope.Split('/')[2]
            }
        }
    }
}