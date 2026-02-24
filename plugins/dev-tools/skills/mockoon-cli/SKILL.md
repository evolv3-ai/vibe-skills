---
name: mockoon-cli
description: |
  Mockoon CLI for running mock REST APIs in CI/CD, Docker, and local development.
  Supports OpenAPI import/export, dynamic templating, proxy mode, and Dockerization.

  Use when: creating mock APIs, testing API integrations, CI/CD pipelines, Docker mock services,
  converting OpenAPI specs, generating fake data with Faker.js.
---

# Mockoon CLI

**Requires**: Node.js 18+

Lightweight CLI for deploying mock APIs anywhere. Accepts Mockoon data files or OpenAPI specifications.

---

## Installation

```bash
npm install -g @mockoon/cli
```

Verify:
```bash
mockoon-cli --version
```

---

## Quick Start

### Start a Mock Server

```bash
# From local file
mockoon-cli start --data ./api-mock.json

# From URL
mockoon-cli start --data https://example.com/mock-data.json

# With custom port
mockoon-cli start --data ./api-mock.json --port 3000

# Watch for changes (development)
mockoon-cli start --data ./api-mock.json --watch
```

### From OpenAPI Spec

```bash
# Import OpenAPI to Mockoon format
mockoon-cli import --input ./openapi.yaml --output ./mock-env.json

# Then start
mockoon-cli start --data ./mock-env.json
```

---

## Commands Reference

### start

Run mock API server(s).

```bash
mockoon-cli start --data <file> [options]
```

| Flag | Description |
|------|-------------|
| `-d, --data` | Path/URL to Mockoon or OpenAPI file(s) **[required]** |
| `-p, --port` | Override port(s) |
| `-l, --hostname` | Override hostname(s) |
| `-w, --watch` | Auto-restart on file changes |
| `-t, --log-transaction` | Log full HTTP transactions |
| `-X, --disable-log-to-file` | Disable file logging |
| `-e, --disable-routes` | Disable routes by UUID or path |
| `-c, --faker-locale` | Faker.js locale (e.g., 'en_GB') |
| `-s, --faker-seed` | Faker.js seed for reproducible data |
| `--disable-admin-api` | Disable admin API endpoint |
| `--disable-tls` | Disable TLS |
| `--env-vars-prefix` | Custom env var prefix (default: MOCKOON_) |
| `--public-base-url` | Base URL for callbacks |

**Examples:**

```bash
# Multiple environments
mockoon-cli start --data ./api1.json ./api2.json --port 3000 3001

# With Faker locale
mockoon-cli start --data ./api.json --faker-locale en_GB

# Disable specific routes
mockoon-cli start --data ./api.json --disable-routes users products

# Background process
mockoon-cli start --data ./api.json &
```

---

### import

Convert OpenAPI/Swagger to Mockoon format.

```bash
mockoon-cli import --input <file> --output <file> [options]
```

| Flag | Description |
|------|-------------|
| `-i, --input` | OpenAPI file path/URL |
| `-o, --output` | Output Mockoon JSON path |
| `-p, --prettify` | Format output JSON |

**Example:**

```bash
mockoon-cli import --input ./openapi.yaml --output ./mock-env.json --prettify
```

---

### export

Convert Mockoon to OpenAPI v3.

```bash
mockoon-cli export --input <file> --output <file> [options]
```

| Flag | Description |
|------|-------------|
| `-i, --input` | Mockoon file path/URL |
| `-o, --output` | Output OpenAPI file path |
| `-f, --format` | Output format: `json` or `yaml` |
| `-p, --prettify` | Format JSON output |

**Example:**

```bash
mockoon-cli export --input ./mock-env.json --output ./openapi.yaml --format yaml
```

---

### dockerize

Generate Dockerfile for containerized mocks.

```bash
mockoon-cli dockerize --data <file> --output <file> [options]
```

| Flag | Description |
|------|-------------|
| `-d, --data` | Mockoon file path(s) |
| `-p, --port` | Port(s) to expose |
| `-o, --output` | Dockerfile output path |
| `-t, --log-transaction` | Enable transaction logging |

**Example:**

```bash
mockoon-cli dockerize --data ./api.json --port 3000 --output ./Dockerfile
docker build -t my-mock-api .
docker run -d -p 3000:3000 my-mock-api
```

---

### validate

Validate Mockoon environment files.

```bash
mockoon-cli validate --data <files...>
```

**Example:**

```bash
mockoon-cli validate --data ./api1.json ./api2.json
```

---

## Docker Usage

### Generic Image

```bash
docker run -d -p 3000:3000 mockoon/cli:latest \
  --data https://example.com/mock-data.json --port 3000
```

### With Local File

```bash
docker run -d -p 3000:3000 \
  --mount type=bind,source=$(pwd)/mock-data.json,target=/data/mock.json,readonly \
  mockoon/cli:latest --data /data/mock.json --port 3000
```

### Docker Compose

```yaml
version: '3.8'
services:
  mock-api:
    image: mockoon/cli:latest
    command: --data /data/mock.json --port 3000
    ports:
      - "3000:3000"
    volumes:
      - ./mock-data.json:/data/mock.json:ro
```

---

## Environment Variables

Access env vars in responses using templating:

```handlebars
{{getEnvVar 'API_KEY'}}
```

**Prefix**: Variables must start with `MOCKOON_` by default.

```bash
# Set env var
export MOCKOON_API_KEY=secret123

# Start with custom prefix
mockoon-cli start --data ./api.json --env-vars-prefix MY_APP_
```

---

## Admin API

Enabled by default at `/mockoon-admin/`.

**Endpoints:**
- `GET /mockoon-admin/logs` - Transaction logs
- `GET /mockoon-admin/state` - Environment state
- `POST /mockoon-admin/state` - Update state
- `PURGE /mockoon-admin/state` - Reset state

Disable with `--disable-admin-api`.

---

## Faker.js Templating

Generate dynamic fake data in responses:

```json
{
  "body": "{ \"name\": \"{{faker 'person.firstName'}}\", \"email\": \"{{faker 'internet.email'}}\" }"
}
```

**Set locale:**
```bash
mockoon-cli start --data ./api.json --faker-locale de
```

**Reproducible data:**
```bash
mockoon-cli start --data ./api.json --faker-seed 12345
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Run Mock API
  uses: mockoon/cli-action@v2
  with:
    version: 'latest'
    data-file: './mock-data.json'
    port: 3000
```

### GitLab CI

```yaml
mock-api:
  image: mockoon/cli:latest
  script:
    - mockoon-cli start --data ./mock-data.json --port 3000 &
    - sleep 5
    - curl http://localhost:3000/api/health
```

---

## Common Patterns

### Development with Watch Mode

```bash
mockoon-cli start --data ./api.json --watch --log-transaction
```

### Multiple APIs

```bash
mockoon-cli start \
  --data ./users-api.json ./orders-api.json \
  --port 3001 3002
```

### Cloud-Hosted Environments

```bash
mockoon-cli start --data cloud://{UUID} --token {API_TOKEN}
```

---

## Logs

Default log location: `~/.mockoon-cli/logs/{environment-name}.log`

Also outputs to stdout for container compatibility.
