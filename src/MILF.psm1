# =============================================================================
# MILF - Managed Identity Lifecycle Framework
# =============================================================================

$privatePath = Join-Path $PSScriptRoot 'Private'
$miscPath    = Join-Path $PSScriptRoot 'Misc'
$publicPath  = Join-Path $PSScriptRoot 'Public'


# =============================================================================
# Private
# =============================================================================

Get-ChildItem -Path $privatePath -Filter '*.ps1' -File |
    Where-Object {
        $_.Name -ne 'Register-MIArgumentCompleters.ps1'
    } |
    Sort-Object Name |
    ForEach-Object {
        . $_.FullName
    }


# =============================================================================
# Misc
# =============================================================================

if (Test-Path $miscPath) {

    Get-ChildItem -Path $miscPath -Filter '*.ps1' -File |
        Sort-Object Name |
        ForEach-Object {
            . $_.FullName
        }
}


# =============================================================================
# Public
# =============================================================================

$publicFunctions = @(
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -File |
        Sort-Object Name
)

foreach ($function in $publicFunctions) {

    . $function.FullName
}


# =============================================================================
# Argument Completers
# =============================================================================

$argumentCompleterPath = Join-Path $privatePath 'Register-MIArgumentCompleters.ps1'

. $argumentCompleterPath


# =============================================================================
# Export Functions
# =============================================================================

$exportedFunctions = @(
    $publicFunctions.BaseName
)

Export-ModuleMember -Function $exportedFunctions


# =============================================================================
# MILF aliases
# =============================================================================

foreach ($functionName in $exportedFunctions) {

    $aliasName = $functionName -replace '^(\w+)-MI', 'MILF-'

    if ($aliasName -ne $functionName) {

        $newAliasSplat = @{
            Name        = $aliasName
            Value       = $functionName
            Scope       = 'Global'
            Description = "MILF alias for $functionName"
            Force       = $true
        }

        New-Alias @newAliasSplat
    }
}