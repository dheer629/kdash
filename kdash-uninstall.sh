#!/usr/bin/env bash
# Standalone uninstaller for kdash. Author: Dheeraj V. License: MIT.
# Keep the KDASH_UNINSTALL_EOF payload in kdash-bundle.sh identical to this file.
set -uo pipefail
PATH="${PATH:+$PATH:}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; export PATH

say() { printf '%s\n' "$*"; }
die() { printf 'kdash-uninstall: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: bash kdash-uninstall.sh [--prefix DIR] [--no-shell] [--dry-run]

Remove kdash, its completion file and the current user's shell integration.
The script works on its own; no installer, kubectl or cluster connection is needed.

  --prefix DIR  Binary directory (default: ~/.local/bin; root: /usr/local/bin).
                Use the same prefix that was passed to the installer.
  --no-shell    Keep shell integration and startup blocks; remove binary/completion.
  --dry-run     Show the planned changes without changing any files.
  -h, --help    Show this help.

Edits only complete kdash setup blocks in ~/.bashrc and ~/.bash_profile, with
backups. Shell integration for a different prefix is kept, including completion.
Root removes /etc/bash_completion.d/kdash and uses root's current HOME; other
users' homes are not scanned. Open a new terminal after uninstalling.

Configuration, disclaimer acceptance, reports, sessions, audit logs, startup
backups and ~/.kdash-old are kept. Running dashboards are not stopped.
HELP
}

PREFIX=""; DO_SHELL=1; DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ -n "${2:-}" ] && [[ "$2" != --* ]] || die '--prefix needs a directory'
      PREFIX="$2"; shift 2 ;;
    --no-shell) DO_SHELL=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option '$1' (try --help)" ;;
  esac
done
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die 'HOME must name an existing directory'
if [ "$(id -u)" -eq 0 ]; then
  PREFIX="${PREFIX:-/usr/local/bin}"; COMPFILE=/etc/bash_completion.d/kdash
else
  PREFIX="${PREFIX:-$HOME/.local/bin}"; COMPFILE="$HOME/.kdash-completion.bash"
fi
# Resolve directory aliases, but never follow the final kdash symlink for removal.
PREFIX="$(readlink -m -- "$PREFIX")" || die 'cannot resolve the install prefix'
BIN="$PREFIX/kdash"; SHELLFILE="$HOME/.kdash-shell.bash"
REMOVE=("$COMPFILE"); EDIT=(); STAGED=(); BACKUPS=()
KEEP_INTEGRATION=0
BEGIN_MARK='# >>> kdash setup >>>'; END_MARK='# <<< kdash setup <<<'

if [ -e "$SHELLFILE" ] || [ -L "$SHELLFILE" ]; then
  [ -f "$SHELLFILE" ] && [ -r "$SHELLFILE" ] || die "cannot read regular shell integration file $SHELLFILE"
  # Read the installer's literal assignment, never execute a shell/config file.
  bound="$(sed -n 's/^KDASH_BIN="\(.*\)"$/\1/p' "$SHELLFILE")"
  if [ -n "$bound" ] && [ "$(readlink -m -- "$bound")" != "$(readlink -m -- "$BIN")" ]; then
    KEEP_INTEGRATION=1; REMOVE=()
    say "kept shell integration and completion for another install: $bound"
  fi
fi
if [ "$DO_SHELL" = 1 ] && [ "$KEEP_INTEGRATION" = 0 ]; then
  REMOVE+=("$SHELLFILE")
  for startup in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -e "$startup" ] || [ -L "$startup" ] || continue
    [ -f "$startup" ] && [ -r "$startup" ] || die "cannot read regular startup file $startup"
    target="$(readlink -f -- "$startup")" || die "cannot resolve $startup"
    # Validate all pairs first; an unmatched start must never delete the file tail.
    count="$(awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
      $0 == begin { if (inside) bad=1; inside=1; count++; next }
      $0 == end { if (!inside) bad=1; inside=0 }
      END { if (inside || bad) exit 1; print count+0 }
    ' "$target")" || die "malformed kdash setup markers in $startup; nothing removed"
    [ "$count" -gt 0 ] || continue
    duplicate=0
    for existing in "${EDIT[@]}"; do [ "$existing" != "$target" ] || duplicate=1; done
    [ "$duplicate" = 0 ] || continue
    [ -w "$target" ] && [ -w "$(dirname -- "$target")" ] || die "cannot edit/back up $startup; nothing removed"
    EDIT+=("$target")
  done
fi
# kdx / kdsh shortcuts, only when they are ours
for shortcut in "$PREFIX/kdx" "$PREFIX/kdsh"; do
  [ -f "$shortcut" ] && grep -qF '# kdash-shortcut: written by kdash-bundle.sh' "$shortcut" 2>/dev/null && REMOVE+=("$shortcut")
done
# Unlink only named installation files, with the binary last. Never recurse.
REMOVE+=("$BIN")
for target in "${REMOVE[@]}"; do
  [ -e "$target" ] || [ -L "$target" ] || continue
  [ -L "$target" ] || [ -f "$target" ] || die "refusing to remove non-file $target; nothing removed"
  [ -w "$(dirname -- "$target")" ] || die "cannot remove $target; nothing removed"
done

if [ "$DRY_RUN" = 1 ]; then
  for target in "${EDIT[@]}"; do say "would back up and remove kdash setup blocks from $target"; done
  for target in "${REMOVE[@]}"; do
    if [ -e "$target" ] || [ -L "$target" ]; then say "would remove $target"; fi
  done
  say 'Dry run complete; no files changed.'
  exit 0
fi

cleanup() {
  local staged
  for staged in "${STAGED[@]}"; do rm -f -- "$staged"; done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
STAMP="$(date +%Y%m%d_%H%M%S)"
# Prepare every edit and backup before changing any installation file.
for target in "${EDIT[@]}"; do
  staged="$(mktemp "$(dirname -- "$target")/.kdash-uninstall.XXXXXX")" || die "cannot stage $target"
  STAGED+=("$staged")
  cp -p -- "$target" "$staged" || die "cannot preserve permissions for $target"
  sed "/^$BEGIN_MARK\$/,/^$END_MARK\$/d" "$target" > "$staged" || die "cannot prepare $target"
  backup="$(mktemp "$target.bak.kdash.$STAMP.XXXXXX")" || die "cannot create backup for $target"
  cp -p -- "$target" "$backup" || die "cannot back up $target"
  BACKUPS+=("$backup")
done
for ((i=0; i<${#EDIT[@]}; i++)); do
  # EDIT holds the symlink target, preserving a symlinked startup file itself.
  mv -f -- "${STAGED[i]}" "${EDIT[i]}" || die "cannot update ${EDIT[i]} (backup: ${BACKUPS[i]})"
  say "removed kdash setup blocks from ${EDIT[i]} (backup: ${BACKUPS[i]})"
done
for target in "${REMOVE[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f -- "$target" || die "cannot remove $target"
    say "removed $target"
  fi
done
say 'Uninstall complete. Configuration, reports, sessions, audit logs and old-version backups were kept.'
say 'Open a new terminal to discard loaded kdash functions and command caches. Running dashboards continue until you quit them.'
