---
name: streamlit-snowflake
description: |
  Build and deploy Streamlit apps natively in Snowflake with production-ready templates. Covers project scaffolding (snowflake.yml, environment.yml), Snowpark session patterns, multi-page structure, and Marketplace publishing as Native Apps.

  Use when building data apps on Snowflake, deploying Streamlit in Snowflake (SiS), or publishing to Snowflake Marketplace. Prevents package channel errors, outdated Streamlit versions, and authentication issues.
license: MIT
metadata:
  version: "1.0.0"
  last_verified: "2025-12-24"
  snowflake_cli: ">=3.14.0"
  streamlit: "1.35.0"
  python: "3.11"
  keywords:
    - streamlit snowflake
    - streamlit in snowflake
    - SiS
    - snowflake native app
    - snowflake marketplace
    - snowpark streamlit
    - snow streamlit deploy
    - environment.yml snowflake
    - snowflake anaconda channel
---

# Streamlit in Snowflake Skill

Build and deploy Streamlit apps natively within Snowflake, including Marketplace publishing as Native Apps.

## Quick Start

### 1. Initialize Project

Copy the templates to your project:

```bash
# Create project directory
mkdir my-streamlit-app && cd my-streamlit-app

# Copy templates (Claude will provide these)
```

### 2. Configure snowflake.yml

Update placeholders in `snowflake.yml`:

```yaml
definition_version: 2
entities:
  my_app:
    type: streamlit
    identifier: my_streamlit_app        # ← Your app name
    stage: my_app_stage                 # ← Your stage name
    query_warehouse: my_warehouse       # ← Your warehouse
    main_file: streamlit_app.py
    pages_dir: pages/
    artifacts:
      - common/
      - environment.yml
```

### 3. Deploy

```bash
# Deploy to Snowflake
snow streamlit deploy --replace

# Open in browser
snow streamlit deploy --replace --open
```

## When to Use This Skill

**Use when:**
- Building data apps that run natively in Snowflake
- Need Snowpark integration for data access
- Publishing apps to Snowflake Marketplace
- Setting up CI/CD for Streamlit in Snowflake

**Don't use when:**
- Hosting Streamlit externally (use Streamlit Community Cloud)
- Building general Snowpark pipelines (use a Snowpark-specific skill)
- Need custom Streamlit components (not supported in SiS)

## Project Structure

```
my-streamlit-app/
├── snowflake.yml           # Project definition (required)
├── environment.yml         # Package dependencies (required)
├── streamlit_app.py        # Main entry point
├── pages/                  # Multi-page apps
│   └── data_explorer.py
├── common/                 # Shared utilities
│   └── utils.py
└── .gitignore
```

## Key Patterns

### Snowpark Session Connection

```python
import streamlit as st

# Get Snowpark session (native SiS connection)
conn = st.connection("snowflake")
session = conn.session()

# Query data
df = session.sql("SELECT * FROM my_table LIMIT 100").to_pandas()
st.dataframe(df)
```

### Caching Expensive Queries

```python
@st.cache_data(ttl=600)  # Cache for 10 minutes
def load_data(query: str):
    conn = st.connection("snowflake")
    return conn.session().sql(query).to_pandas()

# Use cached function
df = load_data("SELECT * FROM large_table")
```

### Environment Configuration

**environment.yml** (required format):

```yaml
name: sf_env
channels:
  - snowflake          # REQUIRED - only supported channel
dependencies:
  - streamlit=1.35.0   # Explicit version (default is old 1.22.0)
  - pandas
  - plotly
  - altair=4.0         # Version 4.0 supported in SiS
  - snowflake-snowpark-python
```

## Error Prevention

| Error | Cause | Prevention |
|-------|-------|------------|
| `PackageNotFoundError` | Using conda-forge or external channel | Always use `channels: - snowflake` only |
| Missing Streamlit features | Default version 1.22.0 | Explicitly set `streamlit=1.35.0` |
| `ROOT_LOCATION deprecated` | Old CLI syntax | Use Snowflake CLI 3.14.0+ with `FROM source_location` |
| Auth failures (2026+) | Password-only authentication | Use key-pair or OAuth (see references/authentication.md) |
| File upload fails | File >250MB | Keep files under 250MB limit |
| `page_title not supported` | SiS limitation | Don't use `st.set_page_config(page_title=...)` |
| Custom component error | SiS limitation | Custom Streamlit components not supported |

