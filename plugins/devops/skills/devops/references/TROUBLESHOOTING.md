# Troubleshooting

## Contents
- SSH connection failed
- Inventory parse errors
- Provider skill not found

---

## SSH Connection Failed

Bash:

```bash
SERVER_ID="WEB01"
HOST=$(grep "SERVER_${SERVER_ID}_HOST=" .agent-devops.env | cut -d= -f2)
USER=$(grep "SERVER_${SERVER_ID}_USER=" .agent-devops.env | cut -d= -f2)
KEY=$(grep "SERVER_${SERVER_ID}_SSH_KEY_PATH=" .agent-devops.env | cut -d= -f2)

ssh -v -i "$KEY" "$USER@$HOST" echo "connected"
ls -la "$KEY"
chmod 600 "$KEY"
```

PowerShell:

```powershell
$SERVER_ID = "WEB01"
$inventory = Get-Content .agent-devops.env
$HOST = ($inventory | Select-String "SERVER_${SERVER_ID}_HOST=(.*)").Matches.Groups[1].Value
$USER = ($inventory | Select-String "SERVER_${SERVER_ID}_USER=(.*)").Matches.Groups[1].Value
$KEY = ($inventory | Select-String "SERVER_${SERVER_ID}_SSH_KEY_PATH=(.*)").Matches.Groups[1].Value

ssh -v -i $KEY "$USER@$HOST" echo "connected"
icacls $KEY
```

---

## Inventory Parse Errors

Common issues:
- Missing `=` in key‑value pair
- Spaces around `=` (not allowed)
- Invalid characters in key names

Bash validation:

```bash
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  if ! [[ "$line" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
    echo "Invalid line: $line"
  fi
done < .agent-devops.env
```

PowerShell validation:

```powershell
Get-Content .agent-devops.env | ForEach-Object {
    if ($_ -match '^\s*$') { return }
    if ($_ -match '^\s*#') { return }
    if ($_ -notmatch '^[A-Z_][A-Z0-9_]*=') {
        Write-Warning "Invalid line: $_"
    }
}
```

---

## Provider Reference Not Found

Bash:

```bash
ls references/*.md
# If missing, reinstall or resync devops
```

PowerShell:

```powershell
$refsPath = 'references'
Get-ChildItem $refsPath -Filter *.md
# If missing, reinstall or resync devops
```
