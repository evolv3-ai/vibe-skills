# devadmin workspace templates

Templates the `/admin-devops:adopt-devadmin` command instantiates into a host's
**devadmin workspace** — the folder a Claude Code session runs from to act as that
host's shared-host-ops seat against the Open Engine `devadmin` Linear backlog.

These graduated out of the per-host staging location
(`~/.admin/templates/devadmin/` on WOPR3) and are now the single source of truth.
Edit them here; the adopt command reads them from the installed plugin.

## Files

| File | Used when | Instantiated to |
| -- | -- | -- |
| `CLAUDE.md.native.template` | Windows native, macOS, or bare-Linux host seat | Windows: `D:\devadmin\CLAUDE.md` · macOS/Linux: `~/dev/devadmin/CLAUDE.md` |
| `CLAUDE.md.wsl.template` | Claude Code inside WSL, or a Linux VPS seat | `~/dev/devadmin/CLAUDE.md` |

The adopt command picks the template from the profile's `ADMIN_PLATFORM`
(`windows`/`macos`/`linux` → native, `wsl` → wsl).

## Placeholders

Substituted from the admin profile (`~/.admin/.env` + `$ADMIN_ROOT/profiles/<device>.json`)
at adoption time. The `devadmin-adopt` script emits these as a JSON `placeholders`
object; the command performs the substitution.

| Placeholder | Source | Example |
| -- | -- | -- |
| `{{HOST}}` | `ADMIN_DEVICE` (display) | `WOPR3` |
| `{{HOST_SLUG}}` | host slug (lowercased, de-suffixed) | `wopr3` |
| `{{HOST_LABEL}}` | `host:<slug>` | `host:wopr3` |
| `{{AGENT_CODE}}` | routing-map seat code for this runtime | `wopr3-claude-cli` / `wopr3-claude-cli-wsl` |
| `{{PLATFORM}}` | `ADMIN_PLATFORM` | `windows` / `wsl` / `linux` / `macos` |
| `{{WORKSPACE_PATH}}` | canonical workspace for the platform | `D:\devadmin` / `~/dev/devadmin` |
| `{{ADMIN_ROOT}}` | `ADMIN_ROOT` | `~/.admin` / `C:\Users\Owner\.admin` |
| `{{LOCAL_ISSUES_DIR}}` | `$ADMIN_ROOT/issues` | `~/.admin/issues` |
| `{{GENERATED}}` | adoption date (ISO, supplied by the command) | `2026-07-01` |

## Shape version

Each template carries a `Template shape version` in its header comment and body. The
adopt command's CLAUDE.md shape-diff compares an existing workspace's version (and a
content hash) against the current template to flag a stale workspace that needs
re-instantiation. **Bump the version when the template structure changes.**

## Retired-path table = migration spec

The "Retired shapes" table in each template is the canonical list of older
admin-devops workspace shapes. `/admin-devops:adopt-devadmin` reads it to detect drift
and offer migration. Adding a row here is how you teach the adopt command about a new
retired shape — keep it current and the migration command stays current.
