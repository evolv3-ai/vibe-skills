# Static QA / Release Checklist

Run `scripts/static-qa-gates.sh` to execute the automated portion; the manual items below remain operator-driven.

## Automated (via `static-qa-gates.sh`)
- [ ] `validate-contract.sh` passes
- [ ] `profile-preflight.sh` passes against `tests/fixtures/profile/valid.json`
- [ ] `validate-dep-graph.sh` passes (no duplicates / missing deps / cycles)
- [ ] No duplicate artifact content under `artifacts/`
- [ ] Markdown link sweep (set `QA_CHECK_MD_LINKS=1`)

## Manual
- [ ] `smoke-test.sh` passes locally
- [ ] Bash + PowerShell parity verified (`test-contract-parity.sh`)
- [ ] CHANGELOG updated with breaking changes (if any)
- [ ] Provider adapters re-tested for `health_check`
