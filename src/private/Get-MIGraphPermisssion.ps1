function Get-MIGraphPermission {

    [CmdletBinding()]
    param(
        $NameFilter
    )

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

    # Microsoft Graph service principal AppId
    $graphAppId = '00000003-0000-0000-c000-000000000000'

    $uri = (
        'https://graph.microsoft.com/v1.0/servicePrincipals' +
        '?$filter=appId eq ''{0}''' -f $graphAppId
    )

    $invokeRestMethodSplat = @{
        Method      = 'Get'
        Uri         = $uri
        Headers     = $headers
        ErrorAction = 'Stop'
    }

    $response = Invoke-RestMethod @invokeRestMethodSplat

    $graphServicePrincipal = @(
        $response.value
    )

    if ($graphServicePrincipal.Count -ne 1) {
        throw 'Unable to resolve the Microsoft Graph service principal.'
    }

    foreach ($appRole in $graphServicePrincipal[0].appRoles | Where-Object {$_.Value -like "$NameFilter*"}) {
        
        if ($appRole.AllowedMemberTypes -notcontains 'Application') {
            continue
        }

        [PSCustomObject]@{
            Name        = $appRole.Value
            Id          = $appRole.Id
            DisplayName = $appRole.DisplayName
            Description = $appRole.Description
        }
    }
}