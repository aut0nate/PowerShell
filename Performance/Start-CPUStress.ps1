function Start-CPUStress {
    <#
    .SYNOPSIS
        Starts one or more CPU stress threads using background jobs.

    .DESCRIPTION
        Creates CPU-intensive jobs that keep logical processors busy.
        Jobs are tagged so they can be safely stopped later.

    .PARAMETER Threads
        Number of CPU stress threads to start. Defaults to the number of logical processors.

    .EXAMPLE
        Start-CPUStress -Threads 4
    #>

    param(
        [Parameter()]
        [int]
        $Threads = [Environment]::ProcessorCount
    )

    Write-Host "Starting $Threads CPU stress jobs..." -ForegroundColor Yellow

    $scriptBlock = {
        while ($true) {
            [Math]::Sqrt(12345) > $null
        }
    }

    for ($i = 1; $i -le $Threads; $i++) {
        Start-Job -ScriptBlock $scriptBlock -Name "CPUStress_$i" | Out-Null
    }

    Write-Host "CPU stress started. Use Stop-CPUStress to end the test." -ForegroundColor Green
}
