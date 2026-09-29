#!/usr/bin/env bash
# Environment probe for the nextcloud-issue-fix skill. Read-only, prints one line per check.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "FAIL repo: not inside a git worktree"; exit 1; }
status=0

ok()   { printf 'OK   %s\n' "$1"; }
bad()  { printf 'FAIL %s — %s\n' "$1" "$2"; status=1; }
warn() { printf 'WARN %s — %s\n' "$1" "$2"; }

[ -f lib/composer/autoload/autoload.php ] \
  && ok "composer deps (lib/composer)" \
  || bad "composer deps" "run: composer install"

[ -d node_modules/@nextcloud/e2e-test-server ] \
  && ok "node deps + e2e-test-server" \
  || bad "node deps" "run: npm ci (needed for the Playwright Docker harness)"

[ -d 3rdparty/sabre ] \
  && ok "3rdparty submodule" \
  || bad "3rdparty" "run: git submodule update --init --depth 1"

if [ -d dist/core ] || [ -n "$(ls -A dist 2>/dev/null)" ]; then
  ok "dist/ present"
else
  warn "dist/" "no build output; npm run build needed before JS verification"
fi

docker info >/dev/null 2>&1 \
  && ok "docker daemon" \
  || bad "docker" "daemon not reachable — needed for the verification harness"

gh auth status >/dev/null 2>&1 \
  && ok "gh authenticated" \
  || bad "gh auth" "run: gh auth login (needed for issue queries and PR creation)"

remote_url=$(git remote get-url origin 2>/dev/null)
case "$remote_url" in
  *devapro/nextcloud-server*) ok "origin is the fork ($remote_url)" ;;
  *) bad "origin" "expected fork devapro/nextcloud-server, got: $remote_url" ;;
esac

base=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || echo "origin/develop")
git fetch origin develop --quiet 2>/dev/null
behind=$(git rev-list --count HEAD..origin/develop 2>/dev/null || echo "?")
[ "$behind" = "0" ] && ok "branch up to date with origin/develop" \
  || warn "freshness" "HEAD is $behind commits behind origin/develop — rebase before fixing"

if (exec 3<>/dev/tcp/127.0.0.1/8042) 2>/dev/null; then
  warn "port 8042" "already listening — an existing harness/container will be reused"
else
  ok "port 8042 free"
fi

[ -d .qoder/issue-fix ] || mkdir -p .qoder/issue-fix
dirty=$(git status --porcelain | grep -v '^?? \.qoder/' | head -5)
[ -z "$dirty" ] && ok "clean working tree" || warn "dirty tree" "uncommitted changes exist: $dirty"

exit $status
