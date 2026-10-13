#!/usr/bin/env bash
# oh-my-zsh, plugins, tema spaceship e zsh como shell padrão.

step_shell() {
  local zsh_dir=${ZSH:-$HOME/.oh-my-zsh}
  local custom=${ZSH_CUSTOM:-$zsh_dir/custom}

  if [[ ! -d $zsh_dir ]]; then
    info "Instalando oh-my-zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
      || return 1
  else
    ok "oh-my-zsh já instalado."
  fi

  mkdir -p "$custom/plugins" "$custom/themes"
  local name url
  for pair in \
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"; do
    name=${pair%% *}; url=${pair##* }
    if [[ -d $custom/plugins/$name ]]; then
      ok "$name já instalado."
    else
      info "Instalando $name..."
      git clone --depth=1 "$url" "$custom/plugins/$name" || return 1
    fi
  done

  if [[ ! -d $custom/themes/spaceship-prompt ]]; then
    info "Instalando tema spaceship..."
    git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git \
      "$custom/themes/spaceship-prompt" || return 1
  else
    ok "spaceship já instalado."
  fi
  ln -sf "$custom/themes/spaceship-prompt/spaceship.zsh-theme" "$custom/themes/spaceship.zsh-theme"

  local rc=$HOME/.zshrc
  touch "$rc"
  if grep -qE '^ZSH_THEME=' "$rc"; then
    sed -i -E 's|^ZSH_THEME=.*|ZSH_THEME="spaceship"|' "$rc"
  else
    printf '\nZSH_THEME="spaceship"\n' >> "$rc"
  fi
  if ! grep -qE '^plugins=.*zsh-autosuggestions' "$rc"; then
    if grep -qE '^plugins=\(' "$rc"; then
      sed -i -E 's|^plugins=\(.*\)$|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' "$rc"
    else
      printf '\nplugins=(git zsh-autosuggestions zsh-syntax-highlighting)\n' >> "$rc"
    fi
  fi
  ok "~/.zshrc configurado (tema spaceship + plugins)."

  local zsh_path; zsh_path=$(command -v zsh)
  if [[ $(getent passwd "$USER" | cut -d: -f7) != "$zsh_path" ]]; then
    grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    info "Definindo zsh como shell padrão..."
    if sudo chsh -s "$zsh_path" "$USER"; then
      need_restart "Faça LOGOUT/LOGIN para o zsh virar o shell padrão."
    else
      return 1
    fi
  else
    ok "zsh já é o shell padrão."
  fi
}
