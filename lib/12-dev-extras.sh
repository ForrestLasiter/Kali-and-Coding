#!/usr/bin/env bash
# 12-dev-extras.sh — extra coding tooling on top of 10-dev.
# uv (Python), JS runtimes, git TUI, DB/API clients, shell QoL, dev utilities,
# secrets. Runs after 10-dev (needs Node/nvm, Go, and Rust/cargo present).

# =============================================================================
# uv — fast Python version + venv + pip manager (Astral)
# =============================================================================
if ! command -v uv >/dev/null 2>&1 && [[ ! -x "$RUN_HOME/.local/bin/uv" ]]; then
  info "installing uv (Python toolchain) for $RUN_USER"
  as_user 'curl -fsSL https://astral.sh/uv/install.sh | sh' || warn "uv install failed"
fi
info "python linters/formatters via pipx"
for t in ruff mypy black; do
  as_user "pipx install $t" || warn "pipx install $t failed"
done

# =============================================================================
# JS runtimes — corepack (pnpm/yarn) + Bun
# =============================================================================
info "enabling corepack (pnpm/yarn)"
as_user 'export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh" 2>/dev/null; \
  command -v corepack >/dev/null && corepack enable && \
  corepack prepare pnpm@latest --activate' || warn "corepack setup failed (is Node installed? run module 10)"
if [[ ! -d "$RUN_HOME/.bun" ]]; then
  info "installing Bun runtime"
  as_user 'curl -fsSL https://bun.sh/install | bash' || warn "bun install failed"
fi

# =============================================================================
# Git TUI + workflow
# =============================================================================
info "git TUI + workflow tools"
apt_install lazygit tig git-lfs git-extras
# fallback: lazygit is a Go tool if the repo doesn't carry it
command -v lazygit >/dev/null 2>&1 || \
  as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/jesseduffield/lazygit@latest' \
  || warn "lazygit not available (apt + go both failed)"
as_user 'git lfs install' >/dev/null 2>&1 || true

# =============================================================================
# Database + API clients
# =============================================================================
info "DB clients + API testing"
apt_install postgresql-client sqlite3 redis-tools pgcli httpie

# DBeaver CE (GUI) — 'latest' is a stable redirect
dpkg -s dbeaver-ce >/dev/null 2>&1 || \
  install_deb "dbeaver-ce" "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"

# Bruno — open-source API client (Postman alternative)
BRUNO_VER="1.34.2"
dpkg -s bruno >/dev/null 2>&1 || \
  install_deb "bruno" "https://github.com/usebruno/bruno/releases/download/v${BRUNO_VER}/bruno_${BRUNO_VER}_amd64_linux.deb"

# =============================================================================
# Shell QoL — zoxide, atuin, tealdeer
# =============================================================================
info "shell QoL (zoxide, atuin, tealdeer)"
apt_install zoxide tealdeer
# atuin: magic searchable/syncable shell history (prebuilt binary, no compile)
install_gh_release_bin atuin atuinsh/atuin "atuin-${RUST_ARCH}-unknown-linux-gnu\.tar\.gz$" atuin
as_user 'command -v tldr >/dev/null 2>&1 && tldr --update >/dev/null 2>&1 || true'

# =============================================================================
# Dev utilities + secrets
# =============================================================================
info "dev utilities (just, watchexec, hyperfine, tokei, entr) + secrets (age/sops)"
# watchexec + sops aren't in Kali's apt; installed via cargo / go below.
apt_install just hyperfine tokei entr age
# sops via go (getsops) — not packaged in Kali
if command -v sops >/dev/null 2>&1 || as_user 'test -x "$HOME/go/bin/sops"'; then :; else
  as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/getsops/sops/v3/cmd/sops@latest' \
    || warn "sops install failed"
fi

# cargo fallbacks for the Rust tools if the repo didn't carry them
for pair in "just:just" "watchexec:watchexec-cli"; do
  bin="${pair%%:*}"; crate="${pair##*:}"
  command -v "$bin" >/dev/null 2>&1 || \
    as_user "source \$HOME/.cargo/env 2>/dev/null; cargo install $crate" \
    || warn "cargo install $crate failed"
done

# container TUIs
command -v lazydocker >/dev/null 2>&1 || \
  as_user 'export PATH=$PATH:/usr/local/go/bin GOPATH=$HOME/go; go install github.com/jesseduffield/lazydocker@latest' \
  || warn "lazydocker install failed"
DIVE_VER="0.12.0"
command -v dive >/dev/null 2>&1 || \
  install_deb "dive" "https://github.com/wagoodman/dive/releases/download/v${DIVE_VER}/dive_${DIVE_VER}_linux_amd64.deb"

cat <<EOF
${_c_blue}[*]${_c_reset} New tools in your PATH after a fresh shell:
    uv (python), pnpm/yarn, bun, lazygit, lazydocker, dive, pgcli,
    http (httpie), z (zoxide), atuin (Ctrl-R history), tldr, just, sops, age
${_c_blue}[*]${_c_reset} atuin sync: run 'atuin register' / 'atuin login' to sync history across
    machines (or keep it local). Pairs with your Syncthing setup.
EOF

ok "dev-extras module complete"
