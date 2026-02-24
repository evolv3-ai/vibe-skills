---
name: deckmate
description: |
  Create and manage Stream Deck profiles, buttons, and scripts for VSCode/Claude Code
  developer workflows. Generate .streamDeckProfile ZIP files programmatically. Use when
  creating Stream Deck buttons for hotkeys, text injection, launching developer tools,
  or generating profiles from integration definitions.
---

# DeckMate

DeckMate helps you create and manage Stream Deck integrations for VSCode and Claude Code
workflows. It understands the native Stream Deck profile format and provides tooling for
developer workflow automation.

## Stream Deck Profile Format

Stream Deck profiles are `.streamDeckProfile` files (ZIP archives):

```
ProfileName.streamDeckProfile (ZIP)
└── {UUID}.sdProfile/
    ├── manifest.json              # Profile metadata
    └── Profiles/
        └── {PAGE_ID}/
            ├── manifest.json      # Button/action configuration
            └── Images/
                └── *.png          # Button icons (72x72 or 144x144)
```

For full manifest schemas, device models, and integration definition formats,
see `references/profile-format.md`.

## Built-in Action UUIDs

| UUID | Name | Description |
|------|------|-------------|
| `com.elgato.streamdeck.system.hotkey` | Hotkey | Send keyboard shortcut |
| `com.elgato.streamdeck.system.hotkeyswitch` | Hotkey Switch | Toggle between two hotkeys |
| `com.elgato.streamdeck.system.open` | Open | Open file/folder/URL |
| `com.elgato.streamdeck.system.website` | Website | Open URL in browser |
| `com.elgato.streamdeck.system.text` | Text | Type text string |
| `com.elgato.streamdeck.system.multimedia` | Multimedia | Media controls |
| `com.elgato.streamdeck.profile.backtoparent` | Back | Navigate to parent folder |
| `com.elgato.streamdeck.profile.openchild` | Open Folder | Navigate to subfolder |

## Hotkey Configuration

```json
{
  "Settings": {
    "Coalesce": true,
    "Hotkeys": [
      {
        "KeyCmd": false,
        "KeyCtrl": true,
        "KeyModifiers": 2,
        "KeyOption": false,
        "KeyShift": false,
        "NativeCode": 67,
        "QTKeyCode": 67,
        "VKeyCode": 67
      }
    ]
  }
}
```

**KeyModifiers Bitmask:**
- 1 = Shift
- 2 = Ctrl
- 4 = Alt/Option
- 8 = Cmd/Win

**Common VKeyCodes:**
- A-Z: 65-90
- 0-9: 48-57
- F1-F12: 112-123
- Enter: 13, Tab: 9, Space: 32, Escape: 27

## Creating Stream Deck Actions for Developers

### Terminal Command via Hotkey + Script

1. Create a shell script in `streamdeck/scripts/`:
```bash
#!/bin/bash
# my-command.sh
claude "/chore $1"
```

2. Create a keyboard shortcut in your terminal app to run the script
3. Configure Stream Deck hotkey to trigger that shortcut

### Text Injection (Snippets)

Use the `com.elgato.streamdeck.system.text` action:

```json
{
  "UUID": "com.elgato.streamdeck.system.text",
  "Settings": {
    "text": "## PITER Framework\n\n### P - Prompt Input\n..."
  }
}
```

### Open VSCode Folder

Use the `com.elgato.streamdeck.system.open` action:

```json
{
  "UUID": "com.elgato.streamdeck.system.open",
  "Settings": {
    "openInBrowser": false,
    "path": "/path/to/project/specs"
  }
}
```

### Launch Terminal with Command

**Option 1: Using Open action with terminal app**
```json
{
  "UUID": "com.elgato.streamdeck.system.open",
  "Settings": {
    "path": "/usr/bin/wt",
    "arguments": "-w 0 nt claude"
  }
}
```

