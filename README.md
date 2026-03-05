# cli-universal

`cli-universal` is a slim base image tuned for the GitHub Copilot CLI, Gemini CLI, and Codex CLI flows. Built on Debian Bookworm with Node.js 22 for optimal compatibility, it ships only the runtimes those tools need (Python via uv and Node.js 22+) plus essential shell utilities.

## Why Debian Bookworm with Node.js 22?

- **Modern Node.js**: Pre-installed Node.js 22+ meets GitHub Copilot CLI requirements (requires Node.js 22+)
- **Stable Foundation**: Debian Bookworm provides a stable, well-tested base with long-term support
- **Minimal Footprint**: Slim variant keeps the image lean while including essential tools
- **Wide Compatibility**: Debian's extensive package ecosystem makes it easy to extend
- **Security**: Runs as non-root user (UID 1000) with minimal privileges

## Runtimes and tools

| Runtime / tool | Details |
| --- | --- |
| Base Image | node:22-bookworm-slim (Debian 12 with Node.js 22) |
| Python | 3.12 / 3.13 / 3.14 (installed via `uv`; default symlinked to `python3`) |
| Node.js | 22.x (pre-installed from official Node.js Docker image) |
| Python Tools | `poetry`, `ruff`, `black`, `mypy`, `pyright`, `isort`, `pytest` (via uv) |
| Common CLI | `uv`, `fzf`, `ripgrep`, `git`, `curl`, `jq`, `fd-find`, etc. |

The entrypoint honors these environment variables at runtime:

| Variable | Meaning |
| --- | --- |
| `CODEX_ENV_PYTHON_VERSION` | Selects one of the bundled Python versions (default: 3.12). |

Timezone automatically follows the host if `/etc/timezone` is mounted.

## Security

The image runs as a non-root user (`cliuser`, UID 1000) by default for enhanced security. All CLI tools, Python environments, and npm packages are installed with appropriate permissions for the non-root user. Volume mounts should target `/home/cliuser` for configuration directories.

## Running the image

Default runtime behavior:

- Mount one external workspace folder (`HOST_DIR`, default: current directory)
- Run inside the mounted workspace (`/workspace/<dirname>`)
- Use `MOUNT_PROFILE=minimal` by default (workspace-only)
- Optional custom mounts via `EXTRA_VOLUMES`

```bash
podman run --rm -it \
  -e CLI_TOOL=codex \
  -e CODEX_ENV_PYTHON_VERSION=3.12 \
  -e OPENAI_API_KEY="your-openai-api-key" \
  --userns=keep-id \
  -p 1455:1455 \
  -v "$(pwd):/workspace/$(basename "$(pwd)")" \
  -w "/workspace/$(basename "$(pwd)")" \
  cli-universal:python3.12

  CLI_TOOL options:
    codex     - Launch Codex CLI
    copilot   - Launch GitHub Copilot CLI
    gemini    - Launch Gemini CLI
    bash      - Launch Bash shell
    (default) - Interactive menu to choose tool
```

### Launcher script (`run_cli_universal.sh`)

Use the launcher for local runs with sensible defaults:

```bash
# Interactive menu (default)
./run_cli_universal.sh

# Start a specific CLI directly
CLI_TOOL=copilot ./run_cli_universal.sh
```

The script passes `CLI_TOOL` into the container, mounts only `HOST_DIR` at `/workspace/<dirname>`, and runs inside that directory by default.

```bash
# Opt in to legacy host cache/config mounts
ENABLE_EXTRA_HOST_MOUNTS=1 ./run_cli_universal.sh

# Use mount profiles
MOUNT_PROFILE=dev ./run_cli_universal.sh   # persist codex/copilot/gemini auth dirs
MOUNT_PROFILE=full ./run_cli_universal.sh  # include npm global/cache + timezone mount

# Add custom mounts (semicolon-separated)
# Format: SRC:DST[:OPTIONS]
EXTRA_VOLUMES="$HOME/.ssh:/home/cliuser/.ssh:ro;copilot-cache:/home/cliuser/.cache/copilot" \
  ./run_cli_universal.sh
```

