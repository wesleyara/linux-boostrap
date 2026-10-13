#!/usr/bin/env bash
# nvm + versão do Node escolhida pelo usuário.

step_node() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [[ ! -s $NVM_DIR/nvm.sh ]]; then
    local tag
    tag=$(github_latest_json nvm-sh/nvm 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    tag=${tag:-v0.40.3}
    info "Instalando nvm $tag..."
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$tag/install.sh" | PROFILE=/dev/null bash || return 1
  else
    ok "nvm já instalado."
  fi

  zshrc_block "nvm" 'export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

  load_nvm || return 1

  local version=${NODE_VERSION:-lts/*} attempt
  for attempt in 1 2 3; do
    info "Instalando Node '$version'..."
    if nvm install "$version"; then
      nvm alias default "$version" >/dev/null
      nvm use default >/dev/null
      break
    fi
    err "Versão inválida: $version"
    [[ $attempt == 3 || $ASSUME_YES == 1 ]] && return 1
    ask version "Informe outra versão do Node (ex.: lts/*, 22, 20.18.0)" "lts/*"
  done

  corepack enable >/dev/null 2>&1 || true
  command -v yarn >/dev/null 2>&1 || npm install -g yarn || warn "Não foi possível instalar yarn."
  command -v pnpm >/dev/null 2>&1 || npm install -g pnpm || warn "Não foi possível instalar pnpm."
  ok "Node $(node -v) ativo (padrão do nvm)."
}
