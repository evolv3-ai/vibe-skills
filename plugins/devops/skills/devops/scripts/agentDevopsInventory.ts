// agentDevopsInventory.ts
// Agent DevOps Inventory v1 - TypeScript Parser/Validator
// See: https://github.com/jezweb/claude-skills/skills/server-admin

export type ProviderType =
  | "oci"
  | "hetzner"
  | "gcp"
  | "contabo"
  | "digitalocean"
  | "vultr"
  | "linode"
  | "local_network"
  | "other"
  | string;

export type ConnectVia = "local" | "ssh" | string;

export interface Provider {
  name: string; // e.g. "OCI"
  type?: ProviderType;
  authMethod?: string;
  authFile?: string;
  defaultRegion?: string;
  label?: string;
  notes?: string;
  // Additional arbitrary fields:
  [key: string]: string | undefined;
}

export interface Server {
  id: string; // e.g. "WEB01"
  provider?: string; // e.g. "OCI"
  kind?: string; // vm | physical | local_pc | ...
  name?: string;
  connectVia?: ConnectVia;
  env?: string;
  os?: string;
  role?: string;
  status?: string;
  tags?: string[]; // parsed from comma-separated list
  host?: string;
  port?: number;
  user?: string;
  sshKeyPath?: string;
  notes?: string;
  // Additional arbitrary fields:
  [key: string]: string | string[] | number | undefined;
}

export interface InventoryMetadata {
  version: string; // default "1" if missing
  project?: string;
  owner?: string;
  notes?: string;
  // raw map of other AGENT_DEVOPS_* keys:
  [key: string]: string | undefined;
}

export interface Inventory {
  metadata: InventoryMetadata;
  providers: Record<string, Provider>;
  servers: Record<string, Server>;
}

export interface ValidationError {
  scope: "provider" | "server" | "file";
  id?: string;
  message: string;
}

export interface ParseResult {
  inventory: Inventory;
  errors: ValidationError[];
}

/**
 * Parse a .env-style text into a raw key-value object.
 */
export function parseEnvText(text: string): Record<string, string> {
  const result: Record<string, string> = {};

  const lines = text.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const eqIndex = line.indexOf("=");
    if (eqIndex === -1) {
      // ignore malformed lines for now
      continue;
    }

    const key = line.slice(0, eqIndex).trim();
    const value = line.slice(eqIndex + 1).trim();
    if (!key) continue;

    result[key] = value;
  }

  return result;
}

/**
 * Build Inventory from a key-value map.
 */
