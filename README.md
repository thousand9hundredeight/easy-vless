# easy-vless 🌐

Automatic idempotent installation of **VLESS Reality (Docker + Xray‑core)** on your server, with optional **3X‑UI web panel** and **nginx TLS‑proxy**.  
Tested on Debian 12 / Ubuntu 22.04+.

The set of scripts is **idempotent**: you can run `easy-instll.sh` multiple times. On each run the old installation is removed and everything is rebuilt from scratch with new keys and parameters.

## Architecture

```text
Internet
  │
  └── :443 / :2443 ──→ Docker vless-reality
                         └── VLESS + Reality + XTLS‑Vision
                               │
                               └── [optional] nginx (TLS‑proxy)
```

- The main Xray‑core container `vless-reality` is exposed either on:
  - `:443/tcp` (recommended) or  
  - `:2443/tcp` (fallback).
- Optional `nginx` TLS‑proxy can sit in front of Xray and accept TLS‑443 traffic, keeping the VPS‑facing VLESS‑port hidden.
- External client → your VLESS Reality link → `vless-reality` → (optional) `nginx` → services.

## What gets installed

| Component | Container / Service | Internal Port | Public Port | Purpose |
|---|---|---:|---:|---|
| VLESS Reality | `vless-reality` Docker | `8443` | `443` or `2443` | Main VLESS+Reality+Vision VPN tunnel |
| TLS‑proxy (opt.) | `nginx` | `8443` | `443` | Optional TLS‑443 front‑end to Xray |
| UI‑panel (opt.) | 3X‑UI web UI | — | `:20870` (example) | Optional web panel for Xray (management, stats, logs) |
| Monitoring | `vpnmon` | — | — | tmux session with `htop`, VLESS logs, netstat |

At the end, a ready‑to‑import client link is generated and saved to `/root/vless-credentials.txt`.

## Directory structure

```bash
vless/
├── base.sh              — basic setup (apt, Docker, UFW, deps)
├── easy-instll.sh       — main orchestrator
├── nginx.sh             — nginx TLS‑proxy (optional)
├── rotate-sni.sh        — change SNI once per month
├── vless.sh             — VLESS Reality setup
├── vpnmon.sh            — tmux monitoring helper
├── .env                 — configuration (non‑secret parameters)
├── README.md
└── optional-3xui        — 3X‑UI panel installer (optional)
```

- None of these scripts ever touch the others’ logic; they only consume config from the beginning of `easy-instll.sh` and from `.env`.
- You can safely run them individually if needed (e.g. `./vless.sh` again after OS reinstall).

## Rotate SNI (monthly)

Script `rotate-sni.sh` changes the Reality `SNI` once per month and regenerates VLESS Reality keys:

```bash
chmod +x rotate-sni.sh
./rotate-sni.sh
```

This can be run manually or scheduled via `cron`:

```bash
0 0 1 * * /root/vless/rotate-sni.sh
```

## Configuration via env file

All non‑secret configuration is stored in `.env`.  
Edit or generate it:

```bash
cp env.example .env
nano .env
```

Edit the following variables:

- `VLESS_SNI`, `VLESS_INTERNAL_PORT`, `VLESS_PUBLIC_PORT`  
- `VLESS_USE_NGINX`, `VLESS_INSTALL_3X_UI`  
- `CONFIG_DIR`, `CONFIG_FILE`, `CREDS_FILE`

Then run:

```bash
./easy-instll.sh
```

All helper scripts (`base.sh`, `vless.sh`, `nginx.sh`, `vpnmon.sh`) will read the same `.env` values.

## Usage

1. Clone the repo on your VPS:

   ```bash
   git clone https://github.com/yourname/easy-vless.git
   cd easy-vless
   ```

2. Run the main installer as root:

   ```bash
   chmod +x ./easy-instll.sh
   ./easy-instll.sh
   ```

   This script:
   - Installs required packages, Docker, UFW;
   - Generates fresh Reality keys, UUID, and short ID;
   - Starts the `vless-reality` container;
   - Optionally:
     - sets up `nginx` TLS‑proxy if `VLESS_USE_NGINX=true`;
     - offers to install 3X‑UI admin panel if `VLESS_INSTALL_3X_UI=true`.

