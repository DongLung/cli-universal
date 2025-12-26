# cli-universal

`cli-universal` is a slim base image tuned for the GitHub Copilot CLI, Gemini CLI, and Codex CLI flows. Built on Red Hat Universal Base Image (UBI) 10 for enhanced security and enterprise-grade stability, it ships only the runtimes those tools need (Python via uv and Node.js) plus essential shell utilities.

## Why Red Hat UBI 10?

- **Security First**: Red Hat UBI receives timely security patches and has fewer vulnerabilities compared to Ubuntu base images
- **Enterprise Support**: Backed by Red Hat's enterprise-grade quality and long-term support
- **Minimal Attack Surface**: Removed unnecessary development libraries and C language build tools to reduce security exposure
- **Production Ready**: Optimized for runtime execution rather than compilation, keeping the image lean and secure

## Runtimes and tools

| Runtime / tool | Details |
| --- | --- |
| Base Image | Red Hat Universal Base Image (UBI) 10 |
| Python | 3.12 / 3.13 / 3.14 (installed via `uv`; default symlinked to `python3`) |
| Node.js | From Red Hat UBI 10 repositories (enterprise-supported) |
| Python Tools | `poetry`, `ruff`, `black`, `mypy`, `pyright`, `isort`, `pytest` (via uv) |
| Common CLI | `uv`, `fzf`, `ripgrep`, `git`, `curl`, `jq`, `fd-find`, etc. |

The entrypoint honors these environment variables at runtime:

| Variable | Meaning |
| --- | --- |
| `CODEX_ENV_PYTHON_VERSION` | Selects one of the bundled Python versions (default: 3.12). |

Timezone automatically follows the host if `/etc/timezone` is mounted.

## Running the image

```bash
podman run --rm -it \
  -e CLI_TOOL=codex \
  -e CODEX_ENV_PYTHON_VERSION=3.12 \
  -e OPENAI_API_KEY="your-openai-api-key" \
  -p 1455:1455 \
  -v /etc/localtime:/etc/localtime:ro \
  -v npm-global:/opt/npm-global \
  -v npm-cache:/opt/npm-cache \
  -v ai-codex-home:/root/.codex \
  -v ai-copilot-home:/root/.copilot \
  -v ai-gemini-home:/root/.gemini \
  -v $(pwd):/workspace/$(basename $(pwd)) \
  -w /workspace/$(basename $(pwd)) \
  cli-universal:python3.12

  CLI_TOOL options:
    codex     - Launch Codex CLI
    copilot   - Launch GitHub Copilot CLI
    gemini    - Launch Gemini CLI
    bash      - Launch Bash shell
    (default) - Interactive menu to choose tool
```

## Building

### Bundled versions:

- **Base**: Red Hat Universal Base Image (UBI) 10
- **Python**: 3.12, 3.13, 3.14.0 (via `uv` - portable Python installations)
- **Node.js**: From Red Hat UBI 10 repositories (version managed by Red Hat)
- **Python Tools**: poetry 2.1.x, ruff, black, mypy, pyright, isort, pytest

### Security Features:

- No C/C++ compilers or build tools included (removed gcc, make, cmake, etc.)
- No development libraries (-devel packages removed)
- Minimal package footprint for reduced attack surface
- Regular security updates from Red Hat

Recommended tag format: `cli-universal:python<version>` (e.g., `cli-universal:python3.12`).

### Quick Build (Recommended)

Use the provided build script for single-platform builds:

```bash
# Build for your current platform (default: linux/amd64)
./build.sh

# Or specify platform and tag
PLATFORM=linux/arm64 TAG=python3.12 ./build.sh
```

### Manual Build

Build for both amd64 and arm64 with Podman:

```bash
# Method 1: Using podman build with manifest (recommended)
podman build --platform linux/amd64,linux/arm64 \
  --manifest cli-universal:python3.12 \
  -f Dockerfile .

# Method 2: Build each platform separately then create manifest
podman build --platform linux/amd64 \
  -f Dockerfile \
  -t cli-universal:python3.12-amd64 .

podman build --platform linux/arm64 \
  -f Dockerfile \
  -t cli-universal:python3.12-arm64 .

# Create and push manifest
podman manifest create cli-universal:python3.12
podman manifest add cli-universal:python3.12 cli-universal:python3.12-amd64
podman manifest add cli-universal:python3.12 cli-universal:python3.12-arm64
```

For Docker users:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t cli-universal:python3.12 \
  -f Dockerfile .
```

> Note: the image is intended for local builds; retag as needed if you publish to your own registry.

See the [Dockerfile](Dockerfile) for the full package list and build steps.

### Version selection

| Environment variable       | Description                     | Supported versions                  |
| -------------------------- | -------------------------------- | ----------------------------------- |
| `CODEX_ENV_PYTHON_VERSION` | Python version to activate      | `3.12`, `3.13`, `3.14.0`            |

## Automated builds

Pushes to `main` (or manual dispatches) will build and push multi-arch images to Docker Hub using GitHub Actions. Configure these repository settings before enabling the workflow:

- Repository variable: `DOCKERHUB_IMAGE` (e.g., `your-dockerhub-username/cli-universal`)
- Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

The workflow publishes tags:

- `latest`
- `python3.12` (update the workflow `PYTHON_TAG` env if you change the default Python)
