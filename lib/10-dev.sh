#!/usr/bin/env bash
# 10-dev.sh — developer & terminal environment.

# --- modern CLI + shell ------------------------------------------------------
info "Modern CLI tooling + zsh"
apt_install \
  zsh tmux \
  bat eza ripgrep fd-find fzf \
  git-delta shellcheck \
  direnv

# On Debian/Kali, `bat` and `fd` install as `batcat` / `fdfind`. The dotfiles
# alias these, but we also drop convenience symlinks in /usr/local/bin.
[[ -x /usr/bin/batcat ]] && ln -sf /usr/bin/batcat /usr/local/bin/bat
[[ -x /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind /usr/local/bin/fd

# --- oh-my-zsh + plugins (as the user) --------------------------------------
if [[ ! -d "$RUN_HOME/.oh-my-zsh" ]]; then
  info "installing oh-my-zsh for $RUN_USER"
  as_user 'export RUNZSH=no CHSH=no KEEP_ZSHRC=yes; \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' \
    || warn "oh-my-zsh install failed"
fi
ZSH_CUSTOM="$RUN_HOME/.oh-my-zsh/custom"
as_user "git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions '$ZSH_CUSTOM/plugins/zsh-autosuggestions' 2>/dev/null || true"
as_user "git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting '$ZSH_CUSTOM/plugins/zsh-syntax-highlighting' 2>/dev/null || true"

# --- starship prompt ---------------------------------------------------------
if ! command -v starship >/dev/null 2>&1; then
  info "installing starship prompt"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y >/dev/null || warn "starship install failed"
fi

# set zsh as the default shell for the user
if [[ "$(getent passwd "$RUN_USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  chsh -s "$(command -v zsh)" "$RUN_USER" && ok "default shell set to zsh"
fi

# --- Editor: VSCodium (fully-FOSS, telemetry-free) --------------------------
# Remote dev is handled by the open-remote-ssh extension (Open VSX), so no MS
# VS Code build is needed. Telemetry-off defaults come from module 90.
add_apt_repo "vscodium" \
  "https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg" \
  "deb [signed-by=KEYRING] https://download.vscodium.com/debs vscodium main"
apt_install codium

# VSCodium extensions (from Open VSX). MS-proprietary ones (Pylance, the MS
# Python/debugpy pack, Remote pack) are NOT on Open VSX, so open equivalents
# are used instead (basedpyright, Ruff, open-remote-ssh). Each install is
# best-effort: a failure warns and continues.
if command -v codium >/dev/null 2>&1; then
  info "installing VSCodium extensions from Open VSX"
  VSCODIUM_EXTS=(
    # --- remote dev ---
    jeanp413.open-remote-ssh
    # --- python ---
    charliermarsh.ruff              # lint + format (Ruff)
    detachhead.basedpyright         # language server / type checker (open Pylance alt)
    # --- javascript / typescript / web ---
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
    astro-build.astro-vscode        # your portfolio
    bradlc.vscode-tailwindcss
    # --- APIs / data formats ---
    humao.rest-client               # send HTTP from .http files (great w/ FastAPI)
    42crunch.vscode-openapi         # OpenAPI/Swagger editor + linting
    redhat.vscode-yaml              # yaml (openapi, compose, k8s)
    tamasfe.even-better-toml        # pyproject.toml, cargo, starship
    mikestead.dotenv                # .env highlighting
    # --- containers ---
    ms-azuretools.vscode-docker
    # --- go / rust ---
    golang.go
    rust-lang.rust-analyzer
    # --- shell (you write bash) ---
    timonwong.shellcheck
    foxundermoon.shell-format
    # --- git + quality-of-life ---
    eamodio.gitlens
    usernamehw.errorlens            # inline errors/warnings
    editorconfig.editorconfig
    gruntfuggly.todo-tree
    streetsidesoftware.code-spell-checker
    yzhang.markdown-all-in-one
    pkief.material-icon-theme
  )
  for ext in "${VSCODIUM_EXTS[@]}"; do
    if as_user "codium --install-extension $ext --force" >/dev/null 2>&1; then
      ok "ext: $ext"
    else
      warn "ext failed (add from Open VSX UI): $ext"
    fi
  done
fi

# If a previous provisioning run installed MS VS Code, drop it (superseded).
if dpkg -s code >/dev/null 2>&1; then
  info "removing MS VS Code (replaced by VSCodium + open-remote-ssh)"
  apt-get purge -y code || warn "could not purge code"
  rm -f /etc/apt/sources.list.d/vscode.list /usr/share/keyrings/vscode.gpg
fi

# --- Docker (Kali repo package is fine and well-integrated) ------------------
info "Docker engine"
apt_install docker.io docker-compose
systemctl enable --now docker 2>/dev/null || warn "could not enable docker service"
if ! id -nG "$RUN_USER" | grep -qw docker; then
  usermod -aG docker "$RUN_USER" && ok "added $RUN_USER to docker group (re-login required)"
fi

# --- Go toolchain (latest stable, not the older apt version) -----------------
GO_VERSION="1.23.4"
if ! command -v go >/dev/null 2>&1 || ! go version 2>/dev/null | grep -q "$GO_VERSION"; then
  info "installing Go $GO_VERSION"
  tmp="$(mktemp -d)"
  if curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o "$tmp/go.tgz"; then
    rm -rf /usr/local/go && tar -C /usr/local -xzf "$tmp/go.tgz"
    ln -sf /usr/local/go/bin/go /usr/local/bin/go
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
    ok "Go installed to /usr/local/go"
  else
    warn "Go download failed; falling back to apt golang"
    apt_install golang
  fi
  rm -rf "$tmp"
fi

# --- Node via nvm (as the user) ---------------------------------------------
if [[ ! -d "$RUN_HOME/.nvm" ]]; then
  info "installing nvm + Node LTS for $RUN_USER"
  as_user 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash' || warn "nvm install failed"
  as_user 'export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm install --lts' || warn "node install failed"
fi

# --- pipx path for the user --------------------------------------------------
as_user 'pipx ensurepath >/dev/null 2>&1 || true'

# --- GitHub CLI (official apt repo) -----------------------------------------
add_apt_repo "github-cli" \
  "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
  "deb [arch=amd64 signed-by=KEYRING] https://cli.github.com/packages stable main"
apt_install gh

# --- Rust toolchain via rustup (as the user) --------------------------------
if [[ ! -d "$RUN_HOME/.rustup" ]]; then
  info "installing rustup + stable Rust for $RUN_USER"
  as_user 'curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path' \
    || warn "rustup install failed"
fi
# dotfiles PATH already includes ~/.cargo/bin via ~/.local/bin? add explicitly:
grep -q 'cargo/bin' "$RUN_HOME/.zshrc" 2>/dev/null || true  # .zshrc from module 90 sources cargo env

ok "dev module complete"
