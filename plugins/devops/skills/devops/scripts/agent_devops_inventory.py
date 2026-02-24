# agent_devops_inventory.py
# Agent DevOps Inventory v1 - Python Parser/Validator
# See: https://github.com/jezweb/claude-skills/skills/server-admin

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any


ProviderType = str  # e.g. "oci", "hetzner", "local_network"
ConnectVia = str    # e.g. "local", "ssh"


@dataclass
class Provider:
    name: str
    type: Optional[ProviderType] = None
    auth_method: Optional[str] = None
    auth_file: Optional[str] = None
    default_region: Optional[str] = None
    label: Optional[str] = None
    notes: Optional[str] = None
    extra: Dict[str, str] = field(default_factory=dict)


@dataclass
class Server:
    id: str
    provider: Optional[str] = None
    kind: Optional[str] = None
    name: Optional[str] = None
    connect_via: Optional[ConnectVia] = None
    env: Optional[str] = None
    os: Optional[str] = None
    role: Optional[str] = None
    status: Optional[str] = None
    tags: List[str] = field(default_factory=list)
    host: Optional[str] = None
    port: Optional[int] = None
    user: Optional[str] = None
    ssh_key_path: Optional[str] = None
    notes: Optional[str] = None
    extra: Dict[str, Any] = field(default_factory=dict)


@dataclass
class InventoryMetadata:
    version: str = "1"
    project: Optional[str] = None
    owner: Optional[str] = None
    notes: Optional[str] = None
    extra: Dict[str, str] = field(default_factory=dict)


@dataclass
class Inventory:
    metadata: InventoryMetadata
    providers: Dict[str, Provider]
    servers: Dict[str, Server]


@dataclass
class ValidationError:
    scope: str  # "provider" | "server" | "file"
    id: Optional[str]
    message: str


def parse_env_text(text: str) -> Dict[str, str]:
    """
    Parse a .env-style text into a dict of key -> value.
    """
    env: Dict[str, str] = {}

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if "=" not in line:
            # ignore malformed lines for now
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if not key:
            continue

        env[key] = value

    return env


def build_inventory(env: Dict[str, str]) -> Tuple[Inventory, List[ValidationError]]:
    providers: Dict[str, Provider] = {}
    servers: Dict[str, Server] = {}
    errors: List[ValidationError] = []

    version = env.get("AGENT_DEVOPS_VERSION", "1")
    metadata = InventoryMetadata(
        version=version,
        project=env.get("AGENT_DEVOPS_PROJECT"),
        owner=env.get("AGENT_DEVOPS_OWNER"),
        notes=env.get("AGENT_DEVOPS_NOTES"),
    )

    # Extra metadata keys
    for key, value in env.items():
        if key.startswith("AGENT_DEVOPS_") and key not in {
            "AGENT_DEVOPS_VERSION",
            "AGENT_DEVOPS_PROJECT",
            "AGENT_DEVOPS_OWNER",
            "AGENT_DEVOPS_NOTES",
        }:
            metadata.extra[key] = value

    # Providers
    for key, value in env.items():
        if not key.startswith("PROVIDER_"):
            continue
        parts = key.split("_")
        if len(parts) < 3:
            continue  # malformed

        name = parts[1]
        field_name = "_".join(parts[2:])

        provider = providers.get(name)
        if provider is None:
            provider = Provider(name=name)
            providers[name] = provider

        if field_name == "TYPE":
            provider.type = value
        elif field_name == "AUTH_METHOD":
            provider.auth_method = value
        elif field_name == "AUTH_FILE":
            provider.auth_file = value
        elif field_name == "DEFAULT_REGION":
            provider.default_region = value
        elif field_name == "LABEL":
            provider.label = value
        elif field_name == "NOTES":
            provider.notes = value
        else:
            provider.extra[field_name] = value

    # Servers
    for key, value in env.items():
        if not key.startswith("SERVER_"):
            continue
        parts = key.split("_")
        if len(parts) < 3:
            continue  # malformed

        server_id = parts[1]
        field_name = "_".join(parts[2:])

        server = servers.get(server_id)
        if server is None:
            server = Server(id=server_id)
            servers[server_id] = server

        if field_name == "PROVIDER":
            server.provider = value
        elif field_name == "KIND":
            server.kind = value
        elif field_name == "NAME":
            server.name = value
        elif field_name == "CONNECT_VIA":
            server.connect_via = value
        elif field_name == "ENV":
            server.env = value
        elif field_name == "OS":
            server.os = value
        elif field_name == "ROLE":
            server.role = value
        elif field_name == "STATUS":
            server.status = value
        elif field_name == "TAGS":
            tags = [t.strip() for t in value.split(",") if t.strip()]
            server.tags = tags
        elif field_name == "HOST":
            server.host = value
        elif field_name == "PORT":
            try:
                server.port = int(value)
            except ValueError:
                errors.append(
                    ValidationError(
                        scope="server",
                        id=server_id,
                        message=f"Invalid PORT for server {server_id}: {value!r}",
                    )
                )
        elif field_name == "USER":
            server.user = value
        elif field_name == "SSH_KEY_PATH":
            server.ssh_key_path = value
        elif field_name == "NOTES":
            server.notes = value
        else:
            server.extra[field_name] = value

    # Basic validation
    for name, provider in providers.items():
        if provider.type is None:
            errors.append(
                ValidationError(
                    scope="provider",
                    id=name,
                    message=f"Provider {name} is missing TYPE",
                )
            )

    for sid, server in servers.items():
        if server.provider is None:
            errors.append(
                ValidationError(
                    scope="server",
                    id=sid,
                    message=f"Server {sid} is missing PROVIDER",
                )
            )
        if server.kind is None:
            errors.append(
                ValidationError(
                    scope="server",
                    id=sid,
                    message=f"Server {sid} is missing KIND",
                )
            )
        if server.name is None:
            errors.append(
                ValidationError(
                    scope="server",
                    id=sid,
                    message=f"Server {sid} is missing NAME",
                )
            )
        if server.connect_via is None:
            errors.append(
                ValidationError(
                    scope="server",
                    id=sid,
                    message=f"Server {sid} is missing CONNECT_VIA",
                )
            )

    inventory = Inventory(
        metadata=metadata,
        providers=providers,
        servers=servers,
    )

    return inventory, errors


