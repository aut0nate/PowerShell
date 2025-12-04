function Stop-MemoryLeakSimulation {
    <#
    .SYNOPSIS
        Stops the memory leak simulation and releases allocated memory.

    .DESCRIPTION
        Clears the leak array stored in module scope and triggers garbage collection.

    .EXAMPLE
        Stop-MemoryLeakSimulation
    #>

    if (-not $script:LeakActive -and -not $script:LeakBlocks) {
        Write-Host "Memory leak simulation is not currently running." -ForegroundColor Cyan
        return
    }

    Write-Host "Stopping memory leak simulation..." -ForegroundColor Yellow
    $script:LeakActive = $false

    Write-Host "Releasing allocated memory..." -ForegroundColor Yellow
    $script:LeakBlocks = $null

    # Trigger garbage collection properly
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()

    Write-Host "Memory leak simulation stopped and memory released." -ForegroundColor Green
}
