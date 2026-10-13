#!/usr/bin/env bash
# Detecção de distro/ambiente e abstração de gerenciador de pacotes.

PKG=
DISTRO_ID=

os_val() { ( . /etc/os-release 2>/dev/null; printf '%s' "${!1:-}" ); }

detect_distro() {
  [[ -r /etc/os-release ]] || die "/etc/os-release não encontrado: distro não suportada."
  DISTRO_ID=$(os_val ID)
  local like; like=" $(os_val ID) $(os_val ID_LIKE) "
  case "$like" in
    *" debian "*|*" ubuntu "*) PKG=apt ;;
    *" fedora "*|*" rhel "*|*" centos "*) PKG=dnf ;;
    *" arch "*) PKG=pacman ;;
    *) die "Distro '$DISTRO_ID' não suportada (suportadas: Debian/Ubuntu, Fedora, Arch)." ;;
  esac
}

is_wsl()    { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }
is_gnome()  { [[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || command -v gnome-shell >/dev/null 2>&1; }
has_systemd() { [[ -d /run/systemd/system ]]; }
is_x86_64() { [[ $(uname -m) == x86_64 ]]; }

pkg_update() {
  case $PKG in
    apt)    sudo apt-get update -y ;;
    dnf)    sudo dnf makecache -y ;;
    pacman) sudo pacman -Syu --noconfirm ;;
  esac
}

pkg_install() {
  case $PKG in
    apt)    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
  esac
}

# Instala pacote(s) local(is) (.deb/.rpm)
pkg_install_file() {
  case $PKG in
    apt)    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
    pacman) sudo pacman -U --noconfirm "$@" ;;
  esac
}

aur_install() {
  local helper
  for helper in yay paru; do
    if command -v "$helper" >/dev/null 2>&1; then
      "$helper" -S --needed --noconfirm "$@"
      return
    fi
  done
  return 1
}

ensure_flatpak() {
  command -v flatpak >/dev/null 2>&1 || pkg_install flatpak || return 1
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

# github_latest_json owner/repo → JSON da última release
github_latest_json() { curl -fsSL "https://api.github.com/repos/$1/releases/latest"; }

# github_asset owner/repo REGEX → URL do primeiro asset que casa
github_asset() {
  github_latest_json "$1" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4 | grep -E "$2" | head -1
}

# Garante uma linha/bloco no ~/.zshrc (idempotente via marcador)
zshrc_block() { # zshrc_block MARKER "conteúdo"
  local marker=$1 body=$2 rc=$HOME/.zshrc
  touch "$rc"
  grep -qF "# >>> $marker >>>" "$rc" && return 0
  printf '\n# >>> %s >>>\n%s\n# <<< %s <<<\n' "$marker" "$body" "$marker" >> "$rc"
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [[ -s $NVM_DIR/nvm.sh ]] || return 1
  set +u
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  set -u
}
