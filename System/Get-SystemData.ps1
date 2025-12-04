
<# =====================================================================
  Collect-NodeDiagnostics.ps1  –  v7.5   (Scans workitems only, triggers on low space)
  - Only scans D:\batch\tasks\workitems for files.
  - Only outputs LargestFiles_D.csv if D: is low on space (default < 10GB).
  - Always reports last write to workitems subtree.
===================================================================== #>

[CmdletBinding()]
param(
    [int]   $MetricsDurationSec = 60,
    [int]   $LargestFileCount   = 50,
    [int]   $LowSpaceGB         = 10,    # Trigger largest-files report if less than this GB left
    [switch]$LogToFile,
    [string]$OutputFolder = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'NodeDiag')
)

$WorkItemsRoot = 'D:\batch\tasks\workitems'

# ── Logger ───────────────────────────────────────────────────────────────
$logFile = Join-Path $OutputFolder 'NodeDiag.log'
function Write-Log {
    param([string]$Msg)
    $line = "[{0:u}] {1}" -f (Get-Date), $Msg
    Write-Output $line
    if ($LogToFile) { Add-Content $logFile -Value $line }
}

# ── Prep ────────────────────────────────────────────────────────────────
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
Write-Log "Diagnostics started – sampling for $MetricsDurationSec s"

