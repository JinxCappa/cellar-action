#!/usr/bin/env bash
set -euo pipefail

REPO="JinxCappa/cellar"

# --- Auth header for GitHub API/downloads (avoids rate limits) ---
auth_header=""
if [[ -n "${GH_TOKEN:-}" ]]; then
  auth_header="Authorization: token $GH_TOKEN"
fi

# --- Resolve version ---
version="${INPUT_VERSION}"
if [[ "$version" == "latest" ]]; then
  version="$(curl -sf ${auth_header:+-H "$auth_header"} \
    "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
  if [[ -z "$version" ]]; then
    echo "::error::Failed to resolve latest version from GitHub API (rate-limited or network error)"
    exit 1
  fi
  echo "Resolved latest version: $version"
fi

# --- Map OS/arch to target triple ---
os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)
    case "$arch" in
      x86_64)  target="x86_64-unknown-linux-musl" ;;
      aarch64) target="aarch64-unknown-linux-musl" ;;
      *) echo "::error::Unsupported Linux architecture: $arch"; exit 1 ;;
    esac
    ;;
  Darwin)
    case "$arch" in
      x86_64)  target="x86_64-apple-darwin" ;;
      arm64)   target="aarch64-apple-darwin" ;;
      *) echo "::error::Unsupported macOS architecture: $arch"; exit 1 ;;
    esac
    ;;
  *) echo "::error::Unsupported OS: $os"; exit 1 ;;
esac

echo "Target: $target"

# --- Prepare install directory ---
install_dir="$(cd "$(dirname "$0")" && pwd)/bin"
mkdir -p "$install_dir"

# --- Download assets ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

binaries=("cellarctl-${target}")
if [[ "${INPUT_INSTALL_CELLARD}" == "true" ]]; then
  binaries+=("cellard-${target}")
fi

echo "Downloading SHA256SUMS..."
curl -fLo "$tmp/SHA256SUMS" ${auth_header:+-H "$auth_header"} \
  "https://github.com/$REPO/releases/download/$version/SHA256SUMS"

for bin in "${binaries[@]}"; do
  echo "Downloading ${bin}..."
  curl -fLo "$tmp/$bin" ${auth_header:+-H "$auth_header"} \
    "https://github.com/$REPO/releases/download/$version/$bin"
done

# --- Verify checksums ---
echo "Verifying checksums..."
cd "$tmp"
for bin in "${binaries[@]}"; do
  expected="$(grep " ${bin}\$" SHA256SUMS | awk '{print $1}')"
  if [[ -z "$expected" ]]; then
    echo "::error::No checksum found for $bin in SHA256SUMS"
    exit 1
  fi

  if command -v sha256sum &>/dev/null; then
    actual="$(sha256sum "$bin" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$bin" | awk '{print $1}')"
  fi

  if [[ "$expected" != "$actual" ]]; then
    echo "::error::Checksum mismatch for $bin (expected $expected, got $actual)"
    exit 1
  fi
  echo "  $bin: OK"
done

# --- Install binaries ---
chmod +x "cellarctl-${target}"
mv "cellarctl-${target}" "$install_dir/cellarctl"

if [[ "${INPUT_INSTALL_CELLARD}" == "true" ]]; then
  chmod +x "cellard-${target}"
  mv "cellard-${target}" "$install_dir/cellard"
fi

echo "$install_dir" >> "$GITHUB_PATH"

# --- Set outputs ---
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "cellarctl-path=$install_dir/cellarctl" >> "$GITHUB_OUTPUT"

echo "cellarctl $version installed to $install_dir/cellarctl"
