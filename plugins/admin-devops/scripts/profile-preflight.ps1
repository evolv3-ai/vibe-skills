param(
  [string]$ProfilePath = $env:ADMIN_PROFILE_PATH,
  [switch]$Json,
  [switch]$FixSuggestions
)
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $ProfilePath) { $ProfilePath = "$root/tests/fixtures/profile/valid.json" }
if (-not (Test-Path $ProfilePath)) {
  if ($Json) { "{`"ok`":false,`"error_code`":`"PROFILE_MISSING`",`"profile`":`"$ProfilePath`"}" }
  else { "PROFILE_MISSING: $ProfilePath" }
  exit 2
}
$raw = Get-Content -Raw -Path $ProfilePath | ConvertFrom-Json
$required = @('schemaVersion','bindings','consumer','secretsConfig')
$missing = @()
foreach ($k in $required) { if (-not $raw.PSObject.Properties.Name.Contains($k)) { $missing += $k } }
if ($raw.PSObject.Properties.Name.Contains('secretsConfig')) {
  if (-not $raw.secretsConfig.PSObject.Properties.Name.Contains('primaryBackend')) {
    $missing += 'secretsConfig.primaryBackend'
  }
}
if ($missing.Count -gt 0) {
  if ($Json) {
    $obj = @{ ok = $false; error_code = 'PROFILE_INVALID'; missing = $missing }
    if ($FixSuggestions) { $obj.fix_suggestions = $missing | ForEach-Object { "Add '$_' to profile" } }
    $obj | ConvertTo-Json -Compress
  } else {
    "PROFILE_INVALID: missing $($missing -join ', ')"
  }
  exit 3
}
if ($Json) { '{"ok":true,"profile":"' + $ProfilePath + '"}' } else { 'OK: profile valid' }
