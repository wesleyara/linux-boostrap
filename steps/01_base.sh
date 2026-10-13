#!/usr/bin/env bash
# zsh, git e ferramentas básicas.

step_base() {
  info "Atualizando índices de pacotes..."
  pkg_update || warn "Falha ao atualizar índices; continuando."

  info "Instalando zsh, git e ferramentas básicas..."
  case $PKG in
    apt)    pkg_install zsh git curl wget unzip ca-certificates gnupg build-essential fontconfig ;;
    dnf)    pkg_install zsh git curl wget unzip ca-certificates gnupg2 gcc gcc-c++ make fontconfig ;;
    pacman) pkg_install zsh git curl wget unzip ca-certificates gnupg base-devel fontconfig ;;
  esac
}
