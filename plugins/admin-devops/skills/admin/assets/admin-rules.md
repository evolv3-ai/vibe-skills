# Admin Correction Rules

This file is the entry point for the admin-devops correction-rules library. Rules are split into two files so other skills can import the portable platform rules without inheriting admin-devops-specific conventions.

## [platform-cli-rules.md](platform-cli-rules.md)

Cross-platform CLI mistakes that occur regardless of which skill you're operating in. **Importable** by any other skill that needs bash/PowerShell/Windows-Linux interop guidance.

- JSON in curl on Windows (ISSUE-0007)
- PowerShell Inline in Bash Tool (ISSUE-0009)
- `del` Does Not Exist in Bash (ISSUE-0010)
- PowerShell Parameter Names
- grep/pipefail Crash on Optional Config Vars (GitHub #22, #23)
- Dead File References in Bash Conditional Blocks (GitHub #13)
- Script Permissions in WSL/Git (GitHub #18)

## [admin-ecosystem-rules.md](admin-ecosystem-rules.md)

Rules specific to admin-devops conventions: MCP HTTP session protocol, agent-roster integrity, profile schema parity, satellite `.env` contracts. **Not portable** outside admin-devops.

- MCP HTTP Session Init Protocol (ISSUE-0008)
- SKILL.md Agent Roster Must Match Actual Agent Files (GitHub #17)
- PowerShell/Bash Schema Version Parity (GitHub #12)
- Satellite .env Must Include All Keys Downstream Scripts Read (GitHub #22, #23, #24)
