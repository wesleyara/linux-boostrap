#!/usr/bin/env bash
# Configura Git, gera chave SSH e orienta o cadastro no GitHub.

step_git() {
  local key=$HOME/.ssh/id_ed25519

  if [[ -n ${GIT_NAME:-} ]]; then git config --global user.name "$GIT_NAME"; fi
  if [[ -n ${GIT_EMAIL:-} ]]; then git config --global user.email "$GIT_EMAIL"; fi
  if [[ -n ${GH_USER:-} ]]; then git config --global github.user "$GH_USER"; fi
  git config --global init.defaultBranch main
  git config --global pull.ff only
  ok "Git configurado: $(git config --global user.name) <$(git config --global user.email)>"

  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  if [[ -f $key ]]; then
    ok "Chave SSH já existe em $key"
  else
    info "Gerando chave SSH ed25519..."
    ssh-keygen -t ed25519 -C "${GIT_EMAIL:-$USER@$(hostname)}" -f "$key" -N "" || return 1
  fi

  if ! grep -q 'github.com' "$HOME/.ssh/config" 2>/dev/null; then
    cat >> "$HOME/.ssh/config" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile $key
  AddKeysToAgent yes
  StrictHostKeyChecking accept-new
EOF
    chmod 600 "$HOME/.ssh/config"
  fi

  if ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q 'successfully authenticated'; then
    ok "Chave SSH já autorizada no GitHub."
    return 0
  fi

  # Tenta enviar via gh CLI (opcional)
  command -v gh >/dev/null 2>&1 || pkg_install gh >/dev/null 2>&1 || true
  if command -v gh >/dev/null 2>&1 && confirm "Usar o GitHub CLI (gh) para autenticar e enviar a chave automaticamente?"; then
    gh auth login -h github.com -p ssh -w \
      && gh ssh-key add "$key.pub" --title "$(hostname)-$(date +%Y%m%d)" \
      && ok "Chave enviada ao GitHub via gh."
  fi

  if ! ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q 'successfully authenticated'; then
    printf '\n%sSua chave pública (copie e adicione em https://github.com/settings/ssh/new):%s\n\n' "$C_BOLD" "$C_RESET"
    cat "$key.pub"
    printf '\n'
    pause
    if ssh -T -o BatchMode=yes git@github.com 2>&1 | grep -q 'successfully authenticated'; then
      ok "Autenticação SSH com o GitHub funcionando."
    else
      warn "Não foi possível validar o SSH agora; adicione a chave e teste com: ssh -T git@github.com"
    fi
  fi
}
