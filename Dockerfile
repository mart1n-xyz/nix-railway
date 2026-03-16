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
    passwd -d dev && \
    echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Nix via Determinate Systems installer (handles containers/root properly)
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
    sh -s -- install linux --no-confirm --init none

# Enable flakes and disable sandbox
RUN mkdir -p /etc/nix && \
    echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf && \
    echo 'sandbox = false' >> /etc/nix/nix.conf

# Add Nix to PATH
ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"

# Make Nix available to dev user
RUN echo 'export PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH' >> /home/dev/.bashrc

# Configure sshd
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config

# SSH host keys
RUN ssh-keygen -A

# Force rebuild of everything below this line
ARG CACHE_BUST=7

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