def parse_inventory_from_env(text: str) -> Tuple[Inventory, List[ValidationError]]:
    """
    Convenience function: parse inventory from a .env-style string.
    """
    env = parse_env_text(text)
    return build_inventory(env)


def find_servers(
    inventory: Inventory,
    env: Optional[str] = None,
    role: Optional[str] = None,
    provider: Optional[str] = None,
    status: Optional[str] = None,
    tag: Optional[str] = None,
) -> List[Server]:
    """
    Get servers matching specified criteria.
    """
    results = []
    for server in inventory.servers.values():
        if env and server.env != env:
            continue
        if role and server.role != role:
            continue
        if provider and server.provider != provider:
            continue
        if status and server.status != status:
            continue
        if tag and (not server.tags or tag not in server.tags):
            continue
        results.append(server)
    return results


def serialize_inventory(inventory: Inventory) -> str:
    """
    Generate inventory text from Inventory object.
    """
    lines: List[str] = []

    # Metadata
    lines.append("# =========================")
    lines.append("# METADATA")
    lines.append("# =========================")
    lines.append(f"AGENT_DEVOPS_VERSION={inventory.metadata.version}")
    if inventory.metadata.project:
        lines.append(f"AGENT_DEVOPS_PROJECT={inventory.metadata.project}")
    if inventory.metadata.owner:
        lines.append(f"AGENT_DEVOPS_OWNER={inventory.metadata.owner}")
    if inventory.metadata.notes:
        lines.append(f"AGENT_DEVOPS_NOTES={inventory.metadata.notes}")
    lines.append("")

    # Providers
    lines.append("# =========================")
    lines.append("# PROVIDERS")
    lines.append("# =========================")
    for provider in inventory.providers.values():
        lines.append("")
        lines.append(f"# {provider.label or provider.name}")
        lines.append(f"PROVIDER_{provider.name}_TYPE={provider.type or 'other'}")
        if provider.auth_method:
            lines.append(f"PROVIDER_{provider.name}_AUTH_METHOD={provider.auth_method}")
        if provider.auth_file:
            lines.append(f"PROVIDER_{provider.name}_AUTH_FILE={provider.auth_file}")
        if provider.default_region:
            lines.append(f"PROVIDER_{provider.name}_DEFAULT_REGION={provider.default_region}")
        if provider.label:
            lines.append(f"PROVIDER_{provider.name}_LABEL={provider.label}")
        if provider.notes:
            lines.append(f"PROVIDER_{provider.name}_NOTES={provider.notes}")
    lines.append("")

    # Servers
    lines.append("# =========================")
    lines.append("# SERVERS / NODES")
    lines.append("# =========================")
    for server in inventory.servers.values():
        lines.append("")
        lines.append(f"# {server.name or server.id}")
        lines.append(f"SERVER_{server.id}_PROVIDER={server.provider or ''}")
        lines.append(f"SERVER_{server.id}_KIND={server.kind or ''}")
        lines.append(f"SERVER_{server.id}_NAME={server.name or ''}")
        lines.append(f"SERVER_{server.id}_CONNECT_VIA={server.connect_via or ''}")
        if server.host:
            lines.append(f"SERVER_{server.id}_HOST={server.host}")
        if server.port:
            lines.append(f"SERVER_{server.id}_PORT={server.port}")
        if server.user:
            lines.append(f"SERVER_{server.id}_USER={server.user}")
        if server.ssh_key_path:
            lines.append(f"SERVER_{server.id}_SSH_KEY_PATH={server.ssh_key_path}")
        if server.env:
            lines.append(f"SERVER_{server.id}_ENV={server.env}")
        if server.os:
            lines.append(f"SERVER_{server.id}_OS={server.os}")
        if server.role:
            lines.append(f"SERVER_{server.id}_ROLE={server.role}")
        if server.status:
            lines.append(f"SERVER_{server.id}_STATUS={server.status}")
        if server.tags:
            lines.append(f"SERVER_{server.id}_TAGS={','.join(server.tags)}")
        if server.notes:
            lines.append(f"SERVER_{server.id}_NOTES={server.notes}")

    return "\n".join(lines)


# Example usage:
# from agent_devops_inventory import parse_inventory_from_env
#
# with open(".agent-devops.env", "r", encoding="utf-8") as f:
#     text = f.read()
#
# inventory, errors = parse_inventory_from_env(text)
#
# if errors:
#     print("Validation errors:")
#     for e in errors:
#         print(f"- [{e.scope} {e.id}] {e.message}")
#
# print("Servers:", list(inventory.servers.keys()))
