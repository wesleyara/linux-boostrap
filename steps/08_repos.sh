#!/usr/bin/env bash
# Clona e instala DockerLocal, ClickLocal, Wttp e gnome-shell-pano.

REPOS_DIR=${REPOS_DIR:-$HOME/dev}

clone_or_update() { # URL DIR [BRANCH]
  local url=$1 dir=$2 branch=${3:-}
  if [[ -d $dir/.git ]]; then
    info "Atualizando $dir"
    git -C "$dir" pull --ff-only -q || warn "Não foi possível atualizar $dir (alterações locais?)."
  else
    info "Clonando $url"
    git clone ${branch:+--branch "$branch"} "$url" "$dir"
  fi
}

docker_cmd() {
  if docker info >/dev/null 2>&1; then docker "$@"; else sudo docker "$@"; fi
}

set_env() { # FILE KEY VALUE
  local f=$1 k=$2 v=$3
  if grep -qE "^$k=" "$f"; then
    sed -i -E "s|^$k=.*|$k=$v|" "$f"
  else
    printf '%s=%s\n' "$k" "$v" >> "$f"
  fi
}

wait_http() { # URL SEGUNDOS
  local i
  for ((i = 0; i < $2; i += 2)); do
    curl -fs "$1" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

_repo_dockerlocal() {
  local dir=$REPOS_DIR/DockerLocal
  clone_or_update https://github.com/wesleyara/DockerLocal.git "$dir" || return 1
  [[ -f $dir/.env ]] || cp "$dir/.env.example" "$dir/.env"
  set_env "$dir/.env" DOCKER_GID "$(getent group docker | cut -d: -f3)"
  set_env "$dir/.env" PROJECTS_ROOT "${PROJECTS_ROOT:-$REPOS_DIR}"
  grep -qE '^FS_ROOTS=' "$dir/.env" && set_env "$dir/.env" FS_ROOTS "${PROJECTS_ROOT:-$REPOS_DIR}"
  info "Build e start do DockerLocal (docker compose)..."
  (cd "$dir" && docker_cmd compose up -d --build) || return 1
  if wait_http http://localhost:5100/api/system/ping 60; then
    ok "DockerLocal no ar: http://localhost:5100 (API)"
  else
    warn "DockerLocal subiu, mas o ping não respondeu em 60s. Veja: docker compose logs"
  fi
}

_repo_clicklocal() {
  local dir=$REPOS_DIR/ClickLocal
  clone_or_update https://github.com/wesleyara/ClickLocal.git "$dir" || return 1
  [[ -f $dir/.env || ! -f $dir/.env.example ]] || cp "$dir/.env.example" "$dir/.env"
  info "Build e start do ClickLocal (docker compose)..."
  (cd "$dir" && docker_cmd compose up -d --build) || return 1
  if wait_http http://localhost:8880 90; then
    ok "ClickLocal no ar: http://localhost:8880"
  else
    warn "ClickLocal subiu, mas a porta 8880 não respondeu. Veja: docker compose logs"
  fi
}

_repo_wttp() {
  if command -v wttp >/dev/null 2>&1 || [[ -x $HOME/.local/bin/wttp ]] || dpkg -s wttp >/dev/null 2>&1; then
    ok "Wttp já instalado."
    return 0
  fi

  local tmp url file sums
  tmp=$(mktemp -d)
  if [[ $PKG == apt ]]; then
    url=$(github_asset wesleyara/Wttp '\.deb$') || true
  else
    url=$(github_asset wesleyara/Wttp '\.AppImage$') || true
  fi

  if [[ -n $url ]]; then
    file=$tmp/$(basename "$url")
    download "$url" "$file" || { rm -rf "$tmp"; return 1; }
    sums=$(github_asset wesleyara/Wttp 'SHA256SUMS-Linux\.txt$') || true
    if [[ -n $sums ]] && download "$sums" "$tmp/SHA256SUMS.txt"; then
      if (cd "$tmp" && grep -F "$(basename "$file")" SHA256SUMS.txt | sha256sum -c - >/dev/null 2>&1); then
        ok "SHA256 verificado."
      else
        err "SHA256 não confere; abortando instalação do Wttp."
        rm -rf "$tmp"; return 1
      fi
    else
      warn "SHA256SUMS não encontrado; instalando sem verificação."
    fi

    if [[ $file == *.deb ]]; then
      pkg_install_file "$file"
    else
      case $PKG in
        dnf)    pkg_install fuse-libs ;;
        pacman) pkg_install fuse2 ;;
      esac
      mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
      install -m 0755 "$file" "$HOME/.local/bin/wttp"
      printf '[Desktop Entry]\nType=Application\nName=Wttp\nExec=%s/.local/bin/wttp --no-sandbox\nCategories=Development;\nTerminal=false\n' "$HOME" \
        > "$HOME/.local/share/applications/wttp.desktop"
    fi
    local rc=$?
    rm -rf "$tmp"
    return $rc
  fi

  rm -rf "$tmp"
  warn "Nenhum binário publicado; compilando a partir do código-fonte."
  local dir=$REPOS_DIR/Wttp
  clone_or_update https://github.com/wesleyara/Wttp.git "$dir" || return 1
  load_nvm || return 1
  (cd "$dir" && yarn && yarn build:linux) || return 1
  warn "Instalador gerado em $dir/dist (ou release/): instale o pacote resultante manualmente."
}

_repo_pano() {
  if ! is_gnome; then
    warn "GNOME não detectado; pulando gnome-shell-pano."
    SKIP_LIST+=("gnome-shell-pano (ambiente não é GNOME)")
    return 0
  fi

  info "Instalando dependências de runtime do Pano..."
  case $PKG in
    apt)    pkg_install gir1.2-gda-5.0 gir1.2-gsound-1.0 ;;
    dnf)    pkg_install libgda libgda-sqlite gsound ;;
    pacman) pkg_install libgda6 gsound ;;
  esac || return 1

  local dir=$REPOS_DIR/gnome-shell-pano
  clone_or_update https://github.com/wesleyara/gnome-shell-pano.git "$dir" feat/gnome-50-support || return 1
  load_nvm || { err "nvm indisponível: rode o passo 'node' antes."; return 1; }
  (cd "$dir" && yarn install && yarn build) || return 1

  local ext=$HOME/.local/share/gnome-shell/extensions
  mkdir -p "$ext"
  ln -sfn "$dir/dist" "$ext/pano@elhan.io"
  if gnome-extensions enable pano@elhan.io 2>/dev/null; then
    ok "Extensão Pano habilitada."
  else
    warn "Habilite após o relogin: gnome-extensions enable pano@elhan.io"
  fi
  need_restart "Faça LOGOUT/LOGIN para o GNOME Shell carregar a extensão Pano."
}

step_repos() {
  mkdir -p "$REPOS_DIR"
  local failed=() r
  for r in dockerlocal clicklocal wttp pano; do
    section "Repositório: $r"
    if is_wsl && [[ $r == pano ]]; then
      warn "WSL: pulando gnome-shell-pano."
      continue
    fi
    "_repo_$r" || { err "Falha em $r."; failed+=("$r"); }
  done
  ((${#failed[@]} == 0)) || { err "Com falha: ${failed[*]}"; return 1; }
}
