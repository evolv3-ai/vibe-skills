param([switch]$Json)
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$profile_ok = 0; $secrets_ok = 0; $runtime_ok = 0; $mcp_ok = 0; $cli_ok = 0
try { & "$root/scripts/profile-preflight.ps1" -Json | Out-Null; $profile_ok = 1 } catch { }
if ((Test-Path "$root/contracts/secrets-resolution.v1.json") -and (Test-Path "$root/policies/secrets-policy.json")) { $secrets_ok = 1 }
if (Test-Path "$root/contracts/contract.v1.json") { $runtime_ok = 1 }
if (Test-Path "$root/skills/admin/assets/mcp-registry.json") { $mcp_ok = 1 }
if (Get-Command bash -ErrorAction SilentlyContinue) { $cli_ok = 1 }
$score = ($profile_ok + $secrets_ok + $runtime_ok + $mcp_ok + $cli_ok) * 20
$payload = [pscustomobject]@{
  readiness_score = $score
  checks = [pscustomobject]@{
    profile_schema = $profile_ok; secrets_reachability = $secrets_ok
    runtime_freshness = $runtime_ok; mcp_integrity = $mcp_ok; provider_cli_readiness = $cli_ok
  }
}
if ($Json) { $payload | ConvertTo-Json -Compress -Depth 4 }
else { "Doctor readiness: $score / 100"; $payload | ConvertTo-Json -Compress -Depth 4 }
