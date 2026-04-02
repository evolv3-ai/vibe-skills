$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsRoot = (Resolve-Path (Join-Path $ScriptRoot "../.." )).Path
$AdminSkill = Join-Path $SkillsRoot "admin"
$DevopsSkill = Join-Path $SkillsRoot "admin-devops"
$ArchiveDir = (Resolve-Path (Join-Path $SkillsRoot "../archive/skills") -ErrorAction SilentlyContinue).Path

$errors = 0
function Fail($msg) {
  Write-Host $msg
  $script:errors++
}

Write-Host "=== Phase 5 Consolidation Verification (PowerShell) ==="

# Test 1: Required directories exist
Write-Host -NoNewline "Test 1: Directory structure... "
if ((Test-Path (Join-Path $AdminSkill "references")) -and (Test-Path (Join-Path $DevopsSkill "references"))) {
  Write-Host "PASS"
} else { Fail "FAIL" }

# Test 2: Required files exist
Write-Host -NoNewline "Test 2: Required files... "
$required = @(
  (Join-Path -Path $AdminSkill -ChildPath "references/windows.md")
  (Join-Path -Path $AdminSkill -ChildPath "references/wsl.md")
  (Join-Path -Path $AdminSkill -ChildPath "references/mcp.md")
  (Join-Path -Path $DevopsSkill -ChildPath "references/hetzner.md")
  (Join-Path -Path $DevopsSkill -ChildPath "references/coolify.md")
)
if ($required | ForEach-Object { Test-Path $_ } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { $_ -eq 0 }) {
  Write-Host "PASS"
} else { Fail "FAIL" }

# Test 3: Reference integrity
Write-Host -NoNewline "Test 3: Reference integrity... "
$refs = @()
$refs += (Get-Content (Join-Path $AdminSkill "SKILL.md") | Select-String -Pattern "references/[A-Za-z0-9._{}-]+\.md" -AllMatches).Matches.Value
$refs += (Get-Content (Join-Path $DevopsSkill "SKILL.md") | Select-String -Pattern "references/[A-Za-z0-9._{}-]+\.md" -AllMatches).Matches.Value
$refs = $refs | Sort-Object -Unique | Where-Object { $_ -ne "references/{platform}.md" }
$ok = $true
foreach ($r in $refs) {
  if (-not (Test-Path (Join-Path $AdminSkill $r)) -and -not (Test-Path (Join-Path $DevopsSkill $r))) { $ok = $false }
}
if ($ok) { Write-Host "PASS" } else { Fail "FAIL" }

# Test 4: Profile gate parity
Write-Host -NoNewline "Test 4: Profile gate parity... "
$adminGate = Join-Path $AdminSkill "references/profile-gate.md"
$devopsGate = Join-Path $DevopsSkill "references/profile-gate.md"
if ((Test-Path $adminGate) -and (Test-Path $devopsGate) -and ((Get-FileHash $adminGate).Hash -eq (Get-FileHash $devopsGate).Hash)) {
  Write-Host "PASS"
} else { Fail "FAIL" }

# Test 5: Version files correct
Write-Host -NoNewline "Test 5: Version files... "
$adminVer = (Get-Content (Join-Path $AdminSkill "VERSION") -ErrorAction SilentlyContinue)
$devopsVer = (Get-Content (Join-Path $DevopsSkill "VERSION") -ErrorAction SilentlyContinue)
if ($adminVer -eq "0.0.3" -and $devopsVer -eq "0.0.3") { Write-Host "PASS" } else { Fail "FAIL" }

# Test 6: Old skills archived
Write-Host -NoNewline "Test 6: Old skills archived... "
if ($ArchiveDir -and (Test-Path (Join-Path $ArchiveDir "admin-windows")) -and -not (Test-Path (Join-Path $SkillsRoot "admin-windows"))) {
  Write-Host "PASS"
} else { Fail "FAIL" }

# Test 7: Logging scripts present in admin-devops
Write-Host -NoNewline "Test 7: Logging scripts in admin-devops... "
if ((Test-Path (Join-Path $DevopsSkill "scripts/log-admin-event.sh")) -and (Test-Path (Join-Path $DevopsSkill "scripts/Log-AdminEvent.ps1"))) {
  Write-Host "PASS"
} else { Fail "FAIL" }

Write-Host "=== Results: $((7 - $errors))/7 tests passed ==="
if ($errors -eq 0) {
  Write-Host "Consolidation verified!"
  exit 0
}
Write-Host "ERRORS: $errors tests failed"
exit 1
