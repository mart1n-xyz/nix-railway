FROM debian:bookworm-slim

# Install base system packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    htop \
    tmux \
    vim \
    neovim \
    openssh-server \
    sudo \
    xz-utils \
    ca-certificates \
    gnupg \
    procps \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create dev user with sudo access
RUN useradd -m -s /bin/bash -G sudo dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Nix (single-user mode, runs as root — simpler in containers)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Add Nix to PATH for all users and enable flakes
ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
RUN mkdir -p /etc/nix && echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf && \
    echo 'sandbox = false' >> /etc/nix/nix.conf

# Make Nix available to dev user too
RUN echo '. /root/.nix-profile/etc/profile.d/nix.sh' >> /home/dev/.bashrc && \
    echo 'export PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH' >> /home/dev/.bashrc && \
    echo 'export NIX_PATH=nixpkgs=/root/.nix-defexpr/channels/nixpkgs' >> /home/dev/.bashrc

# Configure sshd
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config

# SSH host keys (generated at build time; runtime entrypoint regenerates if missing)
RUN ssh-keygen -A

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# /nix will be a Railway volume — create the mount point
RUN mkdir -p /nix

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