## Deployment Commands

### Basic Deployment

```bash
# Deploy and replace existing
snow streamlit deploy --replace

# Deploy and open in browser
snow streamlit deploy --replace --open

# Deploy specific entity (if multiple in snowflake.yml)
snow streamlit deploy my_app --replace
```

### CI/CD Deployment

See `references/ci-cd.md` for GitHub Actions workflow template.

## Marketplace Publishing (Native App)

To publish your Streamlit app to Snowflake Marketplace:

1. **Convert to Native App** - Use `templates-native-app/` templates
2. **Create Provider Profile** - Required for Marketplace listings
3. **Submit for Approval** - Snowflake reviews before publishing

See `templates-native-app/README.md` for complete workflow.

### Native App Structure

```
my-native-app/
├── manifest.yml            # Native App manifest
├── setup.sql               # Installation script
├── streamlit/
│   ├── environment.yml
│   ├── streamlit_app.py
│   └── pages/
└── README.md
```

## Package Availability

Only packages from the **Snowflake Anaconda Channel** are available:

```sql
-- Query available packages
SELECT * FROM information_schema.packages
WHERE language = 'python'
ORDER BY package_name;

-- Search for specific package
SELECT * FROM information_schema.packages
WHERE language = 'python'
AND package_name ILIKE '%plotly%';
```

**Common available packages:**
- pandas, numpy, scipy
- plotly, altair (4.0), matplotlib
- scikit-learn, xgboost
- snowflake-snowpark-python
- streamlit (1.22.0 default, 1.35.0 with explicit version)

**Not available:**
- Packages from conda-forge
- Custom/private packages
- Packages requiring native compilation

See: [Snowpark Python Packages Explorer](https://snowpark-python-packages.streamlit.app/)

## Known Limitations

1. **No custom Streamlit components** - Only built-in components work
2. **Package restrictions** - Only Snowflake Anaconda Channel
3. **No Azure Private Link / GCP Private Service Connect** for app access
4. **page_title and page_icon** not supported in `st.set_page_config()`
5. **File size limit** - 250MB per file
6. **Session timeout** - Apps may timeout after inactivity

## Authentication (Important - 2026 Deadline)

Password-only authentication is being deprecated:

| Milestone | Date | Requirement |
|-----------|------|-------------|
| Milestone 1 | Sept 2025 - Jan 2026 | MFA required for Snowsight users |
| Milestone 2 | May - July 2026 | All new users must use MFA |
| Milestone 3 | Aug - Oct 2026 | All users must use MFA or key-pair/OAuth |

**Recommended authentication methods:**
- Key-pair authentication (for service accounts)
- OAuth client credentials (for M2M)
- Workload Identity Federation (for cloud-native apps)

See `references/authentication.md` for implementation patterns.

## Resources

### Official Documentation
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Snowflake CLI Streamlit Commands](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/streamlit-commands/overview)
- [Native Apps with Streamlit](https://docs.snowflake.com/en/developer-guide/native-apps/adding-streamlit)
- [Marketplace Publishing](https://docs.snowflake.com/en/developer-guide/native-apps/publish-guidelines)

### Examples
- [snowflake-demo-streamlit](https://github.com/Snowflake-Labs/snowflake-demo-streamlit)
- [native-apps-templates](https://github.com/snowflakedb/native-apps-templates)
- [GitLab's Streamlit Framework](https://about.gitlab.com/blog/how-we-built-a-structured-streamlit-application-framework-in-snowflake/)

### Tools
- [Snowpark Python Packages Explorer](https://snowpark-python-packages.streamlit.app/)
- [Snowflake MCP Server](https://github.com/Snowflake-Labs/mcp) (for Claude integration)
