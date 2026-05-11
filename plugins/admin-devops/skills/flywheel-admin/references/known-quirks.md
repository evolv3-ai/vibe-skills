# Known Quirks — Fleet-Specific Gotchas

These are real failure modes observed on the current fleet. Each has the exact fix.

## ACFS / Stack

### ACFS v0.5.0 checksum drift

**Symptom:** `acfs-update --stack` bails with checksum mismatch.
**Cause:** Both flywheels are pinned on v0.5.0; upstream is on v0.6.0; local checksums are stale.
**Fix:** Refresh checksums first.

```bash
ssh flywheel-N-oci 'curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/checksums.yaml -o ~/.acfs/checksums.yaml'
ssh flywheel-N-oci 'acfs-update --stack'
```

### DCG aarch64 binary is wrong arch

**Symptom:** `dcg` fails to exec on ARM64 flywheels.
**Cause:** The official v0.5.1 aarch64 release tarball ships an x86_64 binary.
**Fix:** Build from source.

```bash
ssh flywheel-N-oci '
  cd /tmp && \
  git clone --depth 1 https://github.com/Dicklesworthstone/destructive_command_guard.git && \
  cd destructive_command_guard && \
  cargo build --release && \
  cp target/release/dcg ~/.local/bin/
'
```

### Agent Mail: Python vs Rust

**Symptom:** `acfs doctor` recommends the Python repo, but `run_server_with_token.sh` points to the Rust one. Confusion.
**Cause:** ACFS docs lag the actual install scripts.
**Fix:** Install the Rust version.

```bash
ssh flywheel-N-oci 'curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail_rust/main/install.sh | bash -s -- --yes --easy-mode --migrate --verify'
```

Service runs on `127.0.0.1:8765/mcp/`. Health probe: `curl -fsSL http://127.0.0.1:8765/health`.

### flywheel-1 stuck on `user_setup` ACFS state

**Symptom:** ACFS reports an incomplete install state, but everything works and `acfs doctor` is green.
**Cause:** Original install on flywheel-1 didn't finish cleanly.
**Fix (optional):** Re-run `install.sh --skip-ubuntu-upgrade` to normalize state. Cosmetic; not blocking.

### SSH keepalive doctor false-positive (flywheel-1)

**Symptom:** `acfs doctor` warns about missing `ClientAliveInterval`.
**Cause:** Older `doctor.sh` only reads `/etc/ssh/sshd_config`, not `sshd_config.d/`.
**Fix:** None needed — the directive is set in both files. Cosmetic.

### Codex `bubblewrap` warning

**Symptom:** Codex CLI complains about missing `bubblewrap` on startup.
**Cause:** Codex bundles a fallback but prefers the OS package.
**Fix:** `ssh flywheel-N-oci 'sudo apt install -y bubblewrap'`.

### Codex "3 hooks need review"

**Symptom:** Codex prompts about unreviewed hooks.
**Cause:** Interactive approval required.
**Fix:** Run `/hooks` inside a Codex session and approve. Cannot be automated.

## Ubuntu / OS

### Version drift between hosts

flywheel-2 is on Ubuntu **25.10** (interim release), flywheel-1 on **24.04 LTS**. To bring flywheel-1 forward would need three sequential `do-release-upgrade`s. **Not worth the risk on Oracle ARM.** Live with the drift; both work.

### Apt + kernel updates

Both hosts had `apt full-upgrade` + kernel reboot during the 2026-05-11 maintenance session. Re-run if `acfs doctor` flags kernel-mismatch warnings.

## NTM-specific (most-hit gotchas)

These are also covered in the `ntm` skill, but worth repeating in the flywheel context:

### Session name ≠ project basename

**Symptom:** `agent-mail` and `ntm` "see different projects"; reservations vanish; beads claim against the wrong session.
**Cause:** `NTM_PROJECTS_BASE + <session>` must equal the on-disk directory. `ntm spawn myproj` against `/data/projects/my-proj/` will break silently.
**Fix:** Use the directory basename verbatim. Symlink if you must.

### `ntm send --all` hits the operator

The default `ntm send <session> "msg"` excludes the user pane. `--all` includes it — a `--all` blast in an SSH'd session will land in the operator's zsh. Use `-s/--skip-first` or target panes explicitly.

### CASS dedup blocks `send`

**Symptom:** `ntm send` aborts with "similar past prompt".
**Cause:** Default `--cass-check=true`, 0.7 similarity, 7-day lookback.
**Fix:** Either rotate the suffix (e.g. `"... pass 17 at 16:40"`) or pass `--no-cass-check`. `--robot-send` is non-interactive and skips this.

## Tailscale / Networking

### `dwelf-stork.ts.net` MagicDNS

Tailnet name is `dwelf-stork.ts.net`. MagicDNS resolves `flywheel-1-oci` and `flywheel-2-oci` directly. If `ssh flywheel-N-oci` fails:

```bash
tailscale status                # is the operator on the tailnet?
ping flywheel-N-oci             # is MagicDNS resolving?
ssh flywheel-N-public           # does public-IP path still work?
```

### "Funnel" is not what you want

Tailscale "funnel" exposes a service to the public internet without auth. You do NOT need it for SSH/VSCode between your own tailnet devices. If anyone proposes "use funnel", the answer is no unless we're publishing a public service.

## Disk / Capacity

flywheel-1 currently at ~73 % disk. Watch and prune. Common offenders:

```bash
ssh flywheel-1-oci 'du -sh ~/.cache/* ~/.npm ~/.local/share/cargo /data/projects/*/node_modules 2>/dev/null | sort -h | tail -20'
```

`/data/projects/*/node_modules`, build caches, and old `target/` dirs are the usual top.

## Skill bundle drift

After editing `.claude/skills/` locally, the flywheels are out of date until mirrored. See the **Skill Mirror** section in the main SKILL.md for the rsync recipe. Run it before spawning a swarm that needs a newly-added or -edited skill.
