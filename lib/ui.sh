#!/usr/bin/env bash
# Helpers de interface: cores, logs, perguntas interativas e resumo final.

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=
fi

ASSUME_YES=${ASSUME_YES:-0}
PENDING=()     # ações que exigem logout/reboot
OK_LIST=()
FAIL_LIST=()
SKIP_LIST=()

section() { printf '\n%s%s━━ %s ━━%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"; }
info()    { printf '%s➜%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()      { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()     { printf '%s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()     { err "$*"; exit 1; }

# ask VAR "pergunta" "padrão" — lê do terminal (funciona mesmo com stdin redirecionado)
ask() {
  local __var=$1 prompt=$2 def=${3:-} reply=
  if [[ $ASSUME_YES == 1 ]]; then
    printf -v "$__var" '%s' "$def"
    return 0
  fi
  read -r -p "${C_BOLD}?${C_RESET} ${prompt}${def:+ [$def]}: " reply </dev/tty || reply=
  printf -v "$__var" '%s' "${reply:-$def}"
}

# confirm "pergunta" [Y|N] — retorna 0 para sim
confirm() {
  local prompt=$1 def=${2:-Y} reply= hint='[S/n]'
  [[ $def == N ]] && hint='[s/N]'
  if [[ $ASSUME_YES == 1 ]]; then
    [[ $def == Y ]]
    return
  fi
  read -r -p "${C_BOLD}?${C_RESET} ${prompt} ${hint}: " reply </dev/tty || reply=
  reply=${reply:-$def}
  [[ $reply =~ ^([sSyY]|sim|yes)$ ]]
}

pause() {
  [[ $ASSUME_YES == 1 ]] && return 0
  read -r -p "${C_BOLD}Pressione Enter para continuar...${C_RESET}" _ </dev/tty || true
}

need_restart() { PENDING+=("$*"); }

download() { # download URL DEST
  curl -fL --retry 3 --retry-delay 2 -sS -o "$2" "$1"
}

# Mostra o resumo final e orienta sobre reinícios.
print_summary() {
  section "Resumo"
  local i
  for i in "${OK_LIST[@]:-}"; do [[ -n $i ]] && ok "$i"; done
  for i in "${SKIP_LIST[@]:-}"; do [[ -n $i ]] && warn "Pulado: $i"; done
  for i in "${FAIL_LIST[@]:-}"; do [[ -n $i ]] && err "Falhou: $i"; done

  if ((${#PENDING[@]})); then
    printf '\n%s%s╔══════════════ AÇÃO NECESSÁRIA ══════════════╗%s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET"
    for i in "${PENDING[@]}"; do printf '%s  • %s%s\n' "$C_YELLOW" "$i" "$C_RESET"; done
    printf '%s%s╚═════════════════════════════════════════════╝%s\n' "$C_BOLD" "$C_YELLOW" "$C_RESET"
    printf 'Encerre a sessão (logout) e entre novamente, ou reinicie a máquina.\n'
  else
    printf '\n%sNenhum reinício necessário.%s\n' "$C_GREEN" "$C_RESET"
  fi
}
