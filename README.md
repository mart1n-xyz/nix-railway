# nix-railway

> **Disclaimer:** This is a personal, experimental hobby project. It is not an official Logos product. Not audited.

A general-purpose Nix development environment designed to run on [Railway](https://railway.app), primarily used for Logos/LEZ testing and builds.

Provides:
- Nix package manager (single-user) with flakes enabled
- SSH access via public key auth
- Persistent `/nix` store via a Railway volume
- Starter `flake.nix` with Rust nightly, Qt6, CMake, OpenSSL, protobuf, Node 20

---

## Deploy to Railway

### 1. Create a new Railway service

- Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub repo
- Select **KindaInsecureBot/nix-railway**
- Railway will detect `railway.toml` and build from the Dockerfile automatically

### 2. Set the SSH_PUBLIC_KEY environment variable

In the Railway service settings → Variables, add:

```
SSH_PUBLIC_KEY=ssh-ed25519 AAAA... you@host
```

Paste the full contents of your `~/.ssh/id_ed25519.pub` (or equivalent).

### 3. Add a volume for /nix

In the Railway service → Volumes, add a new volume mounted at `/nix`.
This persists the Nix store between deploys so you don't re-download everything on each restart.

### 4. Enable TCP proxy for SSH

Railway exposes TCP ports via its proxy. In the service settings → Networking, the `railway.toml` already declares port 22 as a TCP proxy. Railway will assign you a hostname and port like:

```
monorail.proxy.rlwy.net:12345
```

---

## SSH in

```bash
ssh dev@monorail.proxy.rlwy.net -p 12345
```

Replace the hostname and port with the values from your Railway service networking tab.

To make it convenient, add to `~/.ssh/config`:

```
Host nix-railway
    HostName monorail.proxy.rlwy.net
    Port 12345
    User dev
    IdentityFile ~/.ssh/id_ed25519
```

Then just:

```bash
ssh nix-railway
```

---

## Using Nix for builds

Once SSHed in, Nix is available immediately:

```bash
# Enter the Logos/LEZ dev shell (defined in flake.nix)
nix develop

# Or run a one-off tool
nix run nixpkgs#cowsay -- "hello from nix-railway"

# Search for packages
nix search nixpkgs qt6
```

---

## Adding packages

**Option A — add to `flake.nix`** (recommended for project-specific tools):

Edit `flake.nix`, add the package to `buildInputs`, then re-enter the shell:

```bash
nix develop
```

**Option B — ad-hoc nix-env** (for one-off global tools):

```bash
nix-env -iA nixpkgs.ripgrep
```

---

## Local testing with Docker Compose

```bash
# Build and start
SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" docker compose up --build -d

# SSH in on port 2222
ssh dev@localhost -p 2222

# Stop
docker compose down
```

The `nix-store` Docker volume mirrors Railway's `/nix` volume behaviour.

---

## Volume persistence

The `/nix` mount means:
- The Nix store survives redeploys and restarts
- First boot populates the store; subsequent boots are fast
- If you reset the volume, the store will be rebuilt from scratch on next start

---

## Repository structure

```
.
├── Dockerfile          # Debian Bookworm + Nix single-user + sshd
├── entrypoint.sh       # Sets SSH keys from env, starts sshd
├── railway.toml        # Railway build/deploy config + TCP proxy
├── docker-compose.yml  # Local testing
└── flake.nix           # Logos/LEZ dev shell (Rust, Qt6, CMake, etc.)
```
