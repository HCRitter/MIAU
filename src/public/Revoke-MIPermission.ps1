function Revoke-MIPermission {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('FunctionApp')]
        [string]$Type,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Permission,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalId
    )

    begin {

        $getAzAccessTokenSplat = @{
            ResourceTypeName = 'MSGraph'
        }

        $token = (Get-AzAccessToken @getAzAccessTokenSplat).Token

        if ($token -is [System.Security.SecureString]) {

            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                $token
            )

            try {
                $accessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                    $bstr
                )
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR(
                    $bstr
                )
            }
        }
        else {
            $accessToken = $token
        }

        $headers = @{
            Authorization = "Bearer $accessToken"
        }

        # Microsoft Graph application ID
        $graphAppId = '00000003-0000-0000-c000-000000000000'

        $graphServicePrincipalUri = (
            'https://graph.microsoft.com/v1.0/servicePrincipals' +
            '?$filter=appId eq ''{0}''' -f $graphAppId
        )

        $invokeGraphServicePrincipalSplat = @{
            Method      = 'Get'
            Uri         = $graphServicePrincipalUri
            Headers     = $headers
            ErrorAction = 'Stop'
        }

        Write-Verbose 'Retrieving Microsoft Graph service principal.'

        $graphServicePrincipalResponse = Invoke-RestMethod @invokeGraphServicePrincipalSplat

        $graphServicePrincipals = @(
            $graphServicePrincipalResponse.value
        )

        if ($graphServicePrincipals.Count -ne 1) {
            throw 'Unable to resolve the Microsoft Graph service principal.'
        }

        $graphServicePrincipal = $graphServicePrincipals[0]

        Write-Verbose (
            "Microsoft Graph service principal resolved: " +
            "$($graphServicePrincipal.id)"
        )
    }

    process {

        Write-Verbose "Processing managed identity '$PrincipalId'."

        # Retrieve all app role assignments for the managed identity.
        $appRoleAssignmentsUri = (
            'https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignments' -f
            $PrincipalId
        )

        $invokeAppRoleAssignmentsSplat = @{
            Method      = 'Get'
            Uri         = $appRoleAssignmentsUri
            Headers     = $headers
            ErrorAction = 'Stop'
        }

        $appRoleAssignmentsResponse = Invoke-RestMethod @invokeAppRoleAssignmentsSplat

        $graphAssignments = @(
            $appRoleAssignmentsResponse.value |
                Where-Object {
                    $_.resourceId -eq $graphServicePrincipal.id
                }
        )

        foreach ($currentPermission in $Permission) {

            Write-Verbose "Processing permission '$currentPermission'."

            # Resolve the permission name to its Microsoft Graph app role.
            $appRole = @(
                $graphServicePrincipal.appRoles |
                    Where-Object {
                        $_.value -eq $currentPermission -and
                        $_.allowedMemberTypes -contains 'Application'
                    }
            )

            if ($appRole.Count -eq 0) {
                throw (
                    "Microsoft Graph application permission " +
                    "'$currentPermission' was not found."
                )
            }

            if ($appRole.Count -gt 1) {
                throw (
                    "Multiple Microsoft Graph app roles were found for " +
                    "'$currentPermission'."
                )
            }

            $appRole = $appRole[0]

            Write-Verbose (
                "Resolved '$currentPermission' to AppRoleId " +
                "'$($appRole.id)'."
            )

            # Find the existing assignment.
            $existingAssignment = @(
                $graphAssignments |
                    Where-Object {
                        $_.appRoleId -eq $appRole.id
                    }
            )

            if ($existingAssignment.Count -eq 0) {

                Write-Verbose (
                    "Permission '$currentPermission' is not assigned " +
                    "to '$PrincipalId'."
                )

                [PSCustomObject]@{
                    PrincipalId  = $PrincipalId
                    Permission   = $currentPermission
                    AppRoleId    = $appRole.id
                    ResourceId   = $graphServicePrincipal.id
                    AssignmentId = $null
                    Status       = 'NotAssigned'
                }

                continue
            }

            foreach ($assignment in $existingAssignment) {

                $revokeUri = (
                    'https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignments/{1}' -f
                    $PrincipalId,
                    $assignment.id
                )

                $invokeRevokeSplat = @{
                    Method      = 'Delete'
                    Uri         = $revokeUri
                    Headers     = $headers
                    ErrorAction = 'Stop'
                }

                $operation = (
                    "Revoke Microsoft Graph application permission " +
                    "'$currentPermission'"
                )

                if ($PSCmdlet.ShouldProcess($PrincipalId, $operation)) {

                    Write-Verbose (
                        "Revoking '$currentPermission' from '$PrincipalId'."
                    )

                    Invoke-RestMethod @invokeRevokeSplat

                    [PSCustomObject]@{
                        PrincipalId  = $PrincipalId
                        Permission   = $currentPermission
                        AppRoleId    = $appRole.id
                        ResourceId   = $graphServicePrincipal.id
                        AssignmentId = $assignment.id
                        Status       = 'Revoked'
                    }

                    # Remove the assignment from the local cache so that
                    # duplicate permissions in the same invocation are
                    # handled correctly.
                    $graphAssignments = @(
                        $graphAssignments |
                            Where-Object {
                                $_.id -ne $assignment.id
                            }
                    )
                }
            }
        }
    }
}