# Admin-DevOps Contracts

Machine-readable source-of-truth for routing, profile validation, secrets resolution, logging, and command UX.

## Versioning
- `contract.v1.json` is the canonical contract payload.
- `*.schema.json` define JSON Schema validation rules.
- Backward-incompatible changes require a new major version (`contract.v2.json`).

## Validation
Run `scripts/validate-contract.sh` (or `.ps1`) and `scripts/test-contract-parity.sh` to verify both shells produce the same result.
