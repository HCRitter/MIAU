#[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
function Grant-MIPermission {

    [CmdletBinding(SupportsShouldProcess)]
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

        # Get Microsoft Graph access token
        $getAzAccessTokenSplat = @{
            ResourceTypeName = 'MSGraph'
        }

        $token = (Get-AzAccessToken @getAzAccessTokenSplat).Token

        # Az.Accounts can return either a String or SecureString
        # depending on the module version.
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
            'Content-Type' = 'application/json'
        }

        # Microsoft Graph application ID
        $graphAppId = '00000003-0000-0000-c000-000000000000'

        # Resolve the Microsoft Graph service principal.
        #
        # Using the format operator avoids needing a backtick to escape
        # $filter in the URL.
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

        # Retrieve existing app role assignments for THIS principal.
        #
        # This must be in process because PrincipalId is populated by
        # pipeline binding at process time.
        $existingAssignmentsUri = (
            'https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignments' -f
            $PrincipalId
        )

        $invokeExistingAssignmentsSplat = @{
            Method      = 'Get'
            Uri         = $existingAssignmentsUri
            Headers     = $headers
            ErrorAction = 'Stop'
        }

        Write-Verbose (
            "Retrieving existing Graph permissions for '$PrincipalId'."
        )

        $existingAssignmentsResponse = Invoke-RestMethod @invokeExistingAssignmentsSplat

        $existingAssignments = @(
            $existingAssignmentsResponse.value |
                Where-Object {
                    $_.resourceId -eq $graphServicePrincipal.id
                }
        )

        foreach ($currentPermission in $Permission) {

            Write-Verbose "Processing permission '$currentPermission'."

            # Resolve the permission name to the Microsoft Graph app role.
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

            # Check whether this permission is already assigned.
            $existingAssignment = @(
                $existingAssignments |
                    Where-Object {
                        $_.appRoleId -eq $appRole.id
                    }
            )

            if ($existingAssignment.Count -gt 0) {

                Write-Verbose (
                    "Permission '$currentPermission' is already assigned " +
                    "to '$PrincipalId'."
                )

                [PSCustomObject]@{
                    PrincipalId  = $PrincipalId
                    Permission   = $currentPermission
                    AppRoleId    = $appRole.id
                    ResourceId   = $graphServicePrincipal.id
                    AssignmentId = $existingAssignment[0].id
                    Status       = 'AlreadyGranted'
                }

                continue
            }

            $body = @{
                principalId = $PrincipalId
                resourceId  = $graphServicePrincipal.id
                appRoleId   = $appRole.id
            } | ConvertTo-Json -Compress

            $assignmentUri = (
                'https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignments' -f
                $PrincipalId
            )

            $invokeAssignmentSplat = @{
                Method      = 'Post'
                Uri         = $assignmentUri
                Headers     = $headers
                Body        = $body
                ErrorAction = 'Stop'
            }

            $operation = (
                "Grant Microsoft Graph application permission " +
                "'$currentPermission'"
            )

            if ($PSCmdlet.ShouldProcess($PrincipalId, $operation)) {

                Write-Verbose (
                    "Granting '$currentPermission' to '$PrincipalId'."
                )

                $result = Invoke-RestMethod @invokeAssignmentSplat

                [PSCustomObject]@{
                    PrincipalId  = $PrincipalId
                    Permission   = $currentPermission
                    AppRoleId    = $appRole.id
                    ResourceId   = $graphServicePrincipal.id
                    AssignmentId = $result.id
                    Status       = 'Granted'
                }

                # Keep the local cache up to date.
                $existingAssignments += $result
            }
        }
    }
}