try {
    # 1 ─ systeminfo (pretty list) ----------------------------------------
    systeminfo /FO LIST | Out-File (Join-Path $OutputFolder 'SystemInfo.txt') -Encoding utf8
    Write-Log "SystemInfo.txt saved"

    # 2 ─ process snapshots ----------------------------------------------
    Get-Process | Sort CPU -Descending |
      Select -First 25 Id,Name,CPU,
             @{N='WorkingSetMB';E={[math]::Round($_.WS/1MB,1)}} |
      Export-Csv (Join-Path $OutputFolder 'TopCPU.csv') -NoTypeInformation

    Get-Process | Sort WS -Descending |
      Select -First 25 Id,Name,
             @{N='WorkingSetMB';E={[math]::Round($_.WS/1MB,1)}} |
      Export-Csv (Join-Path $OutputFolder 'TopMemory.csv') -NoTypeInformation
    Write-Log "TopCPU.csv / TopMemory.csv captured"

    # 3 ─ performance counters -------------------------------------------
    $counters = @(
        '\Processor(_Total)\% Processor Time',
        '\System\Processor Queue Length',
        '\Memory\Available MBytes',
        '\Memory\Committed Bytes',
        '\Memory\Commit Limit',
        '\Paging File(_Total)\% Usage',
        '\PhysicalDisk(*)\Avg. Disk sec/Transfer',
        '\PhysicalDisk(*)\Current Disk Queue Length',
        '\TCPv4\Segments Retransmitted/sec',
        '\Process(ahost)\Working Set - Private',
        '\Process(ahost)\Private Bytes',
        '\Process(ahost)\% Processor Time',
        '\.NET CLR Memory(ahost)\% Time in GC'
    )

    $samples = $null
    $counterError = $null
    try {
        $samples = Get-Counter $counters -SampleInterval 1 -MaxSamples $MetricsDurationSec -ErrorAction Stop
        Write-Log "Perf counters gathered"
    }
    catch {
        $counterError = $_.Exception.Message
        Write-Log "⚠ Get-Counter failed: $counterError"
        $samples = $null
    }

    # add synthetic D:\ free-space counter if we have samples
    $diskD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction SilentlyContinue
    $dFreeGB = $null
    if ($samples -and $diskD) {
        $samples.CounterSamples += [pscustomobject]@{
            Path        = '\LogicalDisk(D:)\Free Megabytes'
            TimeStamp   = Get-Date
            CookedValue = [math]::Round($diskD.FreeSpace/1MB,0)
        }
        $dFreeGB = [math]::Round($diskD.FreeSpace/1GB,1)
    }
    elseif ($diskD) {
        $dFreeGB = [math]::Round($diskD.FreeSpace/1GB,1)
    }

    # save raw + summary if any samples
    if ($samples) {
        $samples | Export-Counter -Path (Join-Path $OutputFolder 'ResourceCounters.blg') -FileFormat BLG
        $samples.CounterSamples |
            Select TimeStamp,Path,CookedValue |
            Export-Csv (Join-Path $OutputFolder 'ResourceCounters.csv') -NoTypeInformation

        # friendly summary
        $samples.CounterSamples | ForEach-Object {
            $v = $_.CookedValue
            [pscustomobject]@{
                TimeStamp = $_.TimeStamp
                Counter   = $_.Path
                Value     = switch -Wildcard ($_.Path) {
                              '*Available MBytes'          { '{0:N0} MB' -f $v }
                              '*Committed Bytes'           { '{0:N2} GB' -f ($v/1GB) }
                              '*Private Bytes'             { '{0:N2} GB' -f ($v/1GB) }
                              '*Working Set - Private*'    { '{0:N2} GB' -f ($v/1GB) }
                              '*Free Megabytes'            { '{0:N0} MB free' -f $v }
                              '*Bytes/sec'                 { '{0:N2} MB/s' -f ($v/1MB) }
                              '*Disk sec/Transfer'         { '{0:N3} ms' -f ($v*1000) }
                              default                      { '{0:N2}' -f $v }
                           }
            }
        } | Export-Csv (Join-Path $OutputFolder 'ResourceSummary.csv') -NoTypeInformation
        Write-Log "Perf summary written"
    }
    else {
        Write-Log "No performance data captured (all counters missing or unavailable)."
    }

    # 4 ─ workitems files: last write always, largest files if D: nearly full ----
    $largestCsv = Join-Path $OutputFolder 'LargestFiles_D.csv'
    $lastWrite = $null
    $lastWritePath = $null
    $largest5 = @('   (not triggered)')
    $filesInScope = @()
    $scanStart = Get-Date

    if (Test-Path $WorkItemsRoot) {
        try {
            $filesInScope = Get-ChildItem -File -Recurse -Path $WorkItemsRoot -ErrorAction SilentlyContinue
        } catch { }
        $scanElapsed = [math]::Round(((Get-Date) - $scanStart).TotalSeconds, 1)
        Write-Log "workitems scan completed in $scanElapsed s (files: $($filesInScope.Count))"

        if ($filesInScope.Count -gt 0) {
            # Always find most recent write/file
            $lastFileObj = $filesInScope | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $lastWrite = $lastFileObj.LastWriteTime
            $lastWritePath = $lastFileObj.FullName
            Write-Log "Last write to workitems: $lastWrite ($lastWritePath)"

            # Only output largest-files artefact if D: is nearly full
            if ($dFreeGB -ne $null -and $dFreeGB -lt $LowSpaceGB) {
                $largestFiles = $filesInScope | Sort-Object Length -Descending | Select-Object -First $LargestFileCount
                $largestFiles | Select `
                    @{N='Created';E={$_.CreationTime}},
                    @{N='SizeMB'; E={[math]::Round($_.Length/1MB,1)}},
                    FullName |
                    Export-Csv $largestCsv -NoTypeInformation
                Write-Log "LargestFiles_D.csv output (D: free = $dFreeGB GB, threshold $LowSpaceGB GB)"
                $largest5 = Import-Csv $largestCsv | Select -First 5 | ForEach-Object { "   $($_.Created)  $($_.SizeMB) MB  $($_.FullName)" }
            }
            else {
                Write-Log "D: has sufficient free space ($dFreeGB GB) – skipping largest-files output."
            }
        } else {
            $lastWrite = "No files found in $WorkItemsRoot"
            $lastWritePath = ""
            Write-Log "No files found in $WorkItemsRoot for last-write check."
        }
    } else {
        $lastWrite = "$WorkItemsRoot not present"
        $lastWritePath = ""
        Write-Log "$WorkItemsRoot not present – skipping file scan"
    }

    # 5 ─ Winevents.txt ---------------------------------------------------
    $winevPath = Join-Path $OutputFolder 'Winevents.txt'
    Get-WinEvent -FilterHashtable @{LogName=@('Application','System'); Level=@(2,3)} `
                 -MaxEvents 10 | ForEach-Object {
        '─' * 70
        "Time   : {0:u}" -f $_.TimeCreated
        "ID     : $($_.Id)"
        "Source : $($_.ProviderName)"
        "Message:"
        $_.Message
    } | Out-File $winevPath -Encoding utf8
    Write-Log "Winevents.txt created"

    # 6 ─ Summary.txt -----------------------------------------------------
    $osReg  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $osName = $osReg.ProductName
    $osVer  = "$($osReg.CurrentVersion).$($osReg.CurrentBuildNumber)"
    $boot   = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToLocalTime().ToString('g')
    $cs     = Get-CimInstance Win32_ComputerSystem
    $os     = Get-CimInstance Win32_OperatingSystem
    $totGB  = [math]::Round($cs.TotalPhysicalMemory/1GB,1)
    $freeGB = [math]::Round($os.FreePhysicalMemory*1KB/1GB,1)
    $capt   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss (UTCzzz)'

    $topMem = Get-Process | Sort WS -Descending | Select -First 5 |
              ForEach-Object { "   PID {0,-6} {1,-20} {2:N2} GB" -f $_.Id,$_.Name,($_.WS/1GB) }

    $disks  = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
              ForEach-Object { "   {0}  {1:N0} GB total / {2:N0} GB free" -f $_.DeviceID,($_.Size/1GB),($_.FreeSpace/1GB) }

@"
=== Node Diagnostic Summary ===
Hostname        : $env:COMPUTERNAME
OS              : $osName
OS Version      : $osVer
System Boot Time: $boot
Captured        : $capt

Memory          : $totGB GB total / $freeGB GB free

Top memory-consuming processes:
$($topMem -join "`n")

Disks:
$($disks -join "`n")

Largest files in $WorkItemsRoot (Display top 5, only when D:\ is nearly full):
$($largest5 -join "`n")

Last write to $WorkItemsRoot : $lastWrite
File written                : $lastWritePath
"@ | Out-File (Join-Path $OutputFolder 'Summary.txt') -Encoding utf8
    Write-Log "Summary.txt created"

    # 7 ─ zip everything --------------------------------------------------
    $zipPath = Join-Path (Split-Path $OutputFolder -Parent) "NodeDiag_$((Get-Date).ToString('yyyyMMdd_HHmmss')).zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($OutputFolder,$zipPath)
    Write-Log "Output folder zipped to $zipPath"
    Write-Log "Diagnostics complete – download $zipPath"
}
catch {
    Write-Log "Failure: $($_.Exception.Message)"
    throw
}