export function buildInventory(env: Record<string, string>): ParseResult {
  const providers: Record<string, Provider> = {};
  const servers: Record<string, Server> = {};
  const errors: ValidationError[] = [];

  // Metadata
  const version = env["AGENT_DEVOPS_VERSION"] || "1";

  const metadata: InventoryMetadata = {
    version,
    project: env["AGENT_DEVOPS_PROJECT"],
    owner: env["AGENT_DEVOPS_OWNER"],
    notes: env["AGENT_DEVOPS_NOTES"],
  };

  // include other AGENT_DEVOPS_* keys
  for (const [key, value] of Object.entries(env)) {
    if (key.startsWith("AGENT_DEVOPS_") && !(key in metadata)) {
      (metadata as Record<string, string | undefined>)[key] = value;
    }
  }

  // Providers
  for (const [key, value] of Object.entries(env)) {
    if (!key.startsWith("PROVIDER_")) continue;

    const parts = key.split("_");
    if (parts.length < 3) continue; // malformed: PROVIDER_<NAME>_<FIELD>

    const name = parts[1]; // e.g. OCI
    const field = parts.slice(2).join("_"); // e.g. TYPE, DEFAULT_REGION

    if (!providers[name]) {
      providers[name] = { name };
    }

    const provider = providers[name];

    switch (field) {
      case "TYPE":
        provider.type = value as ProviderType;
        break;
      case "AUTH_METHOD":
        provider.authMethod = value;
        break;
      case "AUTH_FILE":
        provider.authFile = value;
        break;
      case "DEFAULT_REGION":
        provider.defaultRegion = value;
        break;
      case "LABEL":
        provider.label = value;
        break;
      case "NOTES":
        provider.notes = value;
        break;
      default:
        provider[field] = value;
        break;
    }
  }

  // Servers
  for (const [key, value] of Object.entries(env)) {
    if (!key.startsWith("SERVER_")) continue;

    const parts = key.split("_");
    if (parts.length < 3) continue; // malformed: SERVER_<ID>_<FIELD>

    const id = parts[1]; // e.g. WEB01
    const field = parts.slice(2).join("_"); // e.g. HOST, SSH_KEY_PATH

    if (!servers[id]) {
      servers[id] = { id };
    }

    const server = servers[id];

    switch (field) {
      case "PROVIDER":
        server.provider = value;
        break;
      case "KIND":
        server.kind = value;
        break;
      case "NAME":
        server.name = value;
        break;
      case "CONNECT_VIA":
        server.connectVia = value as ConnectVia;
        break;
      case "ENV":
        server.env = value;
        break;
      case "OS":
        server.os = value;
        break;
      case "ROLE":
        server.role = value;
        break;
      case "STATUS":
        server.status = value;
        break;
      case "TAGS":
        server.tags = value
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean);
        break;
      case "HOST":
        server.host = value;
        break;
      case "PORT": {
        const n = Number(value);
        if (!Number.isNaN(n)) {
          server.port = n;
        } else {
          errors.push({
            scope: "server",
            id,
            message: `Invalid PORT for server ${id}: "${value}"`,
          });
        }
        break;
      }
      case "USER":
        server.user = value;
        break;
      case "SSH_KEY_PATH":
        server.sshKeyPath = value;
        break;
      case "NOTES":
        server.notes = value;
        break;
      default:
        // Keep unknown fields as strings
        (server as Record<string, unknown>)[field] = value;
        break;
    }
  }

  // Basic validation
  for (const [name, provider] of Object.entries(providers)) {
    if (!provider.type) {
      errors.push({
        scope: "provider",
        id: name,
        message: `Provider ${name} is missing TYPE`,
      });
    }
  }

  for (const [id, server] of Object.entries(servers)) {
    if (!server.provider) {
      errors.push({
        scope: "server",
        id,
        message: `Server ${id} is missing PROVIDER`,
      });
    }
    if (!server.kind) {
      errors.push({
        scope: "server",
        id,
        message: `Server ${id} is missing KIND`,
      });
    }
    if (!server.name) {
      errors.push({
        scope: "server",
        id,
        message: `Server ${id} is missing NAME`,
      });
    }
    if (!server.connectVia) {
      errors.push({
        scope: "server",
        id,
        message: `Server ${id} is missing CONNECT_VIA`,
      });
    }
  }

  const inventory: Inventory = {
    metadata,
    providers,
    servers,
  };

  return { inventory, errors };
}

/**
 * Convenience function: parse inventory from a .env-style string.
 */
export function parseInventoryFromEnv(text: string): ParseResult {
  const env = parseEnvText(text);
  return buildInventory(env);
}

/**
 * Get servers matching specified criteria.
 */
export function findServers(
  inventory: Inventory,
  criteria: {
    env?: string;
    role?: string;
    provider?: string;
    status?: string;
    tag?: string;
  }
): Server[] {
  return Object.values(inventory.servers).filter((server) => {
    if (criteria.env && server.env !== criteria.env) return false;
    if (criteria.role && server.role !== criteria.role) return false;
    if (criteria.provider && server.provider !== criteria.provider) return false;
    if (criteria.status && server.status !== criteria.status) return false;
    if (criteria.tag && (!server.tags || !server.tags.includes(criteria.tag)))
      return false;
    return true;
  });
}

/**
 * Generate inventory text from Inventory object.
 */
