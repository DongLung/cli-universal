# cli-universal

`cli-universal` is a slim base image tuned for the GitHub Copilot CLI, Gemini CLI, and Codex CLI flows. It ships only the runtimes those tools need (Python and Node.js) plus a few shell-friendly utilities.

## Runtimes and tools

| Runtime / tool | Details |
| --- | --- |
| Python | 3.12 / 3.13 / 3.14 (installed via `uv`; default symlinked to `python3`) |
| Node.js | 20 / 22 (managed via `nvm` with npm, yarn, pnpm enabled) |
| Common CLI | `uv`, `fzf`, `ripgrep`, `git`, `curl`, `jq`, etc. |

The entrypoint honors these environment variables at runtime:

| Variable | Meaning |
| --- | --- |
| `CODEX_ENV_PYTHON_VERSION` | Selects one of the bundled Python versions (default: 3.12). |
| `CODEX_ENV_NODE_VERSION` | Selects one of the bundled Node.js versions (default: 22). |

Timezone automatically follows the host if `/etc/timezone` is mounted.

## Running the image

```bash
podman run --rm -it \
  -e CODEX_ENV_PYTHON_VERSION=3.12 \
  -e CODEX_ENV_NODE_VERSION=22 \
  -v /etc/localtime:/etc/localtime:ro \
  -v /etc/timezone:/etc/timezone:ro \
  -v $(pwd):/workspace/$(basename $(pwd)) -w /workspace/$(basename $(pwd)) \
  cli-universal:python3.12
```

## Building

Bundled versions:

- Python: 3.12, 3.13, 3.14.0 (via `uv`)
- Node.js: 20, 22 (with npm 11.4.x and yarn/pnpm via corepack)

Recommended tag format: `cli-universal:python<version>` (e.g., `cli-universal:python3.12`).

Build for both amd64 and arm64 with Podman:

```bash
podman build --platform linux/amd64,linux/arm64 \
  -t cli-universal:python3.12 .
```

> Note: the image is intended for local builds; retag as needed if you publish to your own registry.

See the [Dockerfile](Dockerfile) for the full package list and build steps.

### Version selection

| Environment variable       | Description                     | Supported versions                  |
| -------------------------- | -------------------------------- | ----------------------------------- |
| `CODEX_ENV_PYTHON_VERSION` | Python version to activate      | `3.12`, `3.13`, `3.14.0`            |
| `CODEX_ENV_NODE_VERSION`   | Node.js version to activate     | `20`, `22`                          |

## Automated builds

Pushes to `main` (or manual dispatches) will build and push multi-arch images to Docker Hub using GitHub Actions. Configure these repository settings before enabling the workflow:

- Repository variable: `DOCKERHUB_IMAGE` (e.g., `your-dockerhub-username/cli-universal`)
- Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

The workflow publishes tags:

- `latest`
- `python3.12` (update the workflow `PYTHON_TAG` env if you change the default Python)
