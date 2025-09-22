<#
.SYNOPSIS
    Calculate the difference between two dates.

.DESCRIPTION
    This script interactively prompts the user to enter a start date and an end date.
    - The start date is required.
    - The end date is optional; if left blank, the current date/time (Get-Date) is used.

    The script:
    1. Normalises input (accepts "/", "-", or "." as separators).
    2. Parses input as a [datetime] object using UK date format (dd/MM/yy HH:mm or dd/MM/yyyy HH:mm).
    3. Uses New-TimeSpan to calculate the difference between the two dates.
    4. Always outputs a positive timespan (order of dates doesn’t matter).
    5. Displays the result in a human-readable format (days, hours, minutes, seconds).

.PARAMETER Start
    Entered interactively. Must be a valid date/time in dd/MM/yy HH:mm or dd/MM/yyyy HH:mm format.

.PARAMETER End
    Entered interactively. Same format as Start. Optional; if omitted, defaults to the current date/time.

.EXAMPLE
    PS> .\Get-DateDiff.ps1
    Enter START date/time (e.g. 01/09/25 12:00): 15/09/25 12:41
    Enter END date/time or press Enter to use NOW:
    The difference is 2 days, 3 hours and 14 minutes.

.EXAMPLE
    PS> .\Get-DateDiff.ps1
    Enter START date/time (e.g. 01/09/25 12:00): 01/09/2025 09:00
    Enter END date/time or press Enter to use NOW: 02/09/2025 10:30
    The difference is 1 day, 1 hour and 30 minutes.

.NOTES
    Author: Nathan
    Created: 2025-09-17
    Script Name: Get-DateDiff.ps1
    Tested on: Windows PowerShell 5.1, PowerShell 7.x
#>

# --- Simple script to calculate difference between two dates ---

function Read-DateEasy([string]$prompt) {
    while ($true) {
        $raw = Read-Host $prompt
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }  # allow blank
        # normalize separators
        $norm = ($raw.Trim() -replace '[-\.]', '/')
        try {
            return [datetime]::Parse($norm, [System.Globalization.CultureInfo]::GetCultureInfo('en-GB'))
        }
        catch {
            Write-Host " Invalid date. Try: 17/09/25 12:42 or 17/09/2025 12:42" -ForegroundColor Red
        }
    }
}

# --- Start date (required)
$start = $null
while (-not $start) {
    $start = Read-DateEasy 'Enter START date/time (e.g. 01/09/25 12:00)'
}

# --- End date (optional, defaults to now)
$end = Read-DateEasy 'Enter END date/time or press Enter to use NOW'
if (-not $end) { $end = Get-Date }

# --- Calculate difference
$ts = New-TimeSpan -Start $start -End $end
if ($ts.Ticks -lt 0) { $ts = -$ts }  # make positive

# --- Build nice output
$parts = @()
if ($ts.Days)    { $parts += ("{0} day{1}"    -f $ts.Days,    $(if ($ts.Days -eq 1) {""} else {"s"})) }
if ($ts.Hours)   { $parts += ("{0} hour{1}"   -f $ts.Hours,   $(if ($ts.Hours -eq 1) {""} else {"s"})) }
if ($ts.Minutes) { $parts += ("{0} minute{1}" -f $ts.Minutes, $(if ($ts.Minutes -eq 1) {""} else {"s"})) }
if ($ts.Seconds -and $parts.Count -eq 0) {  # only show seconds if nothing else
    $parts += ("{0} second{1}" -f $ts.Seconds, $(if ($ts.Seconds -eq 1) {""} else {"s"}))
}

Write-Output "The difference is $($parts -join ', ')."
