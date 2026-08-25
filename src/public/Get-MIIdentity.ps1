function Get-MIIdentity {
    [CmdletBinding()]
    param(
        [Parameter(
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [string]$Name,

        [string]$ResourceGroupName,

        [switch]$UserAssigned,

        [switch]$SystemAssigned
    )

    begin {
    }

    process {

        $inventory = Get-MIInventory

        if ($Name) {
            $inventory = $inventory | Where-Object Name -like "*$Name*"
        }

        if ($ResourceGroupName) {
            $inventory = $inventory | Where-Object ResourceGroupName -eq $ResourceGroupName
        }

        if ($UserAssigned) {
            $inventory = $inventory | Where-Object IdentityType -eq 'UserAssigned'
        }

        if ($SystemAssigned) {
            $inventory = $inventory | Where-Object IdentityType -eq 'SystemAssigned'
        }

        $inventory
    }
}