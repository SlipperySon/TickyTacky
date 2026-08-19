#!/usr/bin/env bash
# Tickytacky Cloud Agent — start phase (runs on every boot).
# Brings up the Docker daemon (nested VM) and the local Supabase stack, then
# returns once the API gateway is reachable. Safe to re-run: an already-running
# daemon or stack is detected and reused.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERD_LOG="/tmp/dockerd.log"

log() { printf '\n\033[1;35m[start]\033[0m %s\n' "$*"; }

log "Ensuring Docker daemon is running"
if ! docker info >/dev/null 2>&1; then
  # Launch dockerd inside a detached tmux session so the daemon persists
  # independently of this start script (which returns once services are up).
  sudo rm -f /var/run/docker.pid
  if ! tmux has-session -t tickytacky-dockerd 2>/dev/null; then
    tmux new-session -d -s tickytacky-dockerd "sudo dockerd >>'${DOCKERD_LOG}' 2>&1"
  fi
  for i in $(seq 1 60); do
    if sudo docker info >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if ! sudo docker info >/dev/null 2>&1; then
    echo "dockerd failed to start; last log lines:" >&2
    tail -n 40 "${DOCKERD_LOG}" >&2 || true
    exit 1
  fi
fi

# Make the Docker socket usable by the current user without sudo.
sudo chmod 666 /var/run/docker.sock || true

log "Starting local Supabase stack"
cd "${REPO_ROOT}"
if supabase status >/dev/null 2>&1; then
  log "Supabase already running"
else
  supabase start
fi

log "Waiting for Supabase API gateway"
for i in $(seq 1 60); do
  if curl -fsS -o /dev/null "http://127.0.0.1:54321/auth/v1/health"; then
    log "Supabase API is healthy"
    break
  fi
  sleep 2
done

supabase status || true
log "start complete"
