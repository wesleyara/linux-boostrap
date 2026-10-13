#!/usr/bin/env bash
# Bootstrap de máquina Linux: shell, git/SSH, Docker, apps, fontes, Node e projetos.
# Uso: bash bootstrap.sh [--yes] [--skip passo1,passo2] [--only passo1,passo2] [--help]
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/pkg.sh"
for f in "$SCRIPT_DIR"/steps/*.sh; do
  # shellcheck disable=SC1090
  source "$f"
done

STEP_IDS=(base shell git docker fonts apps node repos)
declare -A STEP_LABEL=(
  [base]="zsh, git e ferramentas básicas"
  [shell]="oh-my-zsh + autosuggestions + syntax-highlighting + spaceship (zsh padrão)"
  [git]="Git + chave SSH para o GitHub"
  [docker]="Docker Engine + compose plugin"
  [fonts]="JetBrains Mono"
  [apps]="Claude Code, VS Code, Chrome, Discord"
  [node]="nvm + Node (você escolhe a versão)"
  [repos]="DockerLocal, ClickLocal, Wttp e gnome-shell-pano"
)
declare -A SELECTED=()
for id in "${STEP_IDS[@]}"; do SELECTED[$id]=1; done

usage() {
  sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//'
  printf 'Passos: %s\n' "${STEP_IDS[*]}"
}

ONLY=
while (($#)); do
  case $1 in
    -y|--yes) ASSUME_YES=1 ;;
    --skip) shift; IFS=, read -ra s <<<"${1:-}"; for id in "${s[@]}"; do SELECTED[$id]=0; done ;;
    --only) shift; ONLY=${1:-} ;;
    -h|--help) usage; exit 0 ;;
    *) die "Argumento desconhecido: $1" ;;
  esac
  shift
done
if [[ -n $ONLY ]]; then
  for id in "${STEP_IDS[@]}"; do SELECTED[$id]=0; done
  IFS=, read -ra s <<<"$ONLY"; for id in "${s[@]}"; do SELECTED[$id]=1; done
fi

[[ $EUID -ne 0 ]] || die "Não rode como root; o script usa sudo quando necessário."
[[ -t 0 || -r /dev/tty ]] || die "Terminal interativo necessário (ou use --yes)."

section "Linux bootstrap"
detect_distro
info "Distro: $DISTRO_ID (gerenciador: $PKG)"
is_wsl && warn "WSL detectado: apps gráficos, fontes e extensão GNOME serão pulados."

# ── menu interativo ────────────────────────────────────────────────
if [[ $ASSUME_YES != 1 ]]; then
  printf '\nComponentes a instalar:\n'
  n=1
  for id in "${STEP_IDS[@]}"; do
    mark='x'; [[ ${SELECTED[$id]} == 1 ]] || mark=' '
    printf '  %d) [%s] %s\n' "$n" "$mark" "${STEP_LABEL[$id]}"
    n=$((n + 1))
  done
  ask toggle "Números para DESMARCAR, separados por espaço (Enter = instalar tudo)" ""
  for num in $toggle; do
    [[ $num =~ ^[1-8]$ ]] && SELECTED[${STEP_IDS[$((num - 1))]}]=0
  done
fi

# ── perguntas (todas antes de instalar) ────────────────────────────
section "Configuração"
if [[ ${SELECTED[git]} == 1 ]]; then
  ask GIT_NAME  "Nome para o Git (user.name)" "$(git config --global user.name 2>/dev/null || true)"
  ask GIT_EMAIL "E-mail para o Git (user.email)" "$(git config --global user.email 2>/dev/null || echo wesleyara.contato@gmail.com)"
  ask GH_USER   "Usuário do GitHub" "$(git config --global github.user 2>/dev/null || echo wesleyara)"
fi
if [[ ${SELECTED[node]} == 1 ]]; then
  ask NODE_VERSION "Versão do Node a instalar via nvm (lts/*, 22, 20, 18.20.4...)" "lts/*"
fi
if [[ ${SELECTED[repos]} == 1 ]]; then
  ask REPOS_DIR "Diretório para clonar os repositórios" "$HOME/dev"
  REPOS_DIR=${REPOS_DIR/#\~/$HOME}
  ask PROJECTS_ROOT "Raiz dos seus projetos (exposta ao DockerLocal)" "$REPOS_DIR"
  PROJECTS_ROOT=${PROJECTS_ROOT/#\~/$HOME}
fi
export GIT_NAME GIT_EMAIL GH_USER NODE_VERSION REPOS_DIR PROJECTS_ROOT

# ── sudo uma única vez + keepalive ────────────────────────────────
info "Solicitando sudo (a senha é pedida uma vez)..."
sudo -v || die "sudo necessário."
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT

# ── execução ───────────────────────────────────────────────────────
for id in "${STEP_IDS[@]}"; do
  if [[ ${SELECTED[$id]} != 1 ]]; then
    SKIP_LIST+=("${STEP_LABEL[$id]}")
    continue
  fi
  if is_wsl && [[ $id == fonts ]]; then
    SKIP_LIST+=("${STEP_LABEL[$id]} (WSL: instale a fonte no Windows)")
    continue
  fi
  section "${STEP_LABEL[$id]}"
  if "step_$id"; then
    OK_LIST+=("${STEP_LABEL[$id]}")
  else
    FAIL_LIST+=("${STEP_LABEL[$id]}")
  fi
done

print_summary

if ((${#PENDING[@]})) && ! is_wsl; then
  printf '\n'
  if confirm "Encerrar a sessão agora para aplicar as mudanças? (salve seu trabalho antes)" N; then
    loginctl terminate-user "$USER"
  else
    info "Ok. Lembre-se de fazer logout/login depois."
  fi
elif ((${#PENDING[@]})); then
  info "No WSL, rode no PowerShell: wsl --shutdown  (depois abra o WSL novamente)."
fi

((${#FAIL_LIST[@]} == 0))
