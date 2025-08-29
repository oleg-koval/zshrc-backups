##### Aliases
alias c='clear'
alias l='ls -la'
alias reload='source ~/.zshrc'
alias f='open .'
alias nb='git checkout -b'

# Git
alias gs='git status'
alias gst='git status'
alias gco='git checkout'
alias ga='git add'
alias gaa='git add .'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate'
alias gb='git branch'
alias gbd='git branch -d'
alias gbl='git blame'
alias glg='git log --graph --decorate --oneline --all --date=relative'
groot() { cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"; }
alias gsw='git switch'
alias gco-='git checkout -'
alias gap='git add -p'
alias gsta='git stash push -u'
alias gstp='git stash pop'
alias gstl='git stash list'
alias grhh='git reset --hard HEAD'
gfixup() { git commit --fixup "$@" && GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash "$(git merge-base HEAD @{u})"; }
gprune() { git remote prune origin && git fetch -p && git branch --merged | grep -vE '(\*|main|master|develop)' | xargs -n1 -I{} git branch -d {}; }


##### Handy utils
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias path='echo $PATH | tr ":" "\n"'
alias serve='python3 -m http.server 8000'
alias please='sudo $(fc -ln -1)'
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# Extract archives
extract() {
  local f="$1"; [[ -f "$f" ]] || { echo "file not found: $f"; return 1; }
  case "$f" in
    *.tar.bz2|*.tbz2) tar xjf "$f" ;;
    *.tar.gz|*.tgz)   tar xzf "$f" ;;
    *.tar.xz)         tar xJf "$f" ;;
    *.tar)            tar xf "$f"  ;;
    *.zip)            unzip -q "$f" ;;
    *.rar)            unrar x "$f" ;;
    *.7z)             7z x "$f" ;;
    *) echo "don't know how to extract '$f'"; return 2;;
  esac
}

# grep/ripgrep
if (( $+commands[rg] )); then
  alias grep='rg --color=auto -n'
  alias grepr='rg -n -uu'
else
  alias grep='grep --color=auto -n'
  alias grepr='grep -RIn'
fi

# Disk / ports / IPs (macOS)
alias dsize='du -sh * | sort -h'
alias ports='lsof -nP -iTCP -sTCP:LISTEN'
whichport() { lsof -nP -iTCP:"$1" -sTCP:LISTEN; }
killport() { lsof -t -i:"$1" | xargs -r kill -9; }
alias myip='curl -s https://ifconfig.me || curl -s https://ipinfo.io/ip'
alias localip="ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null"

