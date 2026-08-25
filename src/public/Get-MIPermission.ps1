function Get-MIPermission {

    [CmdletBinding()]
    param (
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
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
        else {
            $accessToken = $token
        }

        $headers = @{
            Authorization = "Bearer $accessToken"
        }

        # Microsoft Graph service principal
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

        $graphServicePrincipalResponse = Invoke-RestMethod @invokeGraphServicePrincipalSplat

        $graphServicePrincipals = @(
            $graphServicePrincipalResponse.value
        )

        if ($graphServicePrincipals.Count -ne 1) {
            throw 'Unable to resolve the Microsoft Graph service principal.'
        }

        $graphServicePrincipal = $graphServicePrincipals[0]
    }

    process {

        Write-Verbose "Retrieving permissions for '$PrincipalId'."

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

        $response = Invoke-RestMethod @invokeAppRoleAssignmentsSplat

        $assignments = @(
            $response.value |
                Where-Object {
                    $_.resourceId -eq $graphServicePrincipal.id
                }
        )

        foreach ($assignment in $assignments) {

            $appRole = @(
                $graphServicePrincipal.appRoles |
                    Where-Object {
                        $_.id -eq $assignment.appRoleId
                    }
            )

            if ($appRole.Count -eq 0) {
                Write-Warning (
                    "Unable to resolve AppRoleId '$($assignment.appRoleId)' " +
                    "for principal '$PrincipalId'."
                )

                continue
            }

            $appRole = $appRole[0]

            [PSCustomObject]@{
                PrincipalId  = $PrincipalId
                Permission   = $appRole.Value
                AppRoleId    = $appRole.Id
                DisplayName  = $appRole.DisplayName
                Description  = $appRole.Description
                ResourceId   = $assignment.ResourceId
                AssignmentId = $assignment.Id
            }
        }
    }
}