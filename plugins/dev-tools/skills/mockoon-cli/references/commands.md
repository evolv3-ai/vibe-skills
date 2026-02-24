# Mockoon CLI Commands Reference

Quick reference for all CLI commands and flags.

---

## start

Run mock API server(s).

```bash
mockoon-cli start [OPTIONS]
```

| Flag | Short | Description | Required |
|------|-------|-------------|----------|
| `--data` | `-d` | Mockoon/OpenAPI file path(s) or URL(s) | Yes |
| `--port` | `-p` | Override environment port(s) | No |
| `--hostname` | `-l` | Override listening hostname(s) | No |
| `--watch` | `-w` | Auto-restart on file changes | No |
| `--log-transaction` | `-t` | Log full HTTP transactions | No |
| `--disable-log-to-file` | `-X` | Disable file logging | No |
| `--disable-routes` | `-e` | Disable routes by UUID/path | No |
| `--faker-locale` | `-c` | Faker.js locale (e.g., 'en_GB') | No |
| `--faker-seed` | `-s` | Faker.js seed for reproducible data | No |
| `--disable-admin-api` | | Disable admin API endpoint | No |
| `--disable-tls` | | Disable TLS | No |
| `--env-vars-prefix` | | Custom env var prefix | No |
| `--public-base-url` | | Base URL for callbacks | No |
| `--polling-interval` | | File watch interval (ms) | No |
| `--max-transaction-logs` | | Max log entries (default: 100) | No |
| `--token` | `-k` | Cloud environment access token | No |

---

## import

Convert OpenAPI/Swagger to Mockoon format.

```bash
mockoon-cli import [OPTIONS]
```

| Flag | Short | Description | Required |
|------|-------|-------------|----------|
| `--input` | `-i` | OpenAPI file path or URL | Yes |
| `--output` | `-o` | Output Mockoon JSON path | Yes |
| `--prettify` | `-p` | Format output JSON | No |

---

## export

Convert Mockoon to OpenAPI v3.

```bash
mockoon-cli export [OPTIONS]
```

| Flag | Short | Description | Required |
|------|-------|-------------|----------|
| `--input` | `-i` | Mockoon file path or URL | Yes |
| `--output` | `-o` | Output OpenAPI file path | Yes |
| `--format` | `-f` | Output format: json or yaml | No |
| `--prettify` | `-p` | Format JSON output | No |

---

## dockerize

Generate Dockerfile for containerized mocks.

```bash
mockoon-cli dockerize [OPTIONS]
```

| Flag | Short | Description | Required |
|------|-------|-------------|----------|
| `--data` | `-d` | Mockoon file path(s) | Yes |
| `--port` | `-p` | Port(s) to expose | No |
| `--output` | `-o` | Dockerfile output path | Yes |
| `--log-transaction` | `-t` | Enable transaction logging | No |

---

## validate

Validate Mockoon environment files.

```bash
mockoon-cli validate [OPTIONS]
```

| Flag | Short | Description | Required |
|------|-------|-------------|----------|
| `--data` | `-d` | Mockoon file path(s) to validate | Yes |

---

## help

Show help for commands.

```bash
mockoon-cli help [COMMAND]
mockoon-cli --help
mockoon-cli help --all
```

---

## Common Examples

```bash
# Basic start
mockoon-cli start --data ./api.json

# Development mode with watch
mockoon-cli start --data ./api.json --watch --log-transaction

# Multiple environments
mockoon-cli start --data ./api1.json ./api2.json --port 3001 3002

# From URL
mockoon-cli start --data https://example.com/mock.json

# Cloud environment
mockoon-cli start --data cloud://uuid --token TOKEN

# Import OpenAPI
mockoon-cli import --input ./openapi.yaml --output ./mock.json --prettify

# Export to OpenAPI
mockoon-cli export --input ./mock.json --output ./spec.yaml --format yaml

# Generate Dockerfile
mockoon-cli dockerize --data ./api.json --port 3000 --output ./Dockerfile

# Validate files
mockoon-cli validate --data ./api1.json ./api2.json

# Disable specific routes
mockoon-cli start --data ./api.json --disable-routes users orders

# Set Faker locale
mockoon-cli start --data ./api.json --faker-locale de --faker-seed 12345

# Custom env vars prefix
mockoon-cli start --data ./api.json --env-vars-prefix MY_APP_
```
