#!/bin/zsh
# backup.sh — snapshot of the rapidnative-coach setup for safe rollback.
# Captures: repo tree, launchd plists, ~/.config/claude state, Bot Chrome
# profile (cookies, no caches), auto-memory, linked-site git status.
# Writes a self-contained restore.sh inside the backup dir.
#
# Usage:  accountability/routines/backup.sh  [optional-tag]
#         (timestamp is always part of the dir; tag is appended if given)

set -e

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
TAG="${1:-}"
SUFFIX="$TIMESTAMP${TAG:+-$TAG}"

PROJECT="/Users/agni/Documents/rapidclaw"
SLUG="rapidnative-coach"
BACKUP_ROOT="$HOME/rapidclaw-backups/$SUFFIX"

if [ ! -d "$PROJECT" ]; then
  echo "ERROR: project dir not found at $PROJECT" >&2
  exit 1
fi

mkdir -p "$BACKUP_ROOT"/{repo,launchd,config,chrome-profile,auto-memory,linked-sites}

echo "=== Backing up to $BACKUP_ROOT ==="

# 1. Repo snapshot
echo "[1/7] Repo tree → repo/rapidclaw.tar.gz"
cd "$PROJECT"
git status --porcelain > "$BACKUP_ROOT/repo/git-status.txt" 2>/dev/null || true
git log --oneline -30 > "$BACKUP_ROOT/repo/git-log.txt" 2>/dev/null || true
git branch --show-current > "$BACKUP_ROOT/repo/branch.txt" 2>/dev/null || true
tar --exclude="rapidclaw/accountability/listener/node_modules" \
    --exclude="rapidclaw/.git/lfs" \
    -czf "$BACKUP_ROOT/repo/rapidclaw.tar.gz" \
    -C "$(dirname "$PROJECT")" "$(basename "$PROJECT")"

# 2. launchd plists
echo "[2/7] launchd plists → launchd/"
cp -a "$HOME/Library/LaunchAgents/com.agni.${SLUG}-"*.plist "$BACKUP_ROOT/launchd/" 2>/dev/null || true
launchctl list 2>/dev/null | grep "${SLUG}" > "$BACKUP_ROOT/launchd/loaded-jobs.txt" || true

# 3. Config / state files
echo "[3/7] ~/.config/claude/${SLUG}-* → config/"
cp -a "$HOME/.config/claude/${SLUG}-"* "$BACKUP_ROOT/config/" 2>/dev/null || true

# 4. Bot Chrome profile — cookies + login state, NOT caches
if [ -d "$HOME/.rapidclaw-chrome-profile" ]; then
  echo "[4/7] Bot Chrome profile (excluding caches) → chrome-profile/"
  tar -czf "$BACKUP_ROOT/chrome-profile/profile.tar.gz" \
      --exclude=".rapidclaw-chrome-profile/Default/Cache" \
      --exclude=".rapidclaw-chrome-profile/Default/Code Cache" \
      --exclude=".rapidclaw-chrome-profile/Default/GPUCache" \
      --exclude=".rapidclaw-chrome-profile/Default/Service Worker/CacheStorage" \
      --exclude=".rapidclaw-chrome-profile/Default/Application Cache" \
      --exclude=".rapidclaw-chrome-profile/ShaderCache" \
      --exclude=".rapidclaw-chrome-profile/GrShaderCache" \
      --exclude=".rapidclaw-chrome-profile/component_crx_cache" \
      --exclude=".rapidclaw-chrome-profile/optimization_guide_*" \
      -C "$HOME" .rapidclaw-chrome-profile
else
  echo "[4/7] Bot Chrome profile not found — skipping"
fi

# 5. Auto-memory
MEMORY_PARENT="$HOME/.claude/projects/-Users-agni-Documents-rapidclaw"
if [ -d "$MEMORY_PARENT/memory" ]; then
  echo "[5/7] Auto-memory → auto-memory/memory.tar.gz"
  tar -czf "$BACKUP_ROOT/auto-memory/memory.tar.gz" -C "$MEMORY_PARENT" memory
else
  echo "[5/7] Auto-memory dir not found — skipping"
fi

# 6. Linked-site git state (status only — sites have their own git history)
echo "[6/7] Linked-site git state → linked-sites/"
for SITE in rapidnative-website applighter-website tasks branding; do
  SYM="$PROJECT/sites/$SITE"
  [ -e "$SYM" ] || continue
  if [ -L "$SYM" ]; then
    SITE_REAL="$(readlink "$SYM")"
  else
    SITE_REAL="$SYM"
  fi
  [ -d "$SITE_REAL/.git" ] || continue
  mkdir -p "$BACKUP_ROOT/linked-sites/$SITE"
  (cd "$SITE_REAL" && {
    echo "$SITE_REAL" > "$BACKUP_ROOT/linked-sites/$SITE/path.txt"
    git status --porcelain > "$BACKUP_ROOT/linked-sites/$SITE/git-status.txt" 2>/dev/null || true
    git log --oneline -10 > "$BACKUP_ROOT/linked-sites/$SITE/git-log.txt" 2>/dev/null || true
    git branch --show-current > "$BACKUP_ROOT/linked-sites/$SITE/branch.txt" 2>/dev/null || true
    git stash list > "$BACKUP_ROOT/linked-sites/$SITE/stash.txt" 2>/dev/null || true
  })
