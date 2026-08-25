# =============================================================================
# MILF Argument Completers
# =============================================================================


# =============================================================================
# Helper: Get pipeline objects for argument completion
# =============================================================================

function Get-MICompletionPipelineInput {

    param (
        [Parameter(Mandatory)]
        $CommandAst
    )

    $pipelineAst = $CommandAst.FindParent(
        {
            param ($ast)

            $ast -is [System.Management.Automation.Language.PipelineAst]
        },
        $true
    )

    if (-not $pipelineAst) {
        return
    }

    $commandElements = @(
        $pipelineAst.PipelineElements
    )

    if ($commandElements.Count -lt 2) {
        return
    }

    $currentCommand = $pipelineAst.PipelineElements[-1]

    if ($currentCommand -ne $CommandAst.Parent) {
        return
    }

    $upstreamCommand = $pipelineAst.PipelineElements[0]

    if (
        $upstreamCommand -isnot
        [System.Management.Automation.Language.CommandAst]
    ) {
        return
    }

    $commandName = $upstreamCommand.GetCommandName()

    if ([string]::IsNullOrWhiteSpace($commandName)) {
        return
    }

    try {

        & $commandName
    }
    catch {

        return
    }
}


# =============================================================================
# Graph Permissions
# =============================================================================

$permissionCommands = @(
    Get-Command -Module $ExecutionContext.SessionState.Module.Name |
        Where-Object {
            $_.CommandType -eq 'Function' -and
            $_.Parameters.ContainsKey('Permission')
        }
)

$registerPermissionCompleterSplat = @{
    ParameterName = 'Permission'
    ScriptBlock   = {
        param (
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )

        if (-not $script:MIGraphPermissionCache) {

            $script:MIGraphPermissionCache = @(
                Get-MIGraphPermission
            )
        }

        foreach ($permission in $script:MIGraphPermissionCache) {

            if ($permission.Name -like "$WordToComplete*") {

                $completionResultSplat = @{
                    CompletionText = $permission.Name
                    ListItemText   = $permission.Name
                    ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    ToolTip        = $permission.Description
                }

                [System.Management.Automation.CompletionResult]::new(
                    $completionResultSplat.CompletionText,
                    $completionResultSplat.ListItemText,
                    $completionResultSplat.ResultType,
                    $completionResultSplat.ToolTip
                )
            }
        }
    }
}

foreach ($command in $permissionCommands) {

    $registerPermissionCompleterSplat.CommandName = $command.Name

    Register-ArgumentCompleter @registerPermissionCompleterSplat
}


# =============================================================================
# Generic RoleDefinitionName
# =============================================================================

$roleDefinitionCommands = @(
    Get-Command -Module $ExecutionContext.SessionState.Module.Name |
        Where-Object {
            $_.CommandType -eq 'Function' -and
            $_.Parameters.ContainsKey('RoleDefinitionName') -and
            $_.Name -ne 'Revoke-MIRoleAssignment'
        }
)

$registerRoleDefinitionCompleterSplat = @{
    ParameterName = 'RoleDefinitionName'
    ScriptBlock   = {
        param (
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )

        if (-not $script:MIRoleDefinitionCache) {

            $script:MIRoleDefinitionCache = @(
                Get-MIRoleDefinition
            )
        }

        foreach ($role in $script:MIRoleDefinitionCache) {

            if ($role.Name -like "$WordToComplete*") {

                $completionResultSplat = @{
                    CompletionText = $role.Name
                    ListItemText   = $role.Name
                    ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    ToolTip        = $role.Description
                }

                [System.Management.Automation.CompletionResult]::new(
                    $completionResultSplat.CompletionText,
                    $completionResultSplat.ListItemText,
                    $completionResultSplat.ResultType,
                    $completionResultSplat.ToolTip
                )
            }
        }
    }
}

foreach ($command in $roleDefinitionCommands) {

    $registerRoleDefinitionCompleterSplat.CommandName = $command.Name

    Register-ArgumentCompleter @registerRoleDefinitionCompleterSplat
}


