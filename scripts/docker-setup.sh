#!/usr/bin/env bash
# docker-setup.sh — Install Docker CE on Ubuntu via official apt repository.
#
# WHY NOT NIX FOR DOCKER:
# pkgs.docker from nixpkgs is built for NixOS. On Ubuntu the systemd service
# integration is broken — docker.socket is missing and ExecStart paths are wrong.
# Docker CE from the official apt repo handles this correctly.
#
# Installs: docker-ce, docker-ce-cli, containerd.io,
#           docker-buildx-plugin, docker-compose-plugin
#
# Note: podman, buildah, skopeo, dive, crane, cosign, lazydocker are in Nix.
# Reference: https://docs.docker.com/engine/install/ubuntu/

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

if command -v docker &>/dev/null; then
  info "Docker already installed: $(docker --version)"
  exit 0
fi

info "Installing Docker CE on Ubuntu..."

# Remove conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
           podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg" 2>/dev/null || true
done

# Prerequisites
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Docker's GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install Docker CE
sudo apt-get update -y
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Enable daemon and add user to docker group
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

info "Docker CE installed and running."
warn "Log out and back in (or run 'newgrp docker') for group membership to take effect."
info "Test: newgrp docker && docker run --rm hello-world"
