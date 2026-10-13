# linux-bootstrap

Configura uma máquina Linux (Debian/Ubuntu, Fedora, Arch) com um comando.

```bash
git clone https://github.com/wesleyara/linux-boostrap.git ~/linux-bootstrap && bash ~/linux-bootstrap/bootstrap.sh
```

## O que faz

| Passo    | Ação |
|----------|------|
| `base`   | zsh, git, curl, build tools |
| `shell`  | oh-my-zsh, zsh-autosuggestions, zsh-syntax-highlighting, tema spaceship, zsh como shell padrão |
| `git`    | `user.name`/`user.email`, chave SSH ed25519, cadastro no GitHub (via `gh` ou manual) |
| `docker` | Docker Engine + compose plugin, usuário no grupo `docker` |
| `fonts`  | JetBrains Mono |
| `apps`   | Claude Code, VS Code, Chrome, Discord |
| `node`   | nvm + versão do Node escolhida (+ yarn/pnpm) |
| `repos`  | DockerLocal (`:5100`), ClickLocal (`:8880`), Wttp e gnome-shell-pano (só GNOME) em `~/dev` |

## Opções

```
--yes            aceita todos os padrões (sem perguntas)
--skip a,b       pula passos (ex.: --skip fonts,apps)
--only a,b       executa só estes passos
```

Todas as perguntas são feitas no início; depois a instalação roda sem interação (exceto
senha do sudo e, opcionalmente, login do `gh`).

## Reinícios

Ao final, o bloco **AÇÃO NECESSÁRIA** lista o que exige logout/login:
shell padrão (zsh), grupo `docker` e a extensão Pano. O script oferece encerrar a sessão, nunca automaticamente.

## Notas
- Idempotente: pode ser executado várias vezes.
- Em WSL, apps gráficos, fontes e Pano são pulados.
- Chrome/VS Code no Arch exigem `yay`/`paru` (AUR); há fallback via Flatpak para o VS Code.
- O app desktop do Claude não tem pacote oficial Linux; instala-se o Claude Code (CLI).
