#!/usr/bin/env bash
set -euo pipefail

# --- Resolve server ---
server="${INPUT_SERVER:-${CELLAR_SERVER:-}}"

if [[ -z "$server" ]]; then
  echo "::error::server input (or CELLAR_SERVER env var) is required when configure-nix is true"
  exit 1
fi

# --- Resolve signing key ---
signing_key="${INPUT_SIGNING_KEY:-}"

if [[ -z "$signing_key" ]]; then
  echo "No signing-key input provided; fetching from server via cellarctl whoami..."
  if ! command -v cellarctl >/dev/null 2>&1; then
    echo "::error::signing-key input not set and cellarctl is not installed (cannot auto-fetch)"
    exit 1
  fi
  signing_key="$(cellarctl whoami | grep 'Signing key:' | awk '{print $NF}')"
  if [[ -z "$signing_key" ]]; then
    echo "::error::Failed to retrieve signing key from cellarctl whoami. Provide signing-key input or check CELLAR_TOKEN."
    exit 1
  fi
  echo "Auto-detected signing key from server"
fi

# --- Detect nix.conf location ---
nix_conf="/etc/nix/nix.conf"

if [[ ! -d /etc/nix ]]; then
  sudo mkdir -p /etc/nix
fi

# --- Append substituter config ---
echo "Configuring Nix to use cellar substituter: $server"

# Add running user as trusted (so extra-* is respected)
printf '\ntrusted-users = root %s\n' "$(whoami)" | sudo tee -a "$nix_conf" >/dev/null

printf 'extra-substituters = %s\n' "$server" | sudo tee -a "$nix_conf" >/dev/null
printf 'extra-trusted-public-keys = %s\n' "$signing_key" | sudo tee -a "$nix_conf" >/dev/null

echo "Nix configuration updated at $nix_conf"

# --- Restart nix-daemon to pick up new config ---
if command -v systemctl >/dev/null 2>&1 && systemctl is-active nix-daemon >/dev/null 2>&1; then
  echo "Restarting nix-daemon via systemctl..."
  sudo systemctl restart nix-daemon
elif [[ "$(uname)" == "Darwin" ]]; then
  if sudo launchctl list org.nixos.nix-daemon &>/dev/null; then
    echo "Restarting nix-daemon via launchctl (org.nixos.nix-daemon)..."
    sudo launchctl kickstart -k system/org.nixos.nix-daemon
  elif sudo launchctl list systems.determinate.nix-store &>/dev/null; then
    echo "Restarting nix-daemon via launchctl (systems.determinate.nix-store)..."
    sudo launchctl kickstart -k system/systems.determinate.nix-store
  fi
fi
