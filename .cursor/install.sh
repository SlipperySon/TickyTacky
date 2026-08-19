#!/usr/bin/env bash
# Tickytacky Cloud Agent — install phase.
# Idempotent, non-interactive setup of the runnable backend toolchain:
# Docker engine (nested-container friendly), the Supabase CLI, and psql.
# The Apple/SwiftUI clients require macOS/Xcode and cannot build on this Linux
# VM; the Supabase local stack is the piece that runs here.
set -euo pipefail

SUPABASE_VERSION="2.115.0"

log() { printf '\n\033[1;36m[install]\033[0m %s\n' "$*"; }

log "Ensuring apt system packages (docker.io, fuse-overlayfs, iptables, psql, jq)"
NEED_PKGS=()
for pkg in docker.io fuse-overlayfs iptables uidmap postgresql-client jq tmux; do
  dpkg -s "$pkg" >/dev/null 2>&1 || NEED_PKGS+=("$pkg")
done
if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  sudo apt-get update -y
  # --force-confold keeps existing conffiles so fuse3 does not prompt interactively.
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confold" "${NEED_PKGS[@]}"
fi

log "Selecting iptables-legacy backend (nested Docker networking)"
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1 || true

log "Writing Docker daemon config (fuse-overlayfs storage driver)"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "storage-driver": "fuse-overlayfs",
  "iptables": true,
  "ip6tables": false,
  "bridge": "docker0"
}
JSON

# Allow the ubuntu user to reach the Docker socket without sudo.
sudo groupadd -f docker
sudo usermod -aG docker "$(id -un)" || true

log "Ensuring Supabase CLI v${SUPABASE_VERSION}"
if ! command -v supabase >/dev/null 2>&1 || [ "$(supabase --version 2>/dev/null)" != "${SUPABASE_VERSION}" ]; then
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/supabase.tar.gz" \
    "https://github.com/supabase/cli/releases/download/v${SUPABASE_VERSION}/supabase_${SUPABASE_VERSION}_linux_amd64.tar.gz"
  tar -xzf "${tmpdir}/supabase.tar.gz" -C "${tmpdir}" supabase
  sudo install -m 0755 "${tmpdir}/supabase" /usr/local/bin/supabase
  rm -rf "${tmpdir}"
fi

log "Versions:"
docker --version
supabase --version
psql --version | head -1

log "install complete"
