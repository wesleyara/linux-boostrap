#!/usr/bin/env bash
# Docker Engine + plugin docker compose.

step_docker() {
  if is_wsl && command -v docker >/dev/null 2>&1; then
    ok "Docker já disponível no WSL (integração Docker Desktop)."
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker e compose plugin já instalados."
  else
    info "Instalando Docker Engine e compose plugin..."
    case $PKG in
      apt)
        local base=debian codename arch
        [[ " $(os_val ID) $(os_val ID_LIKE) " == *" ubuntu "* ]] && base=ubuntu
        codename=$(os_val UBUNTU_CODENAME); [[ -n $codename ]] || codename=$(os_val VERSION_CODENAME)
        arch=$(dpkg --print-architecture)
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL "https://download.docker.com/linux/$base/gpg" -o /etc/apt/keyrings/docker.asc || return 1
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$base $codename stable" \
          | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update -y || return 1
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1
        ;;
      dnf)
        local repo=fedora
        [[ $(os_val ID) == fedora ]] || repo=centos
        pkg_install dnf-plugins-core || return 1
        sudo dnf config-manager addrepo --from-repofile="https://download.docker.com/linux/$repo/docker-ce.repo" 2>/dev/null \
          || sudo dnf config-manager --add-repo "https://download.docker.com/linux/$repo/docker-ce.repo" || return 1
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1
        ;;
      pacman)
        pkg_install docker docker-compose docker-buildx || return 1
        ;;
    esac
  fi

  if has_systemd; then
    sudo systemctl enable --now docker || warn "Não foi possível iniciar o serviço docker."
  else
    warn "systemd indisponível: inicie o serviço docker manualmente."
  fi

  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "Usuário já está no grupo docker."
  else
    sudo usermod -aG docker "$USER" || return 1
    need_restart "Faça LOGOUT/LOGIN para usar 'docker' sem sudo (grupo docker)."
  fi
}