# =============================================================================
# Generic Scope
# =============================================================================

$roleAssignmentCommands = @(
    Get-Command -Module $ExecutionContext.SessionState.Module.Name |
        Where-Object {
            $_.CommandType -eq 'Function' -and
            $_.Parameters.ContainsKey('RoleDefinitionName') -and
            $_.Parameters.ContainsKey('Scope') -and
            $_.Name -ne 'Revoke-MIRoleAssignment'
        }
)

$registerScopeCompleterSplat = @{
    ParameterName = 'Scope'
    ScriptBlock   = {
        param (
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )

        $roleDefinitionName = $FakeBoundParameters['RoleDefinitionName']

        if (
            [string]::IsNullOrWhiteSpace(
                $roleDefinitionName
            )
        ) {
            return
        }

        if (-not $script:MIRoleScopeCache) {
            $script:MIRoleScopeCache = @{}
        }

        $cacheKey = $roleDefinitionName.ToLowerInvariant()

        if (-not $script:MIRoleScopeCache.ContainsKey($cacheKey)) {

            try {

                $getMIRoleScopeSplat = @{
                    RoleDefinitionName = $roleDefinitionName
                }

                $script:MIRoleScopeCache[$cacheKey] = @(
                    Get-MIRoleScope @getMIRoleScopeSplat
                )
            }
            catch {

                return
            }
        }

        foreach ($scope in $script:MIRoleScopeCache[$cacheKey]) {

            if (
                $scope.ResourceId -like "$WordToComplete*" -or
                $scope.ResourceName -like "$WordToComplete*"
            ) {

                $completionResultSplat = @{
                    CompletionText = $scope.ResourceId
                    ListItemText   = $scope.ResourceName
                    ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    ToolTip        = $scope.ResourceType
                }

                [System.Management.Automation.CompletionResult]::new(
                    $completionResultSplat.CompletionText,
                    $completionResultSplat.ListItemText,
                    $completionResultSplat.ResultType,
                    $completionResultSplat.ToolTip
                )
            }
        }
    }
}

foreach ($command in $roleAssignmentCommands) {

    $registerScopeCompleterSplat.CommandName = $command.Name

    Register-ArgumentCompleter @registerScopeCompleterSplat
}


# =============================================================================
# Revoke-MIRoleAssignment
#
# Supports:
#
#     Revoke-MIRoleAssignment `
#         -PrincipalId $id `
#         -RoleDefinitionName <TAB>
#
# and:
#
#     Get-MIInventory |
#         Revoke-MIRoleAssignment `
#             -RoleDefinitionName <TAB>
# =============================================================================

