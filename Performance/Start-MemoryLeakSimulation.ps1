function Start-MemoryLeakSimulation {
    <#
    .SYNOPSIS
        Simulates a memory leak by allocating memory gradually without releasing it.

    .DESCRIPTION
        Creates repeated allocations of byte arrays, causing the process commit size
        to steadily increase over time. This is useful for practising memory leak
        diagnostics using Task Manager, Resource Monitor, and PerfMon.

    .PARAMETER BlockSizeMB
        Size of each allocated block in MB. Default: 64 MB.

    .PARAMETER MaxBlocks
        Maximum number of allocations before stopping automatically.
        Default: 200.

    .PARAMETER DelaySeconds
        Delay between allocations to allow observation in Task Manager/ResMon.

    .PARAMETER Continuous
        If set, continues leaking until Stop-MemoryLeakSimulation is called.

    .EXAMPLE
        Start-MemoryLeakSimulation -BlockSizeMB 64 -MaxBlocks 100

    .EXAMPLE
        Start-MemoryLeakSimulation -Continuous -BlockSizeMB 32
    #>

    param(
        [Parameter()]
        [ValidateRange(1,2048)]
        [int]$BlockSizeMB = 64,

        [Parameter()]
        [ValidateRange(1,10000)]
        [int]$MaxBlocks = 200,

        [Parameter()]
        [ValidateRange(0,60)]
        [int]$DelaySeconds = 5,

        [Parameter()]
        [switch]$Continuous
    )

    # Initialise leak container in module scope
    $script:LeakBlocks = @()
    $script:LeakActive = $true

    Write-Host "Starting memory leak simulation..." -ForegroundColor Yellow
    Write-Host "  Block Size : $BlockSizeMB MB"
    Write-Host "  Max Blocks : $MaxBlocks"
    Write-Host "  Delay      : $DelaySeconds seconds"
    Write-Host "  Continuous : $Continuous"
    Write-Host ""

    $i = 0

    while ($script:LeakActive) {

        $i++
        if (-not $Continuous -and $i -gt $MaxBlocks) {
            Write-Host "Reached maximum block count. Stopping leakage." -ForegroundColor Cyan
            break
        }

        Write-Host "Leaking block $i ($BlockSizeMB MB)..." -ForegroundColor Magenta

        # Allocate memory block
        $script:LeakBlocks += ,(New-Object byte[] ($BlockSizeMB * 1MB))

        # Delay for monitoring
        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Host "Leak simulation finished (or stopped)." -ForegroundColor Green
}
