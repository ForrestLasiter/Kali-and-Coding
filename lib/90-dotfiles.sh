#!/usr/bin/env bash
# 90-dotfiles.sh — drop shell/tmux/prompt config into the user's home.
# Backs up any existing file to <name>.bak-<timestamp> before overwriting.

DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
STAMP="$(date +%Y%m%d%H%M%S)"

install_dotfile() {
  local src="$1" dest="$2"
  [[ -f "$src" ]] || { warn "dotfile missing: $src"; return 0; }
  if [[ -e "$dest" ]] && ! diff -q "$src" "$dest" >/dev/null 2>&1; then
    cp -a "$dest" "${dest}.bak-${STAMP}"
    info "backed up existing $(basename "$dest") -> $(basename "$dest").bak-${STAMP}"
  fi
  install -o "$RUN_USER" -g "$RUN_USER" -m 0644 "$src" "$dest"
  ok "installed $(basename "$dest")"
}

install_dotfile "$DOTFILES_DIR/zshrc"        "$RUN_HOME/.zshrc"
install_dotfile "$DOTFILES_DIR/tmux.conf"    "$RUN_HOME/.tmux.conf"
install_dotfile "$DOTFILES_DIR/gitconfig"    "$RUN_HOME/.gitconfig"

# starship config
install -d -o "$RUN_USER" -g "$RUN_USER" "$RUN_HOME/.config"
install_dotfile "$DOTFILES_DIR/starship.toml" "$RUN_HOME/.config/starship.toml"

# neovim minimal config
install -d -o "$RUN_USER" -g "$RUN_USER" "$RUN_HOME/.config/nvim"
install_dotfile "$DOTFILES_DIR/init.vim"     "$RUN_HOME/.config/nvim/init.vim"

# editor settings: telemetry-off defaults for VSCodium (~/.config/VSCodium).
install -d -o "$RUN_USER" -g "$RUN_USER" "$RUN_HOME/.config/VSCodium/User"
install_dotfile "$DOTFILES_DIR/vscode-settings.json" "$RUN_HOME/.config/VSCodium/User/settings.json"

ok "dotfiles module complete — open a new shell (or 'exec zsh') to load them"
