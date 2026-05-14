# easy-vless 🌐

Automatic installation of **VLESS Reality (Docker)** on your server. Tested on Debian 12 / Ubuntu 22.04+.

The script is idempotent, so you can run it multiple times: the previous container and old configs will be removed, then everything will be rebuilt from scratch with new keys and parameters.

## Architecture

```text
Internet
  │
  └── :2443 ──→ Docker vless-reality
                   └── VLESS + Reality + XTLS-Vision
```

The script starts a single `vless-reality` container, exposes it on port `2443/tcp`, generates new keys, and saves a ready-to-import connection link.

## What gets installed

| Service | Container | Internal Port | Public Port | Purpose |
|---|---|---:|---:|---|
| VLESS Reality | `vless-reality` | `8443` | `2443` | Main connection |
| Monitoring | `vpnmon` | — | — | tmux windows with logs and status |

## Usage

Run as root:

```bash
bash install-easy-vless.sh
```

After installation, the credentials are saved to:

```bash
/root/vless-credentials.txt
```

File permissions are set to `600`.

## What does the script do?

- Removes the old `vless-reality` installation if it already exists;
- Updates packages and installs dependencies;
- Installs Docker;
- Generates the Reality private key and public key, client UUID, and shortId;
- Creates the Xray config at `/opt/vless/config.json`;
- Starts the `vless-reality` container;
- Opens the required port in UFW;
- Creates the `vpnmon` command for quick monitoring.

## Configuration

At the beginning of the script, you can change the parameters to fit your needs:

```bash
APP_NAME="easy vless"
VLESS_SNI="dl.google.com"

VLESS_INTERNAL_PORT=8443
VLESS_PUBLIC_PORT=2443
CONFIG_DIR="/opt/vless"
CONFIG_FILE="/opt/vless/config.json"
CREDS_FILE="/root/vless-credentials.txt"
```

## Installation result

At the end of the installation, the script outputs:

- server IP;
- connection port;
- SNI;
- UUID;
- public key;
- shortId;
- a ready-to-import `vless://...` client link.

Example link:

```text
vless://UUID@IP:2443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=dl.google.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp#easy-vless
```

## Monitoring

```bash
vpnmon
```

This command opens a tmux session with the following windows:

- `htop`
- `vless` — logs of the `vless-reality` container
- `ports` — check of listening ports

## Firewall (UFW)

The script automatically configures UFW and opens only the required incoming ports.

| Port | Protocol | Purpose |
|---|---|---|
| 22 | TCP | SSH |
| 2443 | TCP | VLESS Reality |

All other incoming connections are blocked by the UFW policy if it is enabled.

## Re-running the script

The script is safe to run multiple times. Before a new installation, it:

- stops and removes the `vless-reality` container;
- disables the old `xray` systemd service if it remains from previous installations;
- removes the old `/opt/vless` directory;
- recreates the config and keys from scratch;
- starts a new container with a fresh set of parameters.

## Repository structure

```text
vpn-setup/
├── install-easy-vless.sh   — main installation script
├── README.md               — documentation
└── .gitignore              — exclusions for sensitive files
```

## ‼️ Important ‼️

The `/root/vless-credentials.txt` file contains sensitive connection data.

Do not add it to the repository, do not send it in public chats, and do not store it openly in git.
