FROM node:22-bookworm-slim

ARG TARGETOS
ARG TARGETARCH

# Security: The base image includes 'node' user (UID 1000), which we'll use instead of root
# We'll rename it to 'cliuser' for clarity
RUN usermod -l cliuser node && \
    groupmod -n cliuser node && \
    usermod -d /home/cliuser -m cliuser

ENV LANG="C.UTF-8"
ENV HOME=/home/cliuser

### BASE ###

# Install common utilities and fzf (combined for layer optimization)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        jq \
        unzip \
        xz-utils \
        sqlite3 \
        fd-find \
        ripgrep && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
    /opt/fzf/install --bin && \
    ln -s /opt/fzf/bin/fzf /usr/local/bin/fzf && \
    chown -R cliuser:cliuser /opt/fzf

### COMMON CLI UTILITIES ###

ENV UV_HOME=/opt/uv
ENV PATH=$UV_HOME/.local/bin:$HOME/.local/bin:$PATH

ARG PYTHON_VERSIONS="3.12 3.13 3.14.0"
ARG POETRY_VERSION="2.1.*"

# Install uv and Python tools (optimized into single layer)
RUN install -d -m 0755 "$UV_HOME" && \
    if command -v uv >/dev/null 2>&1; then \
        echo "Using existing uv installation from base image" && \
        UV_PATH=$(command -v uv) && \
        ln -sf "$UV_PATH" "$UV_HOME/.local/bin/uv" && \
        ln -sf "$UV_PATH" /usr/local/bin/uv; \
    else \
        echo "Installing uv using official installer" && \
        curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$UV_HOME/.local/bin" sh && \
        ln -sf "$UV_HOME/.local/bin/uv" /usr/local/bin/uv; \
    fi && \
    HOME=$UV_HOME uv python install $PYTHON_VERSIONS && \
    PYTHON_DEFAULT=${PYTHON_VERSIONS%% *} && \
    PYTHON_DEFAULT_PATH="$(HOME=$UV_HOME uv python find "$PYTHON_DEFAULT")" && \
    ln -sf "$PYTHON_DEFAULT_PATH" /usr/local/bin/python && \
    ln -sf "$PYTHON_DEFAULT_PATH" /usr/local/bin/python3 && \
    HOME=$UV_HOME uv tool install poetry==$POETRY_VERSION && \
    HOME=$UV_HOME uv tool install ruff && \
    HOME=$UV_HOME uv tool install black && \
    HOME=$UV_HOME uv tool install mypy && \
    HOME=$UV_HOME uv tool install pyright && \
    HOME=$UV_HOME uv tool install isort && \
    HOME=$UV_HOME uv tool install pytest && \
    chown -R cliuser:cliuser "$UV_HOME"

### NODE.js CLI TOOLS ###

ENV NPM_CONFIG_PREFIX=/opt/npm-global
ENV PATH=/opt/npm-global/bin:$PATH

# Install Codex, Copilot, and Gemini CLI tools with version capture
RUN mkdir -p /opt/npm-global /opt/versions && \
    chown -R cliuser:cliuser /opt/npm-global /opt/versions && \
    npm install -g --no-fund \
        @openai/codex@latest \
        @github/copilot@latest \
        @google/gemini-cli@latest && \
    npm cache clean --force && \
    codex --version > /opt/versions/codex.txt 2>&1 || echo "unknown" > /opt/versions/codex.txt && \
    copilot --version > /opt/versions/copilot.txt 2>&1 || echo "unknown" > /opt/versions/copilot.txt && \
    gemini --version > /opt/versions/gemini.txt 2>&1 || echo "unknown" > /opt/versions/gemini.txt

### FINAL SECURITY UPDATE ###

# Apply all security updates and setup script directories
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /opt/codex && \
    chown -R cliuser:cliuser /opt/codex

### SETUP SCRIPTS ###

COPY --chown=cliuser:cliuser setup_universal.sh /opt/codex/setup_universal.sh
RUN chmod +x /opt/codex/setup_universal.sh

### VERIFICATION SCRIPT ###

COPY --chown=cliuser:cliuser verify.sh /opt/verify.sh
RUN chmod +x /opt/verify.sh && bash -lc "TARGETARCH=$TARGETARCH /opt/verify.sh"

### ENTRYPOINT ###

COPY --chown=cliuser:cliuser menu.sh /opt/menu.sh
COPY --chown=cliuser:cliuser entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/menu.sh /opt/entrypoint.sh

### VERSION LABELS ###

RUN CODEX_VERSION=$(cat /opt/versions/codex.txt | head -n1) && \
    COPILOT_VERSION=$(cat /opt/versions/copilot.txt | head -n1) && \
    GEMINI_VERSION=$(cat /opt/versions/gemini.txt | head -n1) && \
    echo "LABEL io.github.cli.codex.version=\"${CODEX_VERSION}\"" > /opt/versions/labels.dockerfile && \
    echo "LABEL io.github.cli.copilot.version=\"${COPILOT_VERSION}\"" >> /opt/versions/labels.dockerfile && \
    echo "LABEL io.github.cli.gemini.version=\"${GEMINI_VERSION}\"" >> /opt/versions/labels.dockerfile

# OCI labels for security metadata
LABEL org.opencontainers.image.title="cli-universal" \
      org.opencontainers.image.description="Secure CLI environment for GitHub Copilot, Gemini, and Codex CLI tools" \
      org.opencontainers.image.vendor="cli-universal" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="docker.io/library/node:22-bookworm-slim" \
      io.github.cli.codex.version="see /opt/versions/codex.txt" \
      io.github.cli.copilot.version="see /opt/versions/copilot.txt" \
      io.github.cli.gemini.version="see /opt/versions/gemini.txt" \
      security.non-root-user="cliuser" \
      security.user-id="1000"

# Switch to non-root user
USER cliuser
WORKDIR /home/cliuser

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD []
