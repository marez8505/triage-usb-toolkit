<#
.SYNOPSIS
    Read-only Windows live-response collector for authorized triage.

.DESCRIPTION
    Collects benign system metadata, configuration, and event-log exports
    from a live Windows host. Does NOT collect credentials, secrets, or
    user files. Every command line and exit status is logged. Output
    files are SHA-256 hashed at the end.

    Authorized use only. Run only with documented authority (warrant,
    employer policy, written consent, etc.). See
    docs/LEGAL_AND_ETHICAL_USE.md.

.PARAMETER OutputRoot
    Path under which a per-case folder will be created. Typically a
    folder on a separate evidence drive — NOT the suspect host.

.PARAMETER CaseId
    Case identifier used as the per-run subdirectory name.

.PARAMETER IncludeEventLogs
    If set, exports the System, Security, and Application EVTX logs.
    Note: exporting Security log typically requires Administrator.

.EXAMPLE
    .\collect_windows_live_response.ps1 -OutputRoot E:\evidence -CaseId CASE-2026-001 -IncludeEventLogs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $OutputRoot,
    [Parameter(Mandatory = $true)] [string] $CaseId,
    [switch] $IncludeEventLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Get-IsoUtc { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Get-TsUtc  { (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") }

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    throw "OutputRoot does not exist: $OutputRoot"
}
$CaseId = $CaseId.Trim()
if ([string]::IsNullOrWhiteSpace($CaseId)) { throw "CaseId is required" }

$RunTs   = Get-TsUtc
$CaseDir = Join-Path $OutputRoot ("{0}_{1}" -f $CaseId, $RunTs)
$OutDir  = Join-Path $CaseDir "windows_live_response"
$LogDir  = Join-Path $CaseDir "logs"
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$LogFile  = Join-Path $LogDir "collector.log"
$CmdLog   = Join-Path $LogDir "commands.tsv"
$HashFile = Join-Path $LogDir "sha256.txt"

"# triage-usb-toolkit Windows live-response collector"     | Out-File -FilePath $LogFile -Encoding utf8
"# started: $(Get-IsoUtc)"                                  | Add-Content -Path $LogFile
"# host: $env:COMPUTERNAME"                                 | Add-Content -Path $LogFile
"# user: $env:USERDOMAIN\$env:USERNAME"                     | Add-Content -Path $LogFile
"# case: $CaseId"                                           | Add-Content -Path $LogFile
"# output: $OutDir"                                         | Add-Content -Path $LogFile
""                                                          | Add-Content -Path $LogFile

"timestamp_utc`tcommand`toutput_file`texit_code"           | Out-File -FilePath $CmdLog -Encoding utf8

function Invoke-Logged {
    param(
        [string] $OutFile,
        [scriptblock] $Block,
        [string] $Description
    )
    $stamp = Get-IsoUtc
    $exitCode = 0
    try {
        & $Block | Out-File -FilePath $OutFile -Encoding utf8
    } catch {
        Add-Content -Path $LogFile -Value ("[{0}] [WARN] {1}: {2}" -f $stamp, $Description, $_.Exception.Message)
        $exitCode = 1
    }
    ("{0}`t{1}`t{2}`t{3}" -f $stamp, $Description, $OutFile, $exitCode) | Add-Content -Path $CmdLog
}

# --- system ---------------------------------------------------------------
Invoke-Logged (Join-Path $OutDir "systeminfo.txt")        { systeminfo }                                       "systeminfo"
Invoke-Logged (Join-Path $OutDir "hostname.txt")          { hostname }                                         "hostname"
Invoke-Logged (Join-Path $OutDir "whoami.txt")            { whoami /all }                                      "whoami /all"
Invoke-Logged (Join-Path $OutDir "os_version.txt")        { Get-CimInstance Win32_OperatingSystem | Format-List * } "os_version"
Invoke-Logged (Join-Path $OutDir "computer_system.txt")   { Get-CimInstance Win32_ComputerSystem | Format-List * } "computer_system"
Invoke-Logged (Join-Path $OutDir "bios.txt")              { Get-CimInstance Win32_BIOS | Format-List * }       "bios"
Invoke-Logged (Join-Path $OutDir "timezone.txt")          { Get-TimeZone | Format-List * }                     "timezone"
Invoke-Logged (Join-Path $OutDir "uptime.txt")            { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } "uptime"

# --- users / sessions -----------------------------------------------------
Invoke-Logged (Join-Path $OutDir "local_users.txt")       { Get-LocalUser | Format-Table -AutoSize | Out-String -Width 4096 } "Get-LocalUser"
Invoke-Logged (Join-Path $OutDir "local_groups.txt")      { Get-LocalGroup | Format-Table -AutoSize | Out-String -Width 4096 } "Get-LocalGroup"
Invoke-Logged (Join-Path $OutDir "logged_on_users.txt")   { query user 2>$null } "query user"
Invoke-Logged (Join-Path $OutDir "user_profiles.txt")     { Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, LastUseTime, Special | Format-Table -AutoSize | Out-String -Width 4096 } "Win32_UserProfile"

# --- processes ------------------------------------------------------------
Invoke-Logged (Join-Path $OutDir "processes.txt")         { Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate | Format-Table -AutoSize | Out-String -Width 8192 } "Win32_Process"
Invoke-Logged (Join-Path $OutDir "processes.csv")         { Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate | ConvertTo-Csv -NoTypeInformation } "Win32_Process csv"

# --- services -------------------------------------------------------------
Invoke-Logged (Join-Path $OutDir "services.txt")          { Get-CimInstance Win32_Service | Select-Object Name, DisplayName, State, StartMode, StartName, PathName | Format-Table -AutoSize | Out-String -Width 8192 } "Win32_Service"
Invoke-Logged (Join-Path $OutDir "services.csv")          { Get-CimInstance Win32_Service | Select-Object Name, DisplayName, State, StartMode, StartName, PathName | ConvertTo-Csv -NoTypeInformation } "Win32_Service csv"

# --- network --------------------------------------------------------------
Invoke-Logged (Join-Path $OutDir "ipconfig.txt")          { ipconfig /all } "ipconfig /all"
Invoke-Logged (Join-Path $OutDir "route_print.txt")       { route print }   "route print"
Invoke-Logged (Join-Path $OutDir "arp.txt")               { arp -a }        "arp -a"
Invoke-Logged (Join-Path $OutDir "netstat.txt")           { netstat -anob } "netstat -anob"
Invoke-Logged (Join-Path $OutDir "tcp_connections.txt")   { Get-NetTCPConnection | Format-Table -AutoSize | Out-String -Width 4096 } "Get-NetTCPConnection"
Invoke-Logged (Join-Path $OutDir "udp_endpoints.txt")     { Get-NetUDPEndpoint | Format-Table -AutoSize | Out-String -Width 4096 } "Get-NetUDPEndpoint"
Invoke-Logged (Join-Path $OutDir "dns_cache.txt")         { ipconfig /displaydns } "ipconfig /displaydns"
Invoke-Logged (Join-Path $OutDir "smb_shares.txt")        { Get-SmbShare | Format-Table -AutoSize | Out-String -Width 4096 } "Get-SmbShare"
Invoke-Logged (Join-Path $OutDir "smb_sessions.txt")      { Get-SmbSession | Format-Table -AutoSize | Out-String -Width 4096 } "Get-SmbSession"
Invoke-Logged (Join-Path $OutDir "firewall_profiles.txt") { Get-NetFirewallProfile | Format-List * } "Get-NetFirewallProfile"

# --- scheduled tasks ------------------------------------------------------
Invoke-Logged (Join-Path $OutDir "scheduled_tasks.txt")   { Get-ScheduledTask | Select-Object TaskPath, TaskName, State, Author, Description | Format-Table -AutoSize | Out-String -Width 8192 } "Get-ScheduledTask"
Invoke-Logged (Join-Path $OutDir "scheduled_tasks.csv")   { Get-ScheduledTask | Select-Object TaskPath, TaskName, State, Author, Description | ConvertTo-Csv -NoTypeInformation } "Get-ScheduledTask csv"

# --- installed software ---------------------------------------------------
Invoke-Logged (Join-Path $OutDir "installed_uninstall.txt") {
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation |
        Where-Object { $_.DisplayName } |
        Sort-Object DisplayName |
        Format-Table -AutoSize | Out-String -Width 4096
} "installed software (registry uninstall keys)"

# --- autorun-relevant locations (read-only listings) ---------------------
$AutorunPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\Windows\System32\drivers\etc"
)
Invoke-Logged (Join-Path $OutDir "autorun_paths_listing.txt") {
    foreach ($p in $AutorunPaths) {
        Write-Output "## $p"
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue |
                Select-Object Mode, LastWriteTime, Length, Name | Format-Table -AutoSize | Out-String -Width 4096
        } else {
            Write-Output "(not present)"
        }
        Write-Output ""
    }
} "autorun path listings"

