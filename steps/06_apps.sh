#!/usr/bin/env bash
# VS Code, Claude, Chrome e Discord.

_app_chrome() {
  command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1 \
    && { ok "Chrome já instalado."; return 0; }
  is_x86_64 || { warn "Chrome oficial só existe para x86_64."; return 1; }
  local tmp; tmp=$(mktemp -d)
  case $PKG in
    apt)
      download https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb "$tmp/chrome.deb" \
        && pkg_install_file "$tmp/chrome.deb" ;;
    dnf)
      download https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm "$tmp/chrome.rpm" \
        && pkg_install_file "$tmp/chrome.rpm" ;;
    pacman)
      aur_install google-chrome || { warn "Instale yay/paru e rode: yay -S google-chrome"; rm -rf "$tmp"; return 1; } ;;
  esac
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

_app_code() {
  command -v code >/dev/null 2>&1 && { ok "VS Code já instalado."; return 0; }
  case $PKG in
    apt)
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
        | sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null || return 1
      echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
      sudo apt-get update -y && pkg_install code ;;
    dnf)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || return 1
      printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
        | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
      pkg_install code ;;
    pacman)
      aur_install visual-studio-code-bin \
        || { ensure_flatpak && sudo flatpak install -y flathub com.visualstudio.code; } ;;
  esac
}

_app_discord() {
  command -v discord >/dev/null 2>&1 && { ok "Discord já instalado."; return 0; }
  case $PKG in
    apt)
      local tmp; tmp=$(mktemp -d)
      download "https://discord.com/api/download?platform=linux&format=deb" "$tmp/discord.deb" \
        && pkg_install_file "$tmp/discord.deb"
      local rc=$?; rm -rf "$tmp"; return $rc ;;
    pacman) pkg_install discord ;;
    dnf)    ensure_flatpak && sudo flatpak install -y flathub com.discordapp.Discord ;;
  esac
}

_app_claude() {
  if command -v claude >/dev/null 2>&1; then
    ok "Claude Code já instalado."
    return 0
  fi
  info "Instalando Claude Code (instalador oficial)..."
  curl -fsSL https://claude.ai/install.sh | bash || return 1
  warn "O app desktop do Claude não possui pacote oficial para Linux; instalado apenas o Claude Code (CLI)."
}

step_apps() {
  if is_wsl; then
    warn "WSL detectado: apps gráficos (Chrome/Code/Discord) devem ser instalados no Windows."
    _app_claude || return 1
    return 0
  fi

  local failed=() a
  for a in claude code chrome discord; do
    section "App: $a"
    "_app_$a" || { err "Falha ao instalar $a."; failed+=("$a"); }
  done
  ((${#failed[@]} == 0)) || { err "Apps com falha: ${failed[*]}"; return 1; }
}