##### Docker / Compose helpers
# Build and up one or more services
dbuild() {
  local dc="docker compose"; $dc version >/dev/null 2>&1 || dc="docker-compose"
  (( $# )) || { echo "usage: dbuild <service> [service …]"; return 1; }
  $dc build "$@" && $dc up -d "$@"
}

# Logs
dlogs() {
  local dc="docker compose"; $dc version >/dev/null 2>&1 || dc="docker-compose"
  (( $# )) || { echo "usage: dlogs <service> [service…]"; return 1; }
  $dc logs -f --tail=200 "$@"
}

# Shell into first container of a service
dsh() {
  local svc="$1"; shift || true
  local cid
  cid="$(docker compose ps -q "$svc" 2>/dev/null || docker-compose ps -q "$svc")"
  [[ -n "$cid" ]] || { echo "no container for service: $svc"; return 1; }
  docker exec -it "$cid" sh -lc 'command -v bash >/dev/null && exec bash || exec sh'
}

# Stop & remove service containers
dkill() {
  local dc="docker compose"; $dc version >/dev/null 2>&1 || dc="docker-compose"
  (( $# )) || { echo "usage: dkill <service> [service…]"; return 1; }
  $dc rm -sf "$@"
}

alias dprune='docker system prune -af --volumes'

# Quick docker ps table
unalias dps 2>/dev/null
dps() { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; }

# dclean — YSU-safe (no 'no_unset'), portable
dclean() {
  emulate -L zsh -o pipefail
  local dc
  if docker compose version >/dev/null 2>&1; then
    dc="docker compose"
  elif command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
    dc="docker-compose"
  else
    echo "[x] docker compose not found."; return 1
  fi

  # Allow running from anywhere via envs
  local project_dir="${DCLEAN_PROJECT_DIR:-$PWD}"
  local -a dc_args
  if [[ -n "${DCLEAN_COMPOSE_FILES:-}" ]]; then
    local f; for f in ${(s[:])DCLEAN_COMPOSE_FILES}; do dc_args+=(-f "$f"); done
  fi
  _dc() { ( cd "$project_dir" && eval "$dc" "${(q@)dc_args}" "${(q@)}" ); }

  _dc config >/dev/null 2>&1 || {
    echo "[x] Not a Docker Compose project directory."
    echo "    Tip: cd into the project or export DCLEAN_PROJECT_DIR=/path"
    return 1
  }

  local -a services
  if (( $# == 0 )); then
    services=(${(f)$(_dc config --services)})
  else
    services=("$@")
  fi

  echo "🎯  Target services:"; printf "  -  %s\n" "${services[@]}"; echo "──────────────────────────────"

  local -a cids svc_cids
  local s; for s in "${services[@]}"; do
    svc_cids=(${(f)$(_dc ps -q "$s" 2>/dev/null)})
    (( ${#svc_cids[@]} )) && cids+=("${svc_cids[@]}")
  done

  local -a cname; local cid name
  for cid in "${cids[@]}"; do
    name="$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null)"; name="${name#/}"
    [[ -n "$name" ]] && cname+=("$name")
  done

  local -a vols imgs; local img_id v
  for cid in "${cids[@]}"; do
    for v in ${(f)$(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' "$cid" 2>/dev/null)}; do
      [[ -n "$v" ]] && vols+=("$v")
    done
    img_id="$(docker inspect -f '{{.Image}}' "$cid" 2>/dev/null)"
    [[ -n "$img_id" ]] && imgs+=("$img_id")
  done

  local -a uniq_vols uniq_imgs
  uniq_vols=(${(u)vols}); uniq_imgs=(${(u)imgs})

  echo "🗑️  Removing containers..."; echo "──────────────────────────────"
  if (( ${#cname[@]} )); then printf '  📦 %s\n' "${cname[@]}"; else echo "No containers to remove."; fi
  _dc rm -sfv "${services[@]}" >/dev/null 2>&1 || true

  echo "──────────────────────────────"; echo "🗑️  Removing volumes..."; echo "──────────────────────────────"
  if (( ${#uniq_vols[@]} )); then printf '  🗄️  %s\n' "${uniq_vols[@]}"; docker volume rm -f "${uniq_vols[@]}" >/dev/null 2>&1 || true
  else echo "No volumes to remove."; fi

  echo "──────────────────────────────"; echo "🗑️  Removing images..."; echo "──────────────────────────────"
  if (( ${#uniq_imgs[@]} )); then
    local img ref short
    for img in "${uniq_imgs[@]}"; do
      short="${${img#sha256:}:0:12}"
      ref="$(docker image inspect --format '{{if .RepoTags}}{{index .RepoTags 0}}{{else}}<untagged>{{end}}' "$img" 2>/dev/null)"
      echo "  🖼️  ${short:-$img} ${ref}"
    done
    docker image rm -f "${uniq_imgs[@]}" >/dev/null 2>&1 || true
  else echo "No images to remove."; fi

  echo "🔄  Rebuilding services..."; echo "──────────────────────────────"
  echo "🛠️  Building Docker Compose services..."; echo "──────────────────────────────"
  if _dc build "${services[@]}"; then echo "🎉  All services built successfully!"; else echo "❌  One or more services failed to build."; fi

  echo "🚀  Starting services..."; echo "──────────────────────────────"
  _dc up -d "${services[@]}"; echo "[✓] Done."
}

# --- zshrc backups (1-click) ---
zrcb() {  # backup current ~/.zshrc, commit, and (if configured) push
  ( set -e
    local BDIR="$HOME/.config/zshrc-backups"
    mkdir -p "$BDIR"
    local TS="$(date +%Y%m%d-%H%M%S)"
    cp "$HOME/.zshrc" "$BDIR/zshrc.$TS"
    cd "$BDIR"
    git add .
    git commit -m "zshrc $TS" >/dev/null
    git push >/dev/null 2>&1 || true
    echo "✓ zshrc backed up to $BDIR (commit $(git rev-parse --short HEAD))"
  )
}
alias zbackup=zrcb

# Set or create a remote for zshrc backups
zrcb-remote() {  # usage: zrcb-remote <git-remote-url> [remote-name=origin]
  local url="$1"; local name="${2:-origin}"
  if [[ -z "$url" ]]; then
    echo "usage: zrcb-remote <git-remote-url> [remote-name]"
    echo "ex:   zrcb-remote git@github.com:<you>/zshrc-backups.git"
    return 2
  fi
  ( set -e
    cd "$HOME/.config/zshrc-backups"
    git remote remove "$name" 2>/dev/null || true
    git remote add "$name" "$url"
    git branch -M main
    git push -u "$name" main
    echo "✓ remote '$name' set to $url"
  )
}

# Show backup status
zrcb-status() {
  ( cd "$HOME/.config/zshrc-backups" || return
    echo "Remote(s):"; git remote -v
    echo; echo "Recent commits:"; git --no-pager log --oneline -n 5
  )
}

# One-liner using GitHub CLI (auto-creates repo), requires 'gh auth login'
zrcb-remote-gh() {  # usage: zrcb-remote-gh [repo-name=zshrc-backups] [visibility=private]
  local repo="${1:-zshrc-backups}" vis="${2:-private}"
  command -v gh >/dev/null || { echo "gh not found. Install GitHub CLI."; return 1; }
  ( set -e
    cd "$HOME/.config/zshrc-backups"
    gh repo create "$repo" --"$vis" --source . --remote origin --push
    echo "✓ created and pushed to GitHub: $repo ($vis)"
  )
}

# optional: restore the most recent backup
zrestore() {
  local BDIR="$HOME/.config/zshrc-backups"
  local LAST="$(ls -1 "$BDIR"/zshrc.* 2>/dev/null | tail -n1)"
  [[ -n "$LAST" ]] || { echo "no backups found in $BDIR"; return 1; }
  cp "$LAST" "$HOME/.zshrc"
  echo "✓ restored $LAST → ~/.zshrc  (reload with: source ~/.zshrc)"
}
# --- end backups ---


# show current plugins
plugs() { print -rl -- $plugins }

# add one safely
plug-add() {
  local p; for p in "$@"; do
    (( ${plugins[(Ie)$p]} )) || plugins+=("$p")
  done
  printf 'plugins=(%s)\n' "${plugins[@]}" | sed 's/ / /g'
  echo "Now run: zbackup && source ~/.zshrc"
}

# backup daily
alias backup='~/.local/bin/zshrc_backup_daily.sh'

# edit aliases
alias edit-aliases='cursor ~/.zsh/aliases.zsh'

alias bpc='AWS_PROFILE=bizcuit-prd-core aws rds generate-db-auth-token --hostname bd1aohrleo1hkas.ca9zxcdegy6a.eu-west-1.rds.amazonaws.com --port 5432 --region eu-west-1 --username user_oleg.koval | tr -d "\n" | pbcopy'

alias token-core='
aws rds generate-db-auth-token \
  --hostname bd1aohrleo1hkas.ca9zxcdegy6a.eu-west-1.rds.amazonaws.com \
  --port 5432 \
  --region eu-west-1 \
  --username user_oleg.koval \
  --profile bizcuit-prd-core | tr -d "\n" | pbcopy
'

alias token-nc='
aws rds generate-db-auth-token \
  --hostname bd1p4a27j5q3mll.c6h3k4kc4ytk.eu-west-1.rds.amazonaws.com \
  --port 5432 \
  --region eu-west-1 \
  --username user_oleg \
  --profile bizcuit-prd | tr -d "\n" | pbcopy
'
