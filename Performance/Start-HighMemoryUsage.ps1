function Start-HighMemoryUsage {
    <#
    .SYNOPSIS
        Simulates high memory usage by allocating large byte arrays.

    .DESCRIPTION
        Allocates a specified number of memory blocks, each of a specified size in MB.
        Useful for simulating applications that legitimately consume large amounts of RAM.

    .PARAMETER BlockSizeMB
        Size in MB of each memory allocation block. Default is 256 MB.

    .PARAMETER BlockCount
        Number of blocks to allocate. Default is 8.

    .PARAMETER DelaySeconds
        Pause between block allocations to allow observation.

    .PARAMETER Hold
        If set, the function will wait for user input before releasing memory.

    .EXAMPLE
        Start-HighMemoryUsage -BlockSizeMB 512 -BlockCount 10

    .EXAMPLE
        Start-HighMemoryUsage -BlockSizeMB 256 -BlockCount 4 -Hold
    #>

    param(
        [Parameter()]
        [ValidateRange(1,4096)]
        [int]$BlockSizeMB = 256,

        [Parameter()]
        [ValidateRange(1,500)]
        [int]$BlockCount = 8,

        [Parameter()]
        [ValidateRange(0,60)]
        [int]$DelaySeconds = 2,

        [Parameter()]
        [switch]$Hold
    )

    Write-Host "Starting high memory allocation..." -ForegroundColor Yellow
    Write-Host "  Block Size:  $BlockSizeMB MB"
    Write-Host "  Block Count: $BlockCount"
    Write-Host ""

    # Script-scoped so Stop-HighMemoryUsage can release it
    $script:MemoryBlocks = @()

    for ($i = 1; $i -le $BlockCount; $i++) {

        Write-Host "Allocating block $i of $BlockSizeMB MB..." -ForegroundColor Cyan

        # Allocate raw memory
        $script:MemoryBlocks += ,(New-Object byte[] ($BlockSizeMB * 1MB))

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Host ""
    Write-Host "High memory allocation complete." -ForegroundColor Green

    if ($Hold) {
        Write-Host "Press ENTER to release memory..." -ForegroundColor Yellow
        [void][System.Console]::ReadLine()
        Stop-HighMemoryUsage
    }
}