**Option 2: Multi-action with hotkey sequence**
1. Open terminal (Ctrl+`)
2. Type command text
3. Send Enter

## Common Developer Patterns

**Launch Claude Interactive** -- Open action with terminal:
```json
{ "UUID": "com.elgato.streamdeck.system.open", "Name": "Claude",
  "Settings": { "path": "/path/to/terminal", "arguments": "claude" } }
```

**Inject Slash Command** -- Text action for quick prefixes:
```json
{ "UUID": "com.elgato.streamdeck.system.text", "Name": "/chore",
  "Settings": { "text": "/chore " } }
```

**Open Project Folder** -- Open action for directories:
```json
{ "UUID": "com.elgato.streamdeck.system.open", "Name": "Specs",
  "Settings": { "path": "/home/user/project/specs" } }
```

**Git Quick Commit (Multi-Action)** -- chain via Multi-Action:
1. Hotkey: Ctrl+` (open terminal)
2. Text: `git add -A && git commit -m ""`
3. Hotkey: Left Arrow (position cursor)

## Creating a Profile Programmatically

### Python Helper

```python
import json
import zipfile
import uuid
import os

def create_profile(name: str, buttons: list, device_model: str = "20GBD9901"):
    """Create a .streamDeckProfile file."""
    profile_uuid = str(uuid.uuid4()).upper()
    page_uuid = str(uuid.uuid4())

    # Root manifest
    root_manifest = {
        "Device": {"Model": device_model, "UUID": ""},
        "Name": name,
        "Pages": {"Current": page_uuid, "Pages": [page_uuid]},
        "Version": "2.0"
    }

    # Build actions from buttons
    actions = {}
    for btn in buttons:
        pos = f"{btn['row']},{btn['col']}"
        actions[pos] = {
            "ActionID": str(uuid.uuid4()),
            "LinkedTitle": False,
            "Name": btn["name"],
            "Settings": btn.get("settings", {}),
            "State": 0,
            "States": [{
                "Title": btn["name"],
                "ShowTitle": True,
                "TitleAlignment": "bottom",
                "TitleColor": "#ffffff"
            }],
            "UUID": btn["uuid"]
        }

    # Page manifest
    page_manifest = {
        "Controllers": [{"Type": "Keypad", "Actions": actions}]
    }

    # Create ZIP
    with zipfile.ZipFile(f"{name}.streamDeckProfile", "w") as zf:
        sd_dir = f"{profile_uuid}.sdProfile"
        zf.writestr(f"{sd_dir}/manifest.json", json.dumps(root_manifest))
        zf.writestr(f"{sd_dir}/Profiles/{page_uuid}/manifest.json", json.dumps(page_manifest))

    return f"{name}.streamDeckProfile"
```

### Usage

```python
buttons = [
    {"row": 0, "col": 0, "name": "Claude",
     "uuid": "com.elgato.streamdeck.system.open", "settings": {"path": "/usr/bin/claude"}},
    {"row": 0, "col": 1, "name": "/chore",
     "uuid": "com.elgato.streamdeck.system.text", "settings": {"text": "/chore "}},
]
create_profile("TAC Developer", buttons)
```

## Workflow: From Integration Definition to Profile

1. **Define integrations** in `profiles/*.json` (blueprint)
2. **Create supporting files** (scripts, snippets)
3. **Generate or manually create** `.streamDeckProfile`
4. **Import** into Stream Deck app

## Best Practices

### Button Layout (15-key Stream Deck)

```
Row 0: [High Priority Actions - Most Used]
Row 1: [Medium Priority - Regular Use]
Row 2: [Low Priority / Navigation]
```

### Icon Guidelines

- Size: 72x72 (standard) or 144x144 (retina)
- Format: PNG with transparency
- Style: Simple, high-contrast icons
- Text: Avoid text in icons, use Title instead

### Naming Conventions

- **Buttons**: Short (1-2 words), action-oriented
- **Scripts**: `kebab-case.sh` (e.g., `run-tests.sh`)
- **Snippets**: Descriptive with extension (e.g., `piter-framework.md`)

## Troubleshooting

### Profile Won't Import

- Verify ZIP structure is correct
- Check `manifest.json` syntax
- Ensure Device Model matches your hardware

### Button Does Nothing

- Check action UUID is valid
- Verify Settings match action type
- For hotkeys, verify key codes

### Script Not Running

```bash
chmod +x scripts/my-script.sh
```
