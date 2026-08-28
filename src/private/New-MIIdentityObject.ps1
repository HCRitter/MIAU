function New-MIIdentityObject {
    param(
        [string]$Name,
        [string]$IdentityType,
        [string]$PrincipalId,
        [string]$ClientId,
        [string]$TenantId,
        [string]$ResourceName,
        [string]$ResourceType,
        [string]$ResourceId,
        [string]$ResourceKind,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [string]$SubscriptionName,
        [string]$Location,
        [object]$Tags
    )

    [PSCustomObject]@{
        PSTypeName         = 'MI.Identity'

        Name               = $Name
        IdentityType       = $IdentityType

        PrincipalId        = $PrincipalId
        ClientId           = $ClientId
        TenantId           = $TenantId

        ResourceName       = $ResourceName
        ResourceType       = $ResourceType
        ResourceId         = $ResourceId
        ResourceKind       = $ResourceKind

        ResourceGroupName  = $ResourceGroupName

        SubscriptionId     = $SubscriptionId
        SubscriptionName   = $SubscriptionName

        Location           = $Location

        Tags = @(
            if ($null -ne $Tags) {
                $Tags.PSObject.Properties |
                    Where-Object Name -NotLike 'hidden-link*' |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name  = $_.Name
                            Value = $_.Value
                        }
                    }
            }
        )
    }
}