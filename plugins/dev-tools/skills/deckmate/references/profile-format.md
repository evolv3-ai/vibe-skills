# Stream Deck Profile Format Reference

Detailed schema reference for Stream Deck `.streamDeckProfile` files. These are ZIP
archives containing manifest JSON files and button icons.

## Table of Contents

- [Root Manifest Schema](#root-manifest-schema)
- [Device Models](#device-models)
- [Page Manifest Schema](#page-manifest-schema)
- [Full Action Schema](#full-action-schema)
- [Open Action Settings](#open-action-settings)
- [Text Action Settings](#text-action-settings)
- [Website Action Settings](#website-action-settings)
- [Integration Definition Structure](#integration-definition-structure)
- [Integration Definition Schema](#integration-definition-schema)
- [TAC Leverage Points Reference](#tac-leverage-points-reference)

---

## Root Manifest Schema

`{UUID}.sdProfile/manifest.json`:

```json
{
  "Device": {
    "Model": "20GBD9901",
    "UUID": ""
  },
  "Name": "Profile Name",
  "Pages": {
    "Current": "page-uuid-here",
    "Pages": ["page-uuid-here", "another-page-uuid"]
  },
  "Version": "2.0"
}
```

## Device Models

| Model Code   | Device                         | Keys/Controls     |
|--------------|--------------------------------|-------------------|
| `20GBD9901`  | Stream Deck (standard)         | 15 keys           |
| `20GAT9901`  | Stream Deck Mini               | 6 keys            |
| `20GAV9901`  | Stream Deck XL                 | 32 keys           |
| `20GBA9901`  | Stream Deck +                  | 8 keys + 4 dials  |
| `20GAA9901`  | Stream Deck Mobile             | Variable          |

## Page Manifest Schema

`Profiles/{PAGE_ID}/manifest.json`:

```json
{
  "Controllers": [
    {
      "Type": "Keypad",
      "Actions": {
        "0,0": { /* Action at row 0, col 0 */ },
        "0,1": { /* Action at row 0, col 1 */ },
        "1,0": { /* Action at row 1, col 0 */ }
      }
    },
    {
      "Type": "Encoder",
      "Actions": {
        "0,0": { /* Dial 1 */ },
        "1,0": { /* Dial 2 */ }
      }
    }
  ]
}
```

## Full Action Schema

Each action in the `Actions` object:

```json
{
  "ActionID": "unique-uuid-here",
  "LinkedTitle": false,
  "Name": "Display Name",
  "Settings": {
    /* Action-specific settings */
  },
  "State": 0,
  "States": [
    {
      "Image": "Images/filename.png",
      "Title": "Button Label",
      "FontFamily": "",
      "FontSize": 12,
      "FontStyle": "",
      "FontUnderline": false,
      "ShowTitle": true,
      "TitleAlignment": "bottom",
      "TitleColor": "#ffffff",
      "OutlineThickness": 2
    }
  ],
  "UUID": "com.elgato.streamdeck.system.hotkey"
}
```

## Open Action Settings

```json
{
  "Settings": {
    "openInBrowser": false,
    "path": "/path/to/file/or/folder"
  }
}
```

## Text Action Settings

```json
{
  "Settings": {
    "text": "Text to type"
  }
}
```

## Website Action Settings

```json
{
  "Settings": {
    "openInBrowser": true,
    "url": "https://example.com"
  }
}
```

## Integration Definition Structure

For complex developer workflows, DeckMate uses Integration Definition files (JSON)
as blueprints. These are NOT native Stream Deck profiles but documentation/configuration
used to document integrations, generate scripts/snippets, and provide context for
manual setup.

```
streamdeck/
├── profiles/                    # Integration blueprints (NOT native profiles)
│   └── tac-lesson4-integrations.json
├── snippets/                    # Text content for Text actions
│   └── piter-framework.md
├── scripts/                     # Shell scripts for hotkey-triggered terminals
│   └── adw-plan-build.sh
└── vscode/
    └── snippets.code-snippets   # VSCode autocomplete snippets
```

## Integration Definition Schema

```json
{
  "name": "Integration Set Name",
  "description": "What this set provides",
  "version": "1.0.0",
  "source_lesson": "lessons/lesson-N.md",
  "buttons": [
    {
      "position": 0,
      "name": "Button Name",
      "icon": "emoji-hint",
      "type": "hotkey|text|open|website|script",
      "action": {
        /* Type-specific configuration */
      },
      "leverage_point": "TAC LP reference",
      "priority": "high|medium|low"
    }
  ],
  "snippets": [
    {
      "name": "Snippet Name",
      "file": "snippets/filename.ext",
      "trigger": "vscode-prefix"
    }
  ]
}
```

## TAC Leverage Points Reference

When creating integrations, tag them with the appropriate leverage point:

| LP | Name           | Stream Deck Use Case                    |
|----|----------------|-----------------------------------------|
| 1  | Context        | Open ai_docs/, load context files       |
| 2  | Model          | -                                       |
| 3  | Prompt         | Text injection of prompts               |
| 4  | Tools          | Launch Claude, terminal commands         |
| 5  | Standard Out   | Status posting scripts                  |
| 6  | Types          | Open type definition files              |
| 7  | Documentation  | Open docs folders                       |
| 8  | Tests          | Run test scripts                        |
| 9  | Architecture   | Navigate project structure              |
| 10 | Plans          | Open specs/, create plans               |
| 11 | Templates      | Inject slash commands                   |
| 12 | ADWs           | Launch ADW workflows                    |