$registerRevokeRoleDefinitionCompleterSplat = @{
    CommandName  = 'Revoke-MIRoleAssignment'
    ParameterName = 'RoleDefinitionName'
    ScriptBlock   = {
        param (
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )

        $principalIds = @()

        if (
            $FakeBoundParameters.ContainsKey('PrincipalId') -and
            -not [string]::IsNullOrWhiteSpace(
                $FakeBoundParameters['PrincipalId']
            )
        ) {

            $principalIds = @(
                $FakeBoundParameters['PrincipalId']
            )
        }
        else {

            $pipelineInput = @(
                Get-MICompletionPipelineInput `
                    -CommandAst $CommandAst
            )

            $principalIds = @(
                $pipelineInput |
                    Where-Object {
                        $_.PSObject.Properties.Name -contains 'PrincipalId'
                    } |
                    Select-Object -ExpandProperty PrincipalId -Unique
            )
        }

        if (-not $principalIds) {
            return
        }

        if (-not $script:MIRoleAssignmentCache) {
            $script:MIRoleAssignmentCache = @{}
        }

        $assignments = foreach ($principalId in $principalIds) {

            $cacheKey = $principalId.ToLowerInvariant()

            if (-not $script:MIRoleAssignmentCache.ContainsKey($cacheKey)) {

                try {

                    $getMIRoleAssignmentSplat = @{
                        PrincipalId = $principalId
                    }

                    $script:MIRoleAssignmentCache[$cacheKey] = @(
                        Get-MIRoleAssignment @getMIRoleAssignmentSplat
                    )
                }
                catch {

                    continue
                }
            }

            $script:MIRoleAssignmentCache[$cacheKey]
        }

        $roles = @(
            $assignments |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_.RoleDefinitionName
                    )
                } |
                Select-Object -ExpandProperty RoleDefinitionName -Unique
        )

        foreach ($role in $roles) {

            if ($role -like "$WordToComplete*") {

                $completionResultSplat = @{
                    CompletionText = $role
                    ListItemText   = $role
                    ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    ToolTip        = 'Role assigned to managed identity'
                }

                [System.Management.Automation.CompletionResult]::new(
                    $completionResultSplat.CompletionText,
                    $completionResultSplat.ListItemText,
                    $completionResultSplat.ResultType,
                    $completionResultSplat.ToolTip
                )
            }
        }
    }
}

Register-ArgumentCompleter @registerRevokeRoleDefinitionCompleterSplat


# =============================================================================
# Revoke-MIRoleAssignment - Scope
# =============================================================================

$registerRevokeScopeCompleterSplat = @{
    CommandName  = 'Revoke-MIRoleAssignment'
    ParameterName = 'Scope'
    ScriptBlock   = {
        param (
            $CommandName,
            $ParameterName,
            $WordToComplete,
            $CommandAst,
            $FakeBoundParameters
        )

        $principalIds = @()

        if (
            $FakeBoundParameters.ContainsKey('PrincipalId') -and
            -not [string]::IsNullOrWhiteSpace(
                $FakeBoundParameters['PrincipalId']
            )
        ) {

            $principalIds = @(
                $FakeBoundParameters['PrincipalId']
            )
        }
        else {

            $pipelineInput = @(
                Get-MICompletionPipelineInput `
                    -CommandAst $CommandAst
            )

            $principalIds = @(
                $pipelineInput |
                    Where-Object {
                        $_.PSObject.Properties.Name -contains 'PrincipalId'
                    } |
                    Select-Object -ExpandProperty PrincipalId -Unique
            )
        }

        $roleDefinitionName = $FakeBoundParameters['RoleDefinitionName']

        if (
            [string]::IsNullOrWhiteSpace(
                $roleDefinitionName
            )
        ) {
            return
        }

        if (-not $principalIds) {
            return
        }

        if (-not $script:MIRoleAssignmentCache) {
            $script:MIRoleAssignmentCache = @{}
        }

        $assignments = foreach ($principalId in $principalIds) {

            $cacheKey = $principalId.ToLowerInvariant()

            if (-not $script:MIRoleAssignmentCache.ContainsKey($cacheKey)) {

                try {

                    $getMIRoleAssignmentSplat = @{
                        PrincipalId = $principalId
                    }

                    $script:MIRoleAssignmentCache[$cacheKey] = @(
                        Get-MIRoleAssignment @getMIRoleAssignmentSplat
                    )
                }
                catch {

                    continue
                }
            }

            $script:MIRoleAssignmentCache[$cacheKey]
        }

        $assignments = @(
            $assignments |
                Where-Object {
                    $_.RoleDefinitionName -eq $roleDefinitionName
                }
        )

        foreach ($assignment in $assignments) {

            if (
                $assignment.Scope -like "$WordToComplete*"
            ) {

                $completionResultSplat = @{
                    CompletionText = $assignment.Scope
                    ListItemText   = $assignment.Scope
                    ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    ToolTip        = 'Scope assigned to managed identity'
                }

                [System.Management.Automation.CompletionResult]::new(
                    $completionResultSplat.CompletionText,
                    $completionResultSplat.ListItemText,
                    $completionResultSplat.ResultType,
                    $completionResultSplat.ToolTip
                )
            }
        }
    }
}

Register-ArgumentCompleter @registerRevokeScopeCompleterSplat