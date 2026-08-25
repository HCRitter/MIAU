function Get-MIInventory {

    [CmdletBinding()]
    param()
    $subscriptions = Get-AzSubscription | Group-Object Id -AsHashTable -AsString
    $query = @'
resources
| where isnotnull(identity)
| project
    name,
    id,
    type,
    kind,
    resourceGroup,
    subscriptionId,
    location,
    tags,
    identity
'@

    $resources = Search-AzGraph -Query $query -First 1000

    foreach ($resource in @($resources)) {

        $common = @{
            ResourceName      = $resource.Name
            ResourceType      = $resource.Type
            ResourceKind      = $resource.kind
            ResourceGroupName = $resource.ResourceGroup
            SubscriptionId    = $resource.SubscriptionId
            SubscriptionName  = $subscriptions[$resource.SubscriptionId].Name
            Location          = $resource.Location
            Tags              = $resource.Tags
        }

        if ($resource.Identity.Type -match 'SystemAssigned') {

            $newMIIdentityObjectSplat = @{
                name = $resource.Name
                IdentityType = 'SystemAssigned'
                PrincipalId = $resource.Identity.PrincipalId
                TenantId = $resource.Identity.TenantId
                ResourceId = $resource.Id
            }

            New-MIIdentityObject @newMIIdentityObjectSplat @common
        }

        foreach ($identity in $resource.Identity.UserAssignedIdentities.PSObject.Properties) {

            New-MIIdentityObject @common @{
                Name         = ($identity.Name -split '/')[-1]
                IdentityType = 'UserAssigned'
                PrincipalId  = $identity.Value.PrincipalId
                ClientId     = $identity.Value.ClientId
                TenantId     = $resource.Identity.TenantId
                ResourceId   = $identity.Name
            }
        }
    }
}