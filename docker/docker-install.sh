#!/usr/bin/env bash
set -euo pipefail

# Install Docker CE from the official upstream repo.
# Supports Debian/Ubuntu (apt) and RHEL/Fedora (dnf).

if [[ $EUID -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed: $(docker --version)"
    exit 0
fi

. /etc/os-release

if command -v apt >/dev/null 2>&1; then
    case "$ID" in
        ubuntu|debian) distro="$ID" ;;
        *) echo "Unsupported apt distro: $ID" >&2; exit 1 ;;
    esac

    apt update
    apt install -y ca-certificates curl gnupg

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${distro}/gpg" \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${distro} ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin

elif command -v dnf >/dev/null 2>&1; then
    case "$ID" in
        fedora) repo_url="https://download.docker.com/linux/fedora/docker-ce.repo" ;;
        rhel|centos|rocky|almalinux)
            repo_url="https://download.docker.com/linux/centos/docker-ce.repo" ;;
        *) echo "Unsupported dnf distro: $ID" >&2; exit 1 ;;
    esac

    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo "$repo_url"
    dnf install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin
else
    echo "Error: no supported package manager (apt/dnf)." >&2
    exit 1
fi

systemctl enable --now docker

# Add invoking sudo user to docker group
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    usermod -aG docker "$SUDO_USER"
    echo "Added ${SUDO_USER} to the docker group — log out/in for it to take effect."
fi

docker --version
docker compose version
