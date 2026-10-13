#!/usr/bin/env bash
# JetBrains Mono em ~/.local/share/fonts.

step_fonts() {
  local dest=$HOME/.local/share/fonts/JetBrainsMono
  if compgen -G "$dest/*.ttf" >/dev/null; then
    ok "JetBrains Mono já instalada."
    return 0
  fi

  local url tmp
  url=$(github_asset JetBrains/JetBrainsMono 'JetBrainsMono-[0-9.]+\.zip$') || true
  [[ -n $url ]] || { err "Não foi possível localizar o release do JetBrains Mono."; return 1; }

  tmp=$(mktemp -d)
  info "Baixando $url"
  download "$url" "$tmp/jb.zip" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$dest"
  unzip -q -o "$tmp/jb.zip" 'fonts/ttf/*.ttf' -d "$tmp/out" || { rm -rf "$tmp"; return 1; }
  cp "$tmp"/out/fonts/ttf/*.ttf "$dest/"
  rm -rf "$tmp"
  fc-cache -f >/dev/null 2>&1 || true
  ok "JetBrains Mono instalada. Selecione-a nas preferências do seu terminal/editor."
}