done

# 7. MANIFEST + restore.sh
echo "[7/7] Writing MANIFEST.md + restore.sh"

cat > "$BACKUP_ROOT/MANIFEST.md" <<MANIFEST_EOF
# Backup snapshot · $SUFFIX

| Field | Value |
|---|---|
| Created | $(date) |
| Host | $(hostname) |
| User | $USER |
| Source project | $PROJECT |
| Slug | $SLUG |
| Repo branch at backup | $(cat "$BACKUP_ROOT/repo/branch.txt" 2>/dev/null || echo unknown) |
| Dirty files | $(wc -l < "$BACKUP_ROOT/repo/git-status.txt" 2>/dev/null | tr -d ' ') |
| Plists | $(ls "$BACKUP_ROOT/launchd"/*.plist 2>/dev/null | wc -l | tr -d ' ') |
| Config files | $(ls "$BACKUP_ROOT/config"/* 2>/dev/null | wc -l | tr -d ' ') |
| Chrome profile | $([ -f "$BACKUP_ROOT/chrome-profile/profile.tar.gz" ] && du -h "$BACKUP_ROOT/chrome-profile/profile.tar.gz" | cut -f1 || echo "—") |
| Auto-memory | $([ -f "$BACKUP_ROOT/auto-memory/memory.tar.gz" ] && du -h "$BACKUP_ROOT/auto-memory/memory.tar.gz" | cut -f1 || echo "—") |
| Total size | $(du -sh "$BACKUP_ROOT" | cut -f1) |

## Contents

\`\`\`
$(cd "$BACKUP_ROOT" && find . -maxdepth 2 -type f | sort | sed 's|^\./||')
\`\`\`

## What's NOT backed up (intentional)

- Per-thread worktrees (\`~/rapidclaw-worktrees/\`, \`~/rapidclaw-site-worktrees/\`) — disposable
- Linked-site working trees — independent git repos, restore from origin if needed
- Chrome caches — regeneratable on next browse
- /tmp/*.log runtime logs

## To restore

\`\`\`bash
$BACKUP_ROOT/restore.sh --dry-run    # preview, no writes
$BACKUP_ROOT/restore.sh --confirm    # actually restore (prompts before invasive steps)
\`\`\`
MANIFEST_EOF

# Generate restore.sh — values pre-baked for THIS backup
cat > "$BACKUP_ROOT/restore.sh" <<RESTORE_EOF
#!/bin/zsh
# Auto-generated restore script for backup $SUFFIX
# Restores: launchd plists, ~/.config/claude/${SLUG}-* state, Bot Chrome profile,
# auto-memory, and the repo tree at $PROJECT.
#
# Run --dry-run FIRST to preview every change.

set -e
BACKUP_DIR="$BACKUP_ROOT"
PROJECT="$PROJECT"
SLUG="$SLUG"

MODE=""
for arg in "\$@"; do
  case "\$arg" in
    --dry-run) MODE="dry" ;;
    --confirm) MODE="confirm" ;;
    *) echo "unknown arg: \$arg" >&2; exit 2 ;;
  esac
done

if [ -z "\$MODE" ]; then
  echo "Usage: \$0 [--dry-run | --confirm]"
  echo
  echo "Restores from: \$BACKUP_DIR"
  echo "Always run --dry-run first."
  exit 1
fi

run() {
  if [ "\$MODE" = "dry" ]; then
    echo "[DRY] \$*"
  else
    echo "[RUN] \$*"
    eval "\$*"
  fi
}

ask() {
  if [ "\$MODE" = "dry" ]; then return 0; fi
  printf "%s (y/n) " "\$1"
  read ans
  [ "\$ans" = "y" ] || [ "\$ans" = "Y" ]
}

echo "================================================================="
echo "  RESTORE from \$BACKUP_DIR"
echo "  Mode: \$MODE"
echo "================================================================="

# Step 1 — bootout listener + cron jobs
echo
echo "Step 1 — bootout existing launchd jobs"
for plist in "\$HOME/Library/LaunchAgents/com.agni.\${SLUG}-"*.plist; do
  [ -f "\$plist" ] || continue
  LABEL=\$(basename "\$plist" .plist)
  run "launchctl bootout gui/\$(id -u)/\$LABEL 2>/dev/null || true"
done

# Step 2 — restore plists
echo
echo "Step 2 — restore plists"
for plist in "\$BACKUP_DIR"/launchd/*.plist; do
  [ -f "\$plist" ] || continue
  DEST="\$HOME/Library/LaunchAgents/\$(basename "\$plist")"
  run "cp -a \"\$plist\" \"\$DEST\""
done

# Step 3 — restore config (Slack tokens, session state, processed-ts log, events)
echo
echo "Step 3 — restore ~/.config/claude/\${SLUG}-* files"
for f in "\$BACKUP_DIR"/config/*; do
  [ -f "\$f" ] || continue
  DEST="\$HOME/.config/claude/\$(basename "\$f")"
  run "cp -a \"\$f\" \"\$DEST\""
done

# Step 4 — Bot Chrome profile (large, confirm)
if [ -f "\$BACKUP_DIR/chrome-profile/profile.tar.gz" ]; then
  echo
  echo "Step 4 — restore Bot Chrome profile"
  echo "  size: \$(du -h "\$BACKUP_DIR/chrome-profile/profile.tar.gz" | cut -f1)"
  echo "  target: \$HOME/.rapidclaw-chrome-profile/  (will be REPLACED)"
  if ask "  confirm Chrome profile restore?"; then
    run "rm -rf \"\$HOME/.rapidclaw-chrome-profile\""
    run "tar -xzf \"\$BACKUP_DIR/chrome-profile/profile.tar.gz\" -C \"\$HOME\""
  else
    echo "  SKIPPED Chrome profile restore"
  fi
fi

# Step 5 — auto-memory
if [ -f "\$BACKUP_DIR/auto-memory/memory.tar.gz" ]; then
  echo
  echo "Step 5 — restore auto-memory"
  MEM_PARENT="\$HOME/.claude/projects/-Users-agni-Documents-rapidclaw"
  run "mkdir -p \"\$MEM_PARENT\""
  if [ -d "\$MEM_PARENT/memory" ]; then
    run "rm -rf \"\$MEM_PARENT/memory\""
  fi
  run "tar -xzf \"\$BACKUP_DIR/auto-memory/memory.tar.gz\" -C \"\$MEM_PARENT\""
fi

# Step 6 — repo tree (MOST INVASIVE, confirm)
echo
echo "Step 6 — restore repo tree at \$PROJECT"
echo "  This RESETS \$PROJECT to the backup snapshot."
echo "  Branch at backup time: \$(cat "\$BACKUP_DIR/repo/branch.txt" 2>/dev/null || echo unknown)"
echo "  Dirty files at backup time: \$(wc -l < "\$BACKUP_DIR/repo/git-status.txt" 2>/dev/null | tr -d ' ')"
echo "  Current tree will be moved aside (NOT deleted)."
if ask "  confirm repo restore?"; then
  PARENT=\$(dirname "\$PROJECT")
  BASENAME=\$(basename "\$PROJECT")
  if [ -d "\$PROJECT" ]; then
    SIDESTEP="\$PARENT/\$BASENAME.before-restore-\$(date +%Y%m%d-%H%M%S)"
    run "mv \"\$PROJECT\" \"\$SIDESTEP\""
    echo "  Old tree at: \$SIDESTEP (rm after verifying restore)"
  fi
  run "tar -xzf \"\$BACKUP_DIR/repo/rapidclaw.tar.gz\" -C \"\$PARENT\""
else
  echo "  SKIPPED repo restore"
fi

# Step 7 — re-bootstrap launchd jobs
echo
echo "Step 7 — bootstrap launchd jobs"
for plist in "\$HOME/Library/LaunchAgents/com.agni.\${SLUG}-"*.plist; do
  [ -f "\$plist" ] || continue
  run "launchctl bootstrap gui/\$(id -u) \"\$plist\""
done

echo
echo "================================================================="
echo "  RESTORE COMPLETE (mode: \$MODE)"
if [ "\$MODE" = "dry" ]; then
  echo "  Nothing was changed. Run with --confirm to actually restore."
fi
echo "================================================================="
RESTORE_EOF
chmod +x "$BACKUP_ROOT/restore.sh"

# Summary
echo
echo "=== BACKUP COMPLETE ==="
echo "Location: $BACKUP_ROOT"
echo "Total size: $(du -sh "$BACKUP_ROOT" | cut -f1)"
echo
echo "Verify:"
echo "  cat $BACKUP_ROOT/MANIFEST.md"
echo "  $BACKUP_ROOT/restore.sh --dry-run"
echo
echo "Restore (when needed):"
echo "  $BACKUP_ROOT/restore.sh --confirm"
