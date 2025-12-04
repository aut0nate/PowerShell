function Stop-DiskFill {
    <#
    .SYNOPSIS
        Removes test disk fill files created during disk stress testing.

    .PARAMETER Path
        The path of the disk fill file to remove.

    .EXAMPLE
        Stop-DiskFill -Path "D:\growing.log"
    #>

    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Write-Host "Removing file: $Path" -ForegroundColor Yellow
        Remove-Item $Path -Force
        Write-Host "File removed." -ForegroundColor Green
    }
    else {
        Write-Host "No test file found at $Path." -ForegroundColor Cyan
    }
}
