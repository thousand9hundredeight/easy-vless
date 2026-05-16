# easy-vless 🌐

Automatic idempotent installation of **VLESS Reality (Docker + Xray‑core)** on your server, with optional **3X‑UI web panel** and **built‑in monitoring**.

Tested on Debian 12 / Ubuntu 22.04+.

The set of scripts is **idempotent**: you can run `easy-install.sh` multiple times. On each run the previous VLESS installation is removed and the container is recreated with new keys and parameters, without touching other services (such as MTProto via your nginx on `:443`).

## Architecture

```text
Internet
  │
  └── :1443 ──→ Docker vless-reality
                    └── VLESS + Reality + XTLS‑Vision
```

- The main Xray‑core container `vless-reality` is published on a separate port, e.g. `1443/tcp` (or `2443/tcp`), so that it does not conflict with nginx serving MTProto on `:443` [web:417][web:421].
- nginx is used **only for MTProto** and does not participate in VLESS traffic in this setup.
- External client → your VLESS Reality link → `vless-reality` → services.

## What you get after installation

| Component | Description | Example ports |
|---|---|---|
| VLESS Reality | Main VPN tunnel | `8443` inside, `1443` outside |
| 3X‑UI (opt.) | Web UI for Xray management | `:20870` |
| vpnmon | tmux‑based monitoring | inside container |

At the end, a ready‑to‑import `vless://...` client link is generated and saved to `/root/vless-credentials.txt` [web:140][web:415].

## Repository structure

```bash
easy-vless/
├── easy-install.sh     — main orchestrator
├── base.sh             — base setup (apt, Docker, UFW, deps)
├── vless.sh            — VLESS Reality setup (container, keys, config.json)
├── rotate-sni.sh       — monthly SNI rotation
├── vpnmon.sh           — monitoring helper (tmux, logs, htop)
├── .env                — configuration (non‑secret parameters)
├── README.md
└── optional-3xui       — 3X‑UI panel installer (optional)
```

- Scripts do not touch each other’s logic; they only read configuration from `.env` and from the top of `easy-install.sh` [web:113].
- You can run them individually if needed, e.g.:
  ```bash
  ./vless.sh
  ```

## Rotate SNI (monthly)

Script `rotate-sni.sh` changes the Reality `SNI` once per month and recreates the container with new keys:

```bash
chmod +x rotate-sni.sh
./rotate-sni.sh
```

You can run it manually or via cron:

```bash
0 0 1 * * /root/easy-vless/rotate-sni.sh
```

## Configuration via .env

All non‑secret configuration is stored in `.env` next to `easy-install.sh`.  
Create it from the example:

```bash
cp env.example .env
nano .env
```

Set these variables:

- `CONTAINER_NAME="vless-reality"`
- `IMAGE_NAME="ghcr.io/xtls/xray-core:latest"`
- `VLESS_SNI="dl.google.com"`
- `VLESS_INTERNAL_PORT=8443`
- `VLESS_PUBLIC_PORT=1443` (or `2443` – no conflict with nginx:443)
- `CONFIG_DIR="/opt/vless"`
- `CONFIG_FILE="/opt/vless/config.json"`
- `CREDS_FILE="/root/vless-credentials.txt"`
- `VLESS_USE_NGINX=false` (if nginx here is only for MTProto)
- `VLESS_INSTALL_3X_UI=true` (or `false` – as desired)

Then run:

```bash
sudo ./easy-install.sh
```

All helper scripts (`base.sh`, `vless.sh`, `rotate-sni.sh`, `vpnmon.sh`, `optional-3xui`) will read the same values from `.env` [web:113][web:415].

## Deploy on a VPS

1. Clone the repo:

   ```bash
   git clone https://github.com/yourname/easy-vless.git
   cd easy-vless
   ```

2. Make scripts executable and run as root:

   ```bash
   chmod +x easy-install.sh base.sh vless.sh rotate-sni.sh vpnmon.sh optional-3xui
   sudo ./easy-install.sh
   ```

   The script:
   - Installs required packages, Docker, UFW;
   - Generates fresh Reality key, UUID, and short ID;
   - Starts the `vless-reality` container on `VLESS_PUBLIC_PORT` (e.g., `1443`);
   - If `VLESS_INSTALL_3X_UI=true`, runs the 3X‑UI installer.

3. Credentials and link:

   ```bash
   /root/vless-credentials.txt
   ```

   File permissions are set to `600` for security [web:140].

4. 3X‑UI (if enabled):

   After installation, the panel is available at:

   ```text
   https://YOUR_SERVER_IP:20870
   ```

   Default login: `admin`, password is shown on screen.  
   Immediately change both in `/etc/3x-ui/config.json`.

5. Monitoring:

   ```bash
   vpnmon
   ```

   Opens a tmux session with:
   - `htop` (system resource usage),
   - `vless` (Docker logs for `vless-reality`),
   - `ports` (listening ports) [web:415].

## Installation output

After a successful run, the script prints:

- Server IP;
- `VLESS_PUBLIC_PORT` (e.g., `1443`);
- `VLESS_SNI` (e.g., `dl.google.com`);
- UUID;
- Reality public key;
- `VLESS_SHORT_ID`;
- a ready‑to‑import `vless://...` client link.

Example link:

```text
vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=dl.google.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp#easy-vless
```

This is the only string you need to import into a VLESS‑Reality‑compatible client (Android/iOS/desktop) [web:140].

## Re‑running the script and updates

The orchestrator `easy-install.sh` can be run multiple times:

- It stops and removes `vless-reality`, then recreates the container with updated keys and parameters.
- It does not touch your nginx‑based MTProto setup, other running containers, or `vpnmon` tmux sessions, unless their own helper scripts are re‑run [web:424].

## Security

- `vless-credentials.txt` contains UUID, public key, short ID, and the full `vless://...` link.  
  Do not commit it to Git or share it in public channels.
- Use `rotate-sni.sh` monthly to rotate keys and Short IDs.

## Important: VLESS and MTProto on the same server

- nginx on port `443` serves **MTProto only** and is not part of the VLESS‑traffic chain (`VLESS_USE_NGINX=false`).
- VLESS‑Reality listens on a different external port (`1443` or `2443`) so it does not conflict with nginx.
- If you later want to place nginx as a TLS‑proxy in front of VLESS, that can be done separately, but this README focuses on the “clean” setup where nginx stays dedicated to MTProto [web:418][web:419].
