function Start-DiskFillGradually {
    <#
    .SYNOPSIS
        Gradually fills disk space by appending data in chunks.

    .DESCRIPTION
        Writes a specified number of MB chunks to a file at intervals.
        Useful for simulating low disk space conditions and disk write pressure.

    .PARAMETER Path
        The full file path to write to (e.g. D:\growing.log).

    .PARAMETER ChunkSizeMB
        Size of each write chunk in MB. Defaults to 200 MB.

    .PARAMETER Iterations
        Number of write cycles. Defaults to 20.

    .PARAMETER DelaySeconds
        Pause between iterations.

    .EXAMPLE
        Start-DiskFillGradually -Path "D:\growing.log" -ChunkSizeMB 200 -Iterations 10

    #>

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateRange(1,10000)]
        [int]$ChunkSizeMB = 200,

        [Parameter()]
        [ValidateRange(1,1000)]
        [int]$Iterations = 20,

        [Parameter()]
        [ValidateRange(0,60)]
        [int]$DelaySeconds = 5
    )

    # Warn if writing to system drive root
    if ($Path -like "C:\*" -and -not $Path.StartsWith("C:\Temp\", [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "You are writing to the C: drive. This may impact system stability."
    }

    # Ensure file exists
    if (-not (Test-Path $Path)) {
        Write-Host "Creating file: $Path"
        New-Item -ItemType File -Path $Path -Force | Out-Null
    }

    Write-Host "Starting gradual disk fill..."
    Write-Host "  File: $Path"
    Write-Host "  Chunk Size: $ChunkSizeMB MB"
    Write-Host "  Iterations: $Iterations"
    Write-Host "  Delay: $DelaySeconds seconds"
    Write-Host ""

    for ($i = 1; $i -le $Iterations; $i++) {

        Write-Host "[$i/$Iterations] Writing $ChunkSizeMB MB..." -ForegroundColor Yellow

        # Create fixed-size byte array
        $bytes = New-Object byte[] ($ChunkSizeMB * 1MB)

        # Write directly as binary
        [System.IO.File]::WriteAllBytes($Path, ([System.IO.File]::ReadAllBytes($Path) + $bytes))

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Host "Disk fill simulation complete." -ForegroundColor Green
}

