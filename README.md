# cellar-action

GitHub Action to install [cellarctl](https://github.com/JinxCappa/cellar) and optionally configure Nix to use a Cellar binary cache.

## Usage

### Install cellarctl only

```yaml
- uses: JinxCappa/cellar-action@v1
```

### Install a specific version

```yaml
- uses: JinxCappa/cellar-action@v1
  with:
    version: v0.1.0
```

### Configure Nix using environment variables (recommended)

If you already have `CELLAR_SERVER`, `CELLAR_TOKEN`, and `CELLAR_CACHE_ID` set as job-level env vars, the action auto-configures everything — no extra inputs needed. The signing key is fetched automatically via `cellarctl whoami`.

```yaml
jobs:
  build:
    env:
      CELLAR_SERVER: ${{ secrets.CELLAR_SERVER }}
      CELLAR_TOKEN: ${{ secrets.CELLAR_TOKEN }}
      CELLAR_CACHE_ID: ${{ secrets.CELLAR_CACHE_ID }}
    steps:
      - uses: JinxCappa/cellar-action@main
        with:
          configure-nix: 'true'
      # Nix is configured, cellarctl is ready
```

### Install and configure Nix substituter (explicit inputs)

```yaml
- uses: JinxCappa/cellar-action@main
  with:
    configure-nix: 'true'
    server: https://cellar.example.com
    signing-key: 'cellar.example.com:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
```

### Full setup (install + configure + auth)

```yaml
- uses: JinxCappa/cellar-action@main
  with:
    configure-nix: 'true'
    server: https://cellar.example.com
    signing-key: 'cellar.example.com:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    cellar-token: ${{ secrets.CELLAR_TOKEN }}
```

### Also install cellard

```yaml
- uses: JinxCappa/cellar-action@main
  with:
    install-cellard: 'true'
```

## Inputs

| Input | Description | Default |
|---|---|---|
| `version` | Cellar version to install (e.g. `v0.1.3`) | `latest` |
| `token` | GitHub token for downloading release assets | `${{ github.token }}` |
| `configure-nix` | Configure Nix to use the cellar server as a substituter | `false` |
| `server` | Cellar server URL. Falls back to `CELLAR_SERVER` env var | |
| `signing-key` | Public signing key for Nix `trusted-public-keys`. Falls back to auto-fetch via `cellarctl whoami` | |
| `cellar-token` | Auth token for cellarctl. Falls back to `CELLAR_TOKEN` env var | |
| `install-cellard` | Also install the cellard server binary | `false` |

## Outputs

| Output | Description |
|---|---|
| `version` | The version of cellar that was installed |
| `cellarctl-path` | Path to the installed cellarctl binary |

## License

MIT
