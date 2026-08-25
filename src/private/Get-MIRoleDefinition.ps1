function Get-MIRoleDefinition {

    [CmdletBinding()]
    param ()

    if ($null -eq $script:MIRoleDefinitionCache) {

        Write-Verbose 'Loading Azure RBAC role definitions.'

        $script:MIRoleDefinitionCache = @(
            Get-AzRoleDefinition -ErrorAction Stop |
                ForEach-Object {

                    [PSCustomObject]@{
                        Name        = $_.Name
                        Id          = $_.Id
                        Description = $_.Description
                        Type        = $_.RoleType
                        IsCustom    = $_.IsCustom
                    }
                }
        )
    }

    $script:MIRoleDefinitionCache
}