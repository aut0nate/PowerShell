function Get-AzBatchQuota {
    <#
    .SYNOPSIS
        Retrieves Azure Batch quotas for one or more Batch accounts.

    .DESCRIPTION
        This function queries Azure using the Azure CLI to list Batch accounts
        under a given subscription (and optionally a specific resource group).
        It then extracts quota information, including active jobs, pool quota,
        spot/low-priority vCPUs, total dedicated vCPUs, and per-VM family quotas.

        The results are exported to an Excel file using the ImportExcel module.

    .PARAMETER Subscription
        The Subscription ID or Name to query.

    .PARAMETER ResourceGroup
        (Optional) Filter to a specific Resource Group. If not supplied,
        all Batch accounts in the subscription are included.

    .PARAMETER OutputFile
        Path to the Excel file to export results. Default: .\BatchQuotas.xlsx

    .EXAMPLE
        Get-AzBatchQuota -Subscription "22276496-153b-41f8-bf7c-300b17643973"

        Queries all Batch accounts in the subscription and exports quotas to Excel.

    .EXAMPLE
        Get-AzBatchQuota -Subscription "My Subscription" -ResourceGroup "Integrate.Batch" -OutputFile "RG-BatchQuotas.xlsx"

        Queries only Batch accounts in a specific Resource Group and saves to the given Excel file.

    .NOTES
        Requires:
        - Azure CLI (`az login`)
        - ImportExcel PowerShell module
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Subscription,

        [string]$ResourceGroup,

        [string]$OutputFile = ".\BatchQuotas.xlsx"
    )

    # Ensure ImportExcel is available
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Output "ImportExcel module not found. Installing..."
        Install-Module -Name ImportExcel -Scope CurrentUser -Force
    }

    # Set subscription
    az account set --subscription $Subscription
    $subName = (az account show --subscription $Subscription --query "name" -o tsv)

    # Get all Batch accounts
    $batchAccounts = az batch account list -o json | ConvertFrom-Json

    if (-not $batchAccounts) {
        Write-Warning "No Batch accounts found in subscription $subName"
        return
    }

    # Apply RG filter if provided
    if ($ResourceGroup) {
        $batchAccounts = $batchAccounts | Where-Object { $_.resourceGroup -eq $ResourceGroup }
        if (-not $batchAccounts) {
            Write-Warning "No Batch accounts found in resource group $ResourceGroup"
            return
        }
    }

    $results = @()

    foreach ($acct in $batchAccounts) {
        $acctName = $acct.name
        $acctRg   = $acct.resourceGroup

        Write-Output "Processing Batch account: $acctName (RG: $acctRg)"

        # Get detailed quota info
        $details = az batch account show --name $acctName --resource-group $acctRg -o json | ConvertFrom-Json

        # Top-level quotas
        $results += [pscustomobject]@{
            Subscription              = $subName
            Region                    = $details.location
            BatchAccount              = $details.name
            "Active jobs & schedules" = $details.activeJobAndJobScheduleQuota
            Pools                     = $details.poolQuota
            "Spot/Low-priority VCPUs" = $details.lowPriorityCoreQuota
            "Total Dedicated VCPUs"   = $details.dedicatedCoreQuota
            VMSeries                  = ""
            Quota                     = ""
        }

        # VM Families with quotas > 0
        foreach ($fam in $details.dedicatedCoreQuotaPerVmFamily) {
            if ($fam.coreQuota -gt 0) {
                $results += [pscustomobject]@{
                    Subscription              = $subName
                    Region                    = $details.location
                    BatchAccount              = $details.name
                    "Active jobs & schedules" = ""
                    Pools                     = ""
                    "Spot/Low-priority VCPUs" = ""
                    "Total Dedicated VCPUs"   = ""
                    VMSeries                  = $fam.name
                    Quota                     = $fam.coreQuota
                }
            }
        }
    }

    # Sort by Region then BatchAccount
    $results = $results | Sort-Object Region, BatchAccount

    # Export to Excel
    $results | Export-Excel -Path $OutputFile -AutoSize -BoldTopRow -FreezeTopRow -Title "Azure Batch Quotas"

    Write-Output "Batch quota report exported to $OutputFile"
}