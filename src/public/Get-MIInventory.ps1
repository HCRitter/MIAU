function Get-MIInventory {

    [CmdletBinding()]
    param()
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
| join kind=leftouter (
    resourcecontainers
    | where type == 'microsoft.resources/subscriptions'
    | project subscriptionId, subscriptionName = name
) on subscriptionId
'@

    $resources = Search-AzGraph -Query $query -First 1000

    foreach ($resource in @($resources)) {

        $common = @{
            ResourceName      = $resource.Name
            ResourceType      = $resource.Type
            ResourceKind      = $resource.kind
            ResourceGroupName = $resource.ResourceGroup
            SubscriptionId    = $resource.SubscriptionId
            SubscriptionName  = $resource.SubscriptionName
            Location          = $resource.Location
            Tags              = $resource.Tags
            TenantId          = $resource.Identity.TenantId
        }

        $identities = @(
            if ($resource.Identity.Type -match 'SystemAssigned') {
                @{
                    Name         = $resource.Name
                    IdentityType = 'SystemAssigned'
                    PrincipalId  = $resource.Identity.PrincipalId
                    ResourceId   = $resource.Id
                }
            }

            foreach ($identity in $resource.Identity.UserAssignedIdentities.PSObject.Properties) {
                @{
                    Name         = ($identity.Name -split '/')[-1]
                    IdentityType = 'UserAssigned'
                    PrincipalId  = $identity.Value.PrincipalId
                    ClientId     = $identity.Value.ClientId
                    ResourceId   = $identity.Name
                }
            }
        )

        foreach ($identity in $identities) {
            New-MIIdentityObject @common @identity
        }
    }
}