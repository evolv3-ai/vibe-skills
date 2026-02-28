/**
 * Admin Vault - TypeScript utility for age-encrypted secrets
 *
 * Uses the age-encryption npm package to decrypt the admin vault.
 * Same key file (~/.age/key.txt) and vault format as the bash/PowerShell wrappers.
 *
 * Prerequisites:
 *   npm install age-encryption
 *
 * Usage:
 *   import { decryptVault, getSecret, listSecrets } from './admin-vault'
 *
 *   const secrets = await decryptVault()
 *   const token = secrets.get('HCLOUD_TOKEN')
 *
 *   // Or use convenience functions:
 *   const token = await getSecret('HCLOUD_TOKEN')
 *   const keys = await listSecrets()
 */

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Lazy import to avoid hard dependency when not using vault
let age: typeof import("age-encryption") | null = null;

async function loadAge() {
  if (!age) {
    try {
      age = await import("age-encryption");
    } catch {
      throw new Error(
        "age-encryption package not installed. Run: npm install age-encryption"
      );
    }
  }
  return age;
}

/** Resolve ADMIN_ROOT from satellite ~/.admin/.env */
async function resolveAdminRoot(): Promise<string> {
  if (process.env.ADMIN_ROOT) return process.env.ADMIN_ROOT;

  const satelliteEnv = join(homedir(), ".admin", ".env");
  if (existsSync(satelliteEnv)) {
    const content = await readFile(satelliteEnv, "utf-8");
    const match = content.match(/^ADMIN_ROOT=(.+)$/m);
    if (match) return match[1].trim();
  }

  return join(homedir(), ".admin");
}

/** Check if vault mode is enabled */
async function isVaultEnabled(): Promise<boolean> {
  if (process.env.ADMIN_VAULT === "enabled") return true;
  if (process.env.ADMIN_VAULT === "disabled") return false;

  const satelliteEnv = join(homedir(), ".admin", ".env");
  if (existsSync(satelliteEnv)) {
    const content = await readFile(satelliteEnv, "utf-8");
    const match = content.match(/^ADMIN_VAULT=(.+)$/m);
    if (match) return match[1].trim() === "enabled";
  }

  return false;
}

/** Parse .env format string into key-value Map */
function parseEnvString(content: string): Map<string, string> {
  const vars = new Map<string, string>();
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const eqIndex = trimmed.indexOf("=");
    if (eqIndex === -1) continue;

    const key = trimmed.substring(0, eqIndex).trim();
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;

    let value = trimmed.substring(eqIndex + 1).trim();
    // Strip surrounding quotes
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    vars.set(key, value);
  }
  return vars;
}

/**
 * Decrypt the admin vault and return all secrets as a Map.
 * Falls back to plaintext .env if vault is disabled.
 */
export async function decryptVault(): Promise<Map<string, string>> {
  const adminRoot = await resolveAdminRoot();
  const vaultEnabled = await isVaultEnabled();

  if (vaultEnabled) {
    const keyPath = join(homedir(), ".age", "key.txt");
    const vaultPath = join(adminRoot, "vault.age");

    if (!existsSync(keyPath)) {
      throw new Error(
        `Age key not found at ${keyPath}. Generate: age-keygen -o ~/.age/key.txt`
      );
    }
    if (!existsSync(vaultPath)) {
      throw new Error(
        `Vault not found at ${vaultPath}. Create: secrets --encrypt /path/to/.env`
      );
    }

    const ageLib = await loadAge();
    const identity = await readFile(keyPath, "utf-8");
    const ciphertext = await readFile(vaultPath);

    // Detect ASCII armor and decode if needed
    const vaultStr = ciphertext.toString("utf-8");
    let encrypted: Uint8Array;
    if (vaultStr.startsWith("-----BEGIN AGE ENCRYPTED FILE-----")) {
      encrypted = ageLib.armor.decode(vaultStr);
    } else {
      encrypted = new Uint8Array(ciphertext);
    }

    const d = new ageLib.Decrypter();
    d.addIdentity(identity.trim());
    const plaintext = await d.decrypt(encrypted, "text");

    return parseEnvString(plaintext);
  }

  // Fallback: plaintext .env
  const masterEnv = join(adminRoot, ".env");
  if (existsSync(masterEnv)) {
    const content = await readFile(masterEnv, "utf-8");
    return parseEnvString(content);
  }

  return new Map();
}

/** Get a single secret by key name */
export async function getSecret(name: string): Promise<string> {
  const secrets = await decryptVault();
  const value = secrets.get(name);
  if (value === undefined) {
    throw new Error(`Secret '${name}' not found in vault`);
  }
  return value;
}

/** List all secret key names */
export async function listSecrets(): Promise<string[]> {
  const secrets = await decryptVault();
  return Array.from(secrets.keys()).sort();
}

/** Export all secrets to process.env */
export async function exportSecrets(): Promise<number> {
  const secrets = await decryptVault();
  for (const [key, value] of secrets) {
    process.env[key] = value;
  }
  return secrets.size;
}