| Variable | Meaning |
| --- | --- |
| `CLI_TOOL` | Tool to start: `codex`, `copilot`, `gemini`, `bash`, or empty for the menu. |
| `CODEX_ENV_PYTHON_VERSION` | Python version used in image tag and passed to the container (default: `3.12`). |
| `HOST_DIR` | Host workspace directory mounted into `/workspace/<dirname>` (default: current directory). |
| `MOUNT_PROFILE` | Mount strategy: `minimal` (workspace-only), `dev` (mount `~/.codex`, `~/.copilot`, `~/.gemini`), `full` (adds npm global/cache and `/etc/localtime`). Default: `minimal`. |
| `ENABLE_EXTRA_HOST_MOUNTS` | Legacy compatibility switch. If set to `1` and `MOUNT_PROFILE` is unset, it behaves like `MOUNT_PROFILE=full`. |
| `EXTRA_VOLUMES` | Extra volume mounts passed to Podman. Use semicolon-separated `SRC:DST[:OPTIONS]` entries. Supports bind mounts and named volumes. |
| `PODMAN_USERNS_MODE` | Podman user namespace mode passed as `--userns` (default: `keep-id`; set empty to disable). |
| `VOL_CODEX_HOME` | Host Codex config directory mounted to `/home/cliuser/.codex` for `dev`/`full` profiles (default: `~/.codex`). |
| `VOL_COPILOT_HOME` | Host Copilot config directory mounted to `/home/cliuser/.copilot` for `dev`/`full` profiles (default: `~/.copilot`). |
| `VOL_GEMINI_HOME` | Host Gemini config directory mounted to `/home/cliuser/.gemini` for `dev`/`full` profiles (default: `~/.gemini`). |
| `VOL_NPM_GLOBAL` | Host directory mounted to `/opt/npm-global` for `full` profile (default: `~/.npm-global`). |
| `VOL_NPM_CACHE` | Host directory mounted to `/opt/npm-cache` for `full` profile (default: `~/.npm-cache`). |
| `NPM_GLOBAL_PREFIX` | npm global install prefix inside container. Defaults to `/opt/npm-global`, with auto-fallback to `/home/cliuser/.npm-global` if not writable. |
| `NPM_CACHE_DIR` | npm cache path inside container. Defaults to `/opt/npm-cache`, with auto-fallback to `/home/cliuser/.npm-cache` if not writable. |

## Building

### Bundled versions:

- **Base**: node:22-bookworm-slim (Debian 12 with Node.js 22)
- **Python**: 3.12, 3.13, 3.14.0 (via `uv` - portable Python installations)
- **Node.js**: 22.x (pre-installed, meets Copilot CLI requirements)
- **Python Tools**: poetry 2.1.x, ruff, black, mypy, pyright, isort, pytest

### Image Features:

- Minimal Debian Bookworm slim base for reduced size
- No C/C++ compilers or build tools included
- Only runtime dependencies installed
- Regular security updates from Debian and Node.js official images
- Runs as non-root user (`cliuser`, UID 1000) for enhanced security
- OCI-compliant security labels for metadata tracking

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

### Extracting CLI versions from image

CLI tool versions are captured during the build process and stored in the image. To check versions:

```bash
# View versions from a running container
podman run --rm cli-universal:python3.12 cat /opt/versions/codex.txt
podman run --rm cli-universal:python3.12 cat /opt/versions/copilot.txt
podman run --rm cli-universal:python3.12 cat /opt/versions/gemini.txt

# Or use the helper script
./extract_versions.sh cli-universal:python3.12
```

Versions are also stored in image labels:
```bash
podman image inspect cli-universal:python3.12 --format '{{.Config.Labels}}'
```

## Automated builds

Pushes to `main` (or manual dispatches) will build and push multi-arch images to Docker Hub using GitHub Actions. The workflow automatically:

1. Builds the multi-arch image
2. Extracts CLI tool versions from the built image
3. Updates the README with actual installed versions
4. Pushes the updated README to Docker Hub

Configure these repository settings before enabling the workflow:

- Repository variable: `DOCKERHUB_IMAGE` (e.g., `your-dockerhub-username/cli-universal`)
- Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`

The workflow publishes tags:

- `latest`
- `python3.12` (update the workflow `PYTHON_TAG` env if you change the default Python)

The Docker Hub description will automatically reflect the actual CLI tool versions installed during the build.

## Using as a Base Image

This image is designed to be used as a base for custom images. See the [examples/](examples/) directory for detailed examples of:

- **Simple inheritance** - Adding packages while keeping menu behavior
- **Application images** - Running apps directly, bypassing the menu
- **Development environments** - Enhanced with additional tools

### Quick Example

```dockerfile
FROM cli-universal:python3.12

# Add your packages
RUN apt-get update && apt-get install -y vim && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN uv pip install --system pandas numpy

# Add your code
COPY myapp/ /app/
WORKDIR /app

# Option 1: Keep menu (default)
# No changes needed

# Option 2: Run app directly
ENTRYPOINT []
CMD ["python3", "main.py"]
```

### Key Points for Derived Images

1. **Lock to specific version**: Use `FROM cli-universal:python3.12` not `:latest`
2. **Override ENTRYPOINT**: Set `ENTRYPOINT []` to bypass the menu system
3. **Use environment variables**: `CLI_TOOL`, `DEFAULT_SELECTION`, `MENU_TIMEOUT`
4. **PATH is set**: Python and Node.js tools are already in PATH

See [examples/README.md](examples/README.md) for comprehensive documentation.
