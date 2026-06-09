$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$doc = Get-Content -Raw "$root/contracts/contract.v1.json" | ConvertFrom-Json
$required = @('version','routing','profile','secrets','logging','commands')
$missing = @()
foreach ($k in $required) { if (-not $doc.PSObject.Properties.Name.Contains($k)) { $missing += $k } }
if ($missing.Count -gt 0) {
  @{ ok = $false; missing = $missing } | ConvertTo-Json -Compress
  exit 1
}
@{ ok = $true; version = $doc.version } | ConvertTo-Json -Compress
