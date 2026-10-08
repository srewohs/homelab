#!/usr/bin/env bash
# Pre-commit hook: fail if any file being committed, or the commit's author or
# committer identity, contains a string from the private denylists. The
# denylists live in the private inventory repo, so the identifying strings
# themselves never appear here.
#
#   <private>/denylist/literal.txt   fixed strings (grep -F)
#   <private>/denylist/regex.txt     extended regexes (grep -E)
#
# <private> is $HOMELAB_PRIVATE, else `git config homelab.private`, else
# ../homelab-private next to this repo. The git config fallback covers shells
# that don't load .envrc:
#
#   git config homelab.private ~/homelab-private
#
# Blank lines and lines starting with # are ignored. If either file is
# missing, the hook fails rather than silently passing.
#
# Requires GNU grep: \b in regex.txt is a GNU extension.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
private="${HOMELAB_PRIVATE:-$(git config --type=path --get homelab.private || echo "$root/../homelab-private")}"
literal="$private/denylist/literal.txt"
regex="$private/denylist/regex.txt"

for f in "$literal" "$regex"; do
  if [[ ! -f $f ]]; then
    echo "check-private-strings: $f not found." >&2
    echo "Set HOMELAB_PRIVATE or git config homelab.private to the private repo." >&2
    exit 1
  fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# A blank pattern would match every line, so strip blanks and comments.
grep -vE '^[[:space:]]*(#|$)' "$literal" > "$tmp/literal" || true
grep -vE '^[[:space:]]*(#|$)' "$regex" > "$tmp/regex" || true

# "Name <email> timestamp tz" -> "Name <email>"
for who in AUTHOR COMMITTER; do
  printf 'GIT_%s_IDENT: %s\n' "$who" "$(git var "GIT_${who}_IDENT" | sed -E 's/ [0-9]+ [+-][0-9]{4}$//')"
done > "$tmp/ident"

status=0
if { [[ -s $tmp/literal ]] && grep -qF -f "$tmp/literal" "$tmp/ident"; } ||
   { [[ -s $tmp/regex ]] && grep -qE -f "$tmp/regex" "$tmp/ident"; }; then
  echo "check-private-strings: the commit identity matches the private denylist." >&2
  echo "Check git config user.name and user.email for this repo." >&2
  status=1
fi

[[ $# -gt 0 ]] || exit $status

if [[ -s $tmp/literal ]] && grep -HnIF -f "$tmp/literal" -- "$@" | cut -d: -f1,2 > "$tmp/hits"; then
  sed 's/$/  (literal.txt)/' "$tmp/hits"
  status=1
fi
if [[ -s $tmp/regex ]] && grep -HnIE -f "$tmp/regex" -- "$@" | cut -d: -f1,2 > "$tmp/hits"; then
  sed 's/$/  (regex.txt)/' "$tmp/hits"
  status=1
fi
if [[ $status -ne 0 ]]; then
  echo "check-private-strings: the lines above match the private denylist." >&2
fi
exit $status