export function serializeInventory(inventory: Inventory): string {
  const lines: string[] = [];

  // Metadata
  lines.push("# =========================");
  lines.push("# METADATA");
  lines.push("# =========================");
  lines.push(`AGENT_DEVOPS_VERSION=${inventory.metadata.version}`);
  if (inventory.metadata.project) {
    lines.push(`AGENT_DEVOPS_PROJECT=${inventory.metadata.project}`);
  }
  if (inventory.metadata.owner) {
    lines.push(`AGENT_DEVOPS_OWNER=${inventory.metadata.owner}`);
  }
  if (inventory.metadata.notes) {
    lines.push(`AGENT_DEVOPS_NOTES=${inventory.metadata.notes}`);
  }
  lines.push("");

  // Providers
  lines.push("# =========================");
  lines.push("# PROVIDERS");
  lines.push("# =========================");
  for (const provider of Object.values(inventory.providers)) {
    lines.push("");
    lines.push(`# ${provider.label || provider.name}`);
    lines.push(`PROVIDER_${provider.name}_TYPE=${provider.type || "other"}`);
    if (provider.authMethod) {
      lines.push(`PROVIDER_${provider.name}_AUTH_METHOD=${provider.authMethod}`);
    }
    if (provider.authFile) {
      lines.push(`PROVIDER_${provider.name}_AUTH_FILE=${provider.authFile}`);
    }
    if (provider.defaultRegion) {
      lines.push(
        `PROVIDER_${provider.name}_DEFAULT_REGION=${provider.defaultRegion}`
      );
    }
    if (provider.label) {
      lines.push(`PROVIDER_${provider.name}_LABEL=${provider.label}`);
    }
    if (provider.notes) {
      lines.push(`PROVIDER_${provider.name}_NOTES=${provider.notes}`);
    }
  }
  lines.push("");

  // Servers
  lines.push("# =========================");
  lines.push("# SERVERS / NODES");
  lines.push("# =========================");
  for (const server of Object.values(inventory.servers)) {
    lines.push("");
    lines.push(`# ${server.name || server.id}`);
    lines.push(`SERVER_${server.id}_PROVIDER=${server.provider || ""}`);
    lines.push(`SERVER_${server.id}_KIND=${server.kind || ""}`);
    lines.push(`SERVER_${server.id}_NAME=${server.name || ""}`);
    lines.push(`SERVER_${server.id}_CONNECT_VIA=${server.connectVia || ""}`);
    if (server.host) lines.push(`SERVER_${server.id}_HOST=${server.host}`);
    if (server.port) lines.push(`SERVER_${server.id}_PORT=${server.port}`);
    if (server.user) lines.push(`SERVER_${server.id}_USER=${server.user}`);
    if (server.sshKeyPath)
      lines.push(`SERVER_${server.id}_SSH_KEY_PATH=${server.sshKeyPath}`);
    if (server.env) lines.push(`SERVER_${server.id}_ENV=${server.env}`);
    if (server.os) lines.push(`SERVER_${server.id}_OS=${server.os}`);
    if (server.role) lines.push(`SERVER_${server.id}_ROLE=${server.role}`);
    if (server.status)
      lines.push(`SERVER_${server.id}_STATUS=${server.status}`);
    if (server.tags && server.tags.length > 0)
      lines.push(`SERVER_${server.id}_TAGS=${server.tags.join(",")}`);
    if (server.notes) lines.push(`SERVER_${server.id}_NOTES=${server.notes}`);
  }

  return lines.join("\n");
}

// Example usage:
// import { parseInventoryFromEnv } from "./agentDevopsInventory";
// import { readFileSync } from "fs";
//
// const text = readFileSync(".agent-devops.env", "utf8");
// const { inventory, errors } = parseInventoryFromEnv(text);
//
// if (errors.length) {
//   console.error("Inventory validation errors:", errors);
// }
//
// console.log("Servers:", Object.keys(inventory.servers));