3. Credentials and link:

   ```bash
   /root/vless-credentials.txt
   ```

   File permissions are set to `600`.

4. Optional web UI (3X‑UI):

   - If you choose “y” during installation, the 3X‑UI panel is installed and available at:

     ```text
     https://YOUR_SERVER_IP:20870
     ```

     Default login: `admin` / initial password (shown during setup).  
     You should change both in `/etc/3x-ui/config.json`.

5. Optional monitoring:

   ```bash
   vpnmon
   ```

   Opens a tmux session with:
   - `htop` (VPS resources),
   - `vless` (Docker logs of `vless-reality`),
   - `ports` (listening ports).

## Installation result

After successful run, the script outputs:

- server IP;
- connection port (`VLESS_PUBLIC_PORT`);
- SNI (`VLESS_SNI`);
- client UUID;
- Reality public key;
- shortId (`VLESS_SHORT_ID`);
- a ready‑to‑import `vless://...` client link.

Example link:

```text
vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=dl.google.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp#easy-vless
```

This is the **only** information you need to connect with any VLESS Reality‑compatible client (Android/iOS/desktop).

## Optional TLS‑proxy (nginx)

If `VLESS_USE_NGINX=true`, `easy-instll.sh` will:

- Install `nginx`.
- Place a site config at `/etc/nginx/sites-available/vless-nginx.conf`.
- Hook it as enabled site.
- Restart nginx.

Traffic path:

- Client → `https://YOUR_SERVER_IP:443` → nginx → `http://127.0.0.1:8443` → `vless-reality`.

This makes it slightly harder for DPI‑systems to distinguish your VPS‑traffic from generic HTTPS sites.

## Optional 3X‑UI panel

If `VLESS_INSTALL_3X_UI=true`, `easy-instll.sh` will:

- Run the official 3X‑UI installer (`optional-3xui`).
- Output the panel URL and first‑time login credentials.

Features:
- Single‑user‑focused mode works fine (you are the only admin).
- You can:
  - view your VLESS‑Reality inbound;
  - see real‑time bandwidth, online clients (you);
  - change protocol modes, ports, TLS‑settings without editing `config.json` by hand.
- Still, the core Xray‑config (`/opt/vless/config.json`) remains the **single source of truth** — UI just reflects/controls it.

## Re‑running the script

The orchestrator `easy-instll.sh` is designed to be run multiple times:

- On each run it:
  - stops and removes the `vless-reality` container;
  - disables and cleans old Xray‑related services if present;
  - removes the old `/opt/vless` directory;
  - regenerates keys, config, and secrets;
  - restarts the container with fresh parameters.

This is safe even if you already have:
- `3x‑ui`,  
- `nginx`,  
- `vpnmon` tmux sessions.

They are **not touched** unless their own helper scripts are run again.

## Security and sensitive data

- The `/root/vless-credentials.txt` file contains:
  - UUID;
  - public key;
  - short ID;
  - the full `vless://...` link.

  File permissions are set to `600`.

- Do not:
  - commit `vless-credentials.txt` to Git;
  - send it via public chats;
  - store it on unencrypted cloud drives;
  - share it without rotating keys first.

- For corporate‑scale deployments consider:
  - Hashicorp Vault / another secret store for UUID and key management;
  - automatic key‑rotation scripts (per‑month) that regenerate `VLESS_PRIVATE_KEY`, `VLESS_PUBLIC_KEY`, `VLESS_UUID`, `VLESS_SHORT_ID` and restart the container.

## ‼️ Important for EU‑facing workloads

If you are using this setup for **EU‑facing workloads** (GDPR‑critical data, customer‑facing apps, etc.):

- All application traffic **on top of VLESS** should be:
  - HTTP over TLS (HTTPS),  
  - or properly TLS‑wrapped APIs;
- Use:
  - `nginx` TLS‑proxy (or equivalent) in front of your services,
  - with up‑to‑date certificates and HSTS.

That way, your VPS‑hoster can see:
- VLESS‑Reality TLS‑443‑like handshake,
- HTTPS‑to‑VPS traffic,
but not **application‑level** payloads without TLS‑decryption (which is hard to do without MITM‑cert and client trust).
