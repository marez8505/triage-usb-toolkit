<#
.SYNOPSIS
    Lay out the standard triage USB folder structure on a destination
    drive and copy repo scripts/manifests/docs.

.DESCRIPTION
    Windows PowerShell counterpart to build_usb.sh. Does NOT format,
    repartition, or write proprietary binaries. Optionally fetches
    manifest entries that include a 'direct_download_url' field.

.PARAMETER Destination
    Path to the mounted USB drive root (e.g. E:\).

.PARAMETER Download
    If set, attempt to download tools that include a 'direct_download_url'
    field in their manifest entry.

.PARAMETER Force
    Overwrite existing files at the destination.

.EXAMPLE
    .\scripts\build_usb.ps1 -Destination E:\
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Destination,
    [switch] $Download,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TimestampUtc { (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") }
function Get-IsoUtc       { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildTs  = Get-TimestampUtc

if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
    throw "Destination does not exist or is not a directory: $Destination"
}

$LogDir   = Join-Path $Destination "logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile  = Join-Path $LogDir ("build_usb_{0}.log" -f $BuildTs)

function Write-Log {
    param([string] $Level, [string] $Message)
    $line = "[{0}] [{1}] {2}" -f (Get-IsoUtc), $Level, $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Info  ([string]$m) { Write-Log "INFO"  $m }
function Warn  ([string]$m) { Write-Log "WARN"  $m }
function Errlg ([string]$m) { Write-Log "ERROR" $m }

Info "triage-usb-toolkit build_usb.ps1 starting"
Info ("destination={0} download={1} force={2}" -f $Destination, [bool]$Download, [bool]$Force)
Info ("repo_root={0}" -f $RepoRoot)

# 1. Folder layout
$LayoutDirs = @(
    "tools","tools\win","tools\mac","tools\android","tools\ios","tools\common",
    "scripts","manifests","docs","cases","evidence","reports","logs"
)
foreach ($d in $LayoutDirs) {
    New-Item -ItemType Directory -Path (Join-Path $Destination $d) -Force | Out-Null
}
Info "folder layout created"

# 2. Copy repo trees
function Copy-Tree {
    param([string] $Src, [string] $Dst)
    if (-not (Test-Path -LiteralPath $Src)) { Warn "source missing: $Src"; return }
    if ((Test-Path -LiteralPath $Dst) -and -not $Force) {
        Copy-Item -Path (Join-Path $Src "*") -Destination $Dst -Recurse -Force:$false -ErrorAction SilentlyContinue
    } else {
        if (Test-Path -LiteralPath $Dst) { Remove-Item -Recurse -Force -LiteralPath $Dst }
        New-Item -ItemType Directory -Path $Dst -Force | Out-Null
        Copy-Item -Path (Join-Path $Src "*") -Destination $Dst -Recurse -Force
    }
    Info ("copied {0} -> {1}" -f $Src, $Dst)
}

Copy-Tree (Join-Path $RepoRoot "scripts")   (Join-Path $Destination "scripts")
Copy-Tree (Join-Path $RepoRoot "manifests") (Join-Path $Destination "manifests")
Copy-Tree (Join-Path $RepoRoot "docs")      (Join-Path $Destination "docs")

foreach ($f in @("README.md","LICENSE","SECURITY.md")) {
    $src = Join-Path $RepoRoot $f
    if (Test-Path -LiteralPath $src) {
        Copy-Item -Path $src -Destination (Join-Path $Destination $f) -Force
    }
}

# 3. Generate per-tool README.md and tool index
$ToolIndex = Join-Path $LogDir ("tool_index_{0}.tsv" -f $BuildTs)
"" | Out-File -FilePath $ToolIndex -Encoding utf8

Get-ChildItem -Path (Join-Path $RepoRoot "manifests") -Filter *.json | ForEach-Object {
    $m = $_.FullName
    Info ("processing manifest {0}" -f $m)
    try {
        $data = Get-Content -LiteralPath $m -Raw | ConvertFrom-Json
    } catch {
        Warn ("failed to parse manifest {0}: {1}" -f $m, $_.Exception.Message)
        return
    }
    foreach ($tool in $data.tools) {
        $rel = ($tool.destination | Out-String).Trim()
        if (-not $rel) { continue }
        $rel = $rel.TrimStart("/").Replace("/", "\")
        $full = Join-Path $Destination $rel
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        $body = @()
        $body += "# $($tool.name)"
        $body += ""
        $body += "- Category: $($tool.category)"
        $body += "- Platform: $($tool.platform)"
        $body += "- Purpose: $($tool.purpose)"
        $body += "- Official URL: $($tool.official_url)"
        if ($tool.PSObject.Properties.Name -contains "alt_url" -and $tool.alt_url) {
            $body += "- Alternate URL: $($tool.alt_url)"
        }
        $body += "- License: $($tool.license)"
        $body += "- Redistribution: $($tool.redistribution)"
        $body += "- Install method: $($tool.install_method)"
        $body += "- Checksum reference: $($tool.checksum_url)"
        $body += "- Expected SHA-256: $($tool.sha256_placeholder)"
        $body += ""
        $body += "## Notes"
        $body += ""
        $body += ($tool.notes | Out-String).Trim()
        $body += ""
        $body += "## How to populate"
        $body += ""
        $body += "1. Download from the Official URL on a clean workstation."
        $body += "2. Verify the publisher signature/SHA-256."
        $body += "3. Place the binaries/archive in this folder."
        ($body -join "`r`n") | Out-File -FilePath (Join-Path $full "README.md") -Encoding utf8 -Force
        ("{0}`t{1}`t{2}`t{3}`t{4}" -f $tool.name, $tool.platform, $rel, $tool.install_method, $tool.redistribution) `
            | Add-Content -Path $ToolIndex
    }
}

# 4. Optional download
if ($Download) {
    Info "--Download enabled; only manifest entries with direct_download_url are fetched."
    Get-ChildItem -Path (Join-Path $RepoRoot "manifests") -Filter *.json | ForEach-Object {
        $data = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        foreach ($tool in $data.tools) {
            $url = $null
            if ($tool.PSObject.Properties.Name -contains "direct_download_url") {
                $url = $tool.direct_download_url
            }
            if (-not $url) { continue }
            $rel = ($tool.destination | Out-String).Trim().TrimStart("/").Replace("/", "\")
            $outDir = Join-Path $Destination $rel
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $fname = [System.IO.Path]::GetFileName($url)
            if (-not $fname) { $fname = "download.bin" }
            $outFile = Join-Path $outDir $fname
            if ((Test-Path -LiteralPath $outFile) -and -not $Force) {
                Info ("skip existing {0}" -f $outFile); continue
            }
            try {
                Info ("downloading {0} -> {1}" -f $url, $outFile)
                Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -TimeoutSec 60
                $h = Get-FileHash -Algorithm SHA256 -LiteralPath $outFile
                Info ("sha256 {0} = {1}" -f $outFile, $h.Hash)
            } catch {
                Warn ("download failed {0}: {1}" -f $url, $_.Exception.Message)
            }
        }
    }
}

# 5. Inventory
$Inventory = Join-Path $LogDir ("inventory_{0}.txt" -f $BuildTs)
"# triage-usb-toolkit build inventory"             | Out-File -FilePath $Inventory -Encoding utf8
"# built: $(Get-IsoUtc)"                            | Add-Content -Path $Inventory
"# destination: $Destination"                       | Add-Content -Path $Inventory
""                                                  | Add-Content -Path $Inventory
"## file listing"                                   | Add-Content -Path $Inventory
Get-ChildItem -Path $Destination -Recurse -File `
    | Where-Object { $_.FullName -notlike "*\logs\*" } `
    | Sort-Object FullName `
    | ForEach-Object { $_.FullName.Substring($Destination.Length).TrimStart("\") } `
    | Add-Content -Path $Inventory
Info ("wrote inventory to {0}" -f $Inventory)

# 6. SHA-256 catalog
$HashFile = Join-Path $LogDir ("sha256_{0}.txt" -f $BuildTs)
"" | Out-File -FilePath $HashFile -Encoding utf8
Get-ChildItem -Path $Destination -Recurse -File `
    | Where-Object { $_.FullName -notlike "*\logs\*" } `
    | ForEach-Object {
        try {
            $h = Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
            ("{0}  {1}" -f $h.Hash, $_.FullName.Substring($Destination.Length).TrimStart("\")) `
                | Add-Content -Path $HashFile
        } catch {
            Warn ("hash failed for {0}: {1}" -f $_.FullName, $_.Exception.Message)
        }
    }
Info ("wrote sha256 catalog to {0}" -f $HashFile)

Info "build_usb.ps1 completed successfully"
Write-Host ""
Write-Host "USB drive built at: $Destination"
Write-Host "Build log:         $LogFile"
Write-Host "Inventory:         $Inventory"
Write-Host "SHA-256 catalog:   $HashFile"
