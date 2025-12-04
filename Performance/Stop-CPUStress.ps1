function Stop-CPUStress {
    <#
    .SYNOPSIS
        Stops and removes CPU stress jobs created by Start-CPUStress.
    #>

    Write-Host "Stopping CPU stress jobs..." -ForegroundColor Yellow

    $jobs = Get-Job | Where-Object { $_.Name -like "CPUStress_*" }

    if (-not $jobs) {
        Write-Host "No CPU stress jobs found." -ForegroundColor Cyan
        return
    }

    $jobs | Stop-Job -ErrorAction SilentlyContinue
    $jobs | Remove-Job -Force

    Write-Host "CPU stress jobs stopped and removed." -ForegroundColor Green
}