# --- artifact directory listings (metadata only, not contents) -----------
$ArtifactDirs = @(
    "C:\Windows\Prefetch",
    "C:\Windows\System32\winevt\Logs",
    "C:\Windows\System32\Tasks",
    "C:\Windows\AppCompat\Programs",
    "C:\Windows\Temp"
)
Invoke-Logged (Join-Path $OutDir "artifact_listings.txt") {
    foreach ($p in $ArtifactDirs) {
        Write-Output "## $p"
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Force -Recurse -ErrorAction SilentlyContinue |
                Select-Object FullName, Length, LastWriteTimeUtc, CreationTimeUtc, LastAccessTimeUtc |
                Format-Table -AutoSize | Out-String -Width 8192
        } else {
            Write-Output "(not present)"
        }
        Write-Output ""
    }
} "artifact directory listings"

# --- USB / connected device history (registry, read-only) ----------------
Invoke-Logged (Join-Path $OutDir "usb_devices_registry.txt") {
    $keys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Enum\USB",
        "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
    )
    foreach ($k in $keys) {
        Write-Output "## $k"
        if (Test-Path -LiteralPath $k) {
            Get-ChildItem -LiteralPath $k -Recurse -ErrorAction SilentlyContinue |
                Select-Object Name, PSChildName |
                Format-Table -AutoSize | Out-String -Width 4096
        } else {
            Write-Output "(not present)"
        }
        Write-Output ""
    }
} "usb device history (registry)"

