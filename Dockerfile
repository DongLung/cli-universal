FROM registry.access.redhat.com/ubi10:latest

ARG TARGETOS
ARG TARGETARCH

ENV LANG="C.UTF-8"
ENV HOME=/root

### BASE ###

# Install EPEL repository for additional packages
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm \
    && dnf makecache \
    && dnf install -y \
        ca-certificates \
        curl \
        fd-find \
        fzf \
        iputils \
        ripgrep \
        git \
        jq \
        openssh-clients \
        sqlite \
        unzip \
        xz \
        nodejs \
    && dnf update -y \
    && dnf clean all

### COMMON CLI UTILITIES ###

ENV UV_HOME=/opt/uv
ENV PATH=$UV_HOME/.local/bin:$HOME/.local/bin:$PATH

ARG PYTHON_VERSIONS="3.12 3.13 3.14.0"

# Install uv using the official recommended method
RUN install -d -m 0755 "$UV_HOME" \
    && if command -v uv >/dev/null 2>&1; then \
        echo "Using existing uv installation from base image" \
        && UV_PATH=$(command -v uv) \
        && ln -sf "$UV_PATH" "$UV_HOME/.local/bin/uv" \
        && ln -sf "$UV_PATH" /usr/local/bin/uv; \
    else \
        echo "Installing uv using official installer" \
        && curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$UV_HOME/.local/bin" sh \
        && ln -sf "$UV_HOME/.local/bin/uv" /usr/local/bin/uv; \
    fi \
    && HOME=$UV_HOME uv python install $PYTHON_VERSIONS \
    && PYTHON_DEFAULT=${PYTHON_VERSIONS%% *} \
    && PYTHON_DEFAULT_PATH="$(HOME=$UV_HOME uv python find "$PYTHON_DEFAULT")" \
    && ln -sf "$PYTHON_DEFAULT_PATH" /usr/local/bin/python \
    && ln -sf "$PYTHON_DEFAULT_PATH" /usr/local/bin/python3 \
    && HOME=$UV_HOME uv tool install poetry==2.1.* \
    && HOME=$UV_HOME uv tool install ruff \
    && HOME=$UV_HOME uv tool install black \
    && HOME=$UV_HOME uv tool install mypy \
    && HOME=$UV_HOME uv tool install pyright \
    && HOME=$UV_HOME uv tool install isort \
    && HOME=$UV_HOME uv tool install pytest

### NODE.js CLI TOOLS ###

ENV NPM_CONFIG_PREFIX=/opt/npm-global
ENV PATH=/opt/npm-global/bin:$PATH

# Install Codex, Copilot, and Gemini CLI tools
RUN npm install -g --no-fund \
        @openai/codex@latest \
        @github/copilot@latest \
        @google/gemini-cli@latest \
    && npm cache clean --force \
    && mkdir -p /opt/versions \
    && codex --version > /opt/versions/codex.txt 2>&1 || echo "unknown" > /opt/versions/codex.txt \
    && copilot --version > /opt/versions/copilot.txt 2>&1 || echo "unknown" > /opt/versions/copilot.txt \
    && gemini --version > /opt/versions/gemini.txt 2>&1 || echo "unknown" > /opt/versions/gemini.txt

### FINAL SECURITY UPDATE ###

# Apply all security updates one more time
RUN dnf update -y && dnf clean all

### SETUP SCRIPTS ###

COPY setup_universal.sh /opt/codex/setup_universal.sh
RUN chmod +x /opt/codex/setup_universal.sh

### VERIFICATION SCRIPT ###

COPY verify.sh /opt/verify.sh
RUN chmod +x /opt/verify.sh && bash -lc "TARGETARCH=$TARGETARCH /opt/verify.sh"

### ENTRYPOINT ###

COPY menu.sh /opt/menu.sh
RUN chmod +x /opt/menu.sh

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

### VERSION LABELS ###

RUN CODEX_VERSION=$(cat /opt/versions/codex.txt | head -n1) && \
    COPILOT_VERSION=$(cat /opt/versions/copilot.txt | head -n1) && \
    GEMINI_VERSION=$(cat /opt/versions/gemini.txt | head -n1) && \
    echo "LABEL io.github.cli.codex.version=\"${CODEX_VERSION}\"" > /opt/versions/labels.dockerfile && \
    echo "LABEL io.github.cli.copilot.version=\"${COPILOT_VERSION}\"" >> /opt/versions/labels.dockerfile && \
    echo "LABEL io.github.cli.gemini.version=\"${GEMINI_VERSION}\"" >> /opt/versions/labels.dockerfile

LABEL io.github.cli.codex.version="see /opt/versions/codex.txt" \
      io.github.cli.copilot.version="see /opt/versions/copilot.txt" \
      io.github.cli.gemini.version="see /opt/versions/gemini.txt"

CMD  ["/opt/entrypoint.sh"]
