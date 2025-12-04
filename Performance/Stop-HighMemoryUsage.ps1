function Stop-HighMemoryUsage {
    <#
    .SYNOPSIS
        Releases memory allocated by Start-HighMemoryUsage.

    .DESCRIPTION
        Clears the script-scoped variable and forces garbage collection.

    .EXAMPLE
        Stop-HighMemoryUsage
    #>

    if (-not $script:MemoryBlocks) {
        Write-Host "No memory blocks found to release." -ForegroundColor Cyan
        return
    }

    Write-Host "Releasing allocated memory..." -ForegroundColor Yellow

    $script:MemoryBlocks = $null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()

    Write-Host "Memory released." -ForegroundColor Green
}