# --- event logs (optional) -----------------------------------------------
if ($IncludeEventLogs) {
    foreach ($logName in @("System","Application","Security")) {
        $dst = Join-Path $OutDir ("evtx_{0}.evtx" -f $logName)
        Add-Content -Path $LogFile -Value ("[{0}] [INFO] exporting EVTX {1} -> {2}" -f (Get-IsoUtc), $logName, $dst)
        try {
            wevtutil epl $logName $dst 2>&1 | Out-Null
            ("{0}`twevtutil epl {1}`t{2}`t0" -f (Get-IsoUtc), $logName, $dst) | Add-Content -Path $CmdLog
        } catch {
            Add-Content -Path $LogFile -Value ("[{0}] [WARN] wevtutil failed for {1}: {2}" -f (Get-IsoUtc), $logName, $_.Exception.Message)
            ("{0}`twevtutil epl {1}`t{2}`t1" -f (Get-IsoUtc), $logName, $dst) | Add-Content -Path $CmdLog
        }
    }
}

# --- hash all output files -----------------------------------------------
Add-Content -Path $LogFile -Value ("[{0}] [INFO] hashing collected files" -f (Get-IsoUtc))
"" | Out-File -FilePath $HashFile -Encoding utf8
Get-ChildItem -Path $OutDir -Recurse -File | ForEach-Object {
    try {
        $h = Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
        ("{0}  {1}" -f $h.Hash, $_.FullName.Substring($CaseDir.Length).TrimStart("\")) `
            | Add-Content -Path $HashFile
    } catch {
        Add-Content -Path $LogFile -Value ("[{0}] [WARN] hash failed for {1}: {2}" -f (Get-IsoUtc), $_.FullName, $_.Exception.Message)
    }
}

Add-Content -Path $LogFile -Value ("[{0}] [INFO] collector finished" -f (Get-IsoUtc))

Write-Host ""
Write-Host "Collection complete."
Write-Host "Case dir:       $CaseDir"
Write-Host "Collector log:  $LogFile"
Write-Host "Command log:    $CmdLog"
Write-Host "SHA-256 file:   $HashFile"
