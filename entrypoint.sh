#!/bin/bash
set -e

# Unlock the dev account (handles images built without passwd -d)
passwd -d dev 2>/dev/null || true

# Set up SSH authorized keys from environment variable
if [ -n "$SSH_PUBLIC_KEY" ]; then
    mkdir -p /home/dev/.ssh
    echo "$SSH_PUBLIC_KEY" > /home/dev/.ssh/authorized_keys
    chmod 700 /home/dev/.ssh
    chmod 600 /home/dev/.ssh/authorized_keys
    chown -R dev:dev /home/dev/.ssh
    echo "[entrypoint] SSH public key configured for dev user"
else
    echo "[entrypoint] WARNING: SSH_PUBLIC_KEY is not set — SSH login will not work"
fi

# Regenerate host keys if missing (e.g. fresh container)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[entrypoint] Generating SSH host keys..."
    ssh-keygen -A
fi

# Ensure /nix is initialised (volume mount may be empty on first run)
# The Nix single-user install puts the store under /nix — if the volume
# was just mounted, restore the Nix profile symlinks from the image layer.
if [ ! -d /nix/store ] || [ -z "$(ls -A /nix/store 2>/dev/null)" ]; then
    echo "[entrypoint] /nix/store is empty — installing Nix into volume..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
        sh -s -- install linux --no-confirm --init none
    echo "[entrypoint] Nix installed successfully"
elif [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    echo "[entrypoint] Nix store found on volume"
fi

# Ensure nix config has flakes enabled
mkdir -p /etc/nix
grep -q 'experimental-features' /etc/nix/nix.conf 2>/dev/null || \
    echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf
grep -q 'sandbox = false' /etc/nix/nix.conf 2>/dev/null || \
    echo 'sandbox = false' >> /etc/nix/nix.conf

echo "[entrypoint] Starting sshd..."
exec /usr/sbin/sshd -D -e
