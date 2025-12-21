FROM registry.access.redhat.com/ubi10:latest

ARG TARGETOS
ARG TARGETARCH

ENV LANG="C.UTF-8"
ENV HOME=/root

### BASE ###

RUN dnf install -y \
        ca-certificates \
        curl \
        wget \
        git \
        git-lfs \
        binutils \
        sudo \
        gcc \
        gcc-c++ \
        make \
        cmake \
        autoconf \
        automake \
        libtool \
        bzr \
        mariadb-devel \
        bind-utils \
        fd-find \
        fzf \
        gettext \
        gnupg2 \
        inotify-tools \
        iputils \
        jq \
        bzip2-devel \
        glibc \
        glibc-devel \
        libcurl-devel \
        libdb-devel \
        libedit \
        libffi-devel \
        gdbm-devel \
        krb5-libs \
        xz-devel \
        ncurses-devel \
        nss-devel \
        libpq-devel \
        libpsl-devel \
        python3-devel \
        readline-devel \
        sqlite-devel \
        openssl-devel \
        libstdc++-devel \
        libunwind \
        libuuid \
        libxml2-devel \
        moreutils \
        nmap-ncat \
        openssh-clients \
        pkgconfig \
        protobuf-compiler \
        ripgrep \
        rsync \
        sqlite \
        swig \
        tk-devel \
        tzdata \
        ctags \
        unixODBC-devel \
        unzip \
        uuid-devel \
        xz \
        zip \
        zlib \
        zlib-devel \
    && dnf clean all

### COMMON CLI UTILITIES ###

ENV UV_HOME=/opt/uv
ENV PATH=$UV_HOME/.local/bin:$HOME/.local/bin:$PATH

ARG PYTHON_VERSIONS="3.12 3.13 3.14.0"

# Reduce the verbosity of uv - impacts performance of stdout buffering
ENV UV_NO_PROGRESS=1

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
    && ln -sf "$PYTHON_DEFAULT_PATH" /usr/local/bin/python3 \
    && HOME=$UV_HOME uv tool install poetry==2.1.* \
    && HOME=$UV_HOME uv tool install ruff \
    && HOME=$UV_HOME uv tool install black \
    && HOME=$UV_HOME uv tool install mypy \
    && HOME=$UV_HOME uv tool install pyright \
    && HOME=$UV_HOME uv tool install isort \
    && HOME=$UV_HOME uv tool install pytest

### NODE ###

ARG NVM_VERSION=v0.40.2
ARG NODE_VERSION=22

ENV NVM_DIR=/root/.nvm
# Corepack tries to do too much - disable some of its features:
# https://github.com/nodejs/corepack/blob/main/README.md
ENV COREPACK_DEFAULT_TO_LATEST=0
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV COREPACK_ENABLE_AUTO_PIN=0
ENV COREPACK_ENABLE_STRICT=0

RUN git -c advice.detachedHead=0 clone --branch "$NVM_VERSION" --depth 1 https://github.com/nvm-sh/nvm.git "$NVM_DIR" \
    && echo 'source $NVM_DIR/nvm.sh' >> /etc/profile \
    && echo "prettier\neslint\ntypescript" > $NVM_DIR/default-packages \
    && . $NVM_DIR/nvm.sh \
    && nvm install 20 && nvm use 20 && npm install -g npm@11.4 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm install 22 && nvm use 22 && npm install -g npm@11.4 pnpm@10.12 && corepack enable && corepack install -g yarn \
    && nvm alias default "$NODE_VERSION" \
    && nvm cache clear \
    && npm cache clean --force || true \
    && pnpm store prune || true \
    && yarn cache clean || true

### SETUP SCRIPTS ###

COPY setup_universal.sh /opt/codex/setup_universal.sh
RUN chmod +x /opt/codex/setup_universal.sh

### VERIFICATION SCRIPT ###

COPY verify.sh /opt/verify.sh
RUN chmod +x /opt/verify.sh && bash -lc "TARGETARCH=$TARGETARCH /opt/verify.sh"

### ENTRYPOINT ###

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

ENTRYPOINT  ["/opt/entrypoint.sh"]
