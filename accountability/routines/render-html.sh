#!/bin/zsh
# render-html.sh — open an HTML file in browser-use, screenshot, return PNG path.
# For architectural diagrams, charts, code snippets, before/after — anything
# composable in HTML/CSS where vector output beats AI image gen.
#
# Usage:
#   render-html.sh <html_file_path> [output_png_path]
#   echo "<html>...</html>" | render-html.sh --stdin [output_png_path]

set -e
source "${0:A:h}/_lib.sh"

BU="$(command -v browser-use || echo "$HOME/.browser-use-env/bin/browser-use")"
[ -x "$BU" ] || { echo "ERROR: browser-use not found. Install: pip install browser-use" >&2; exit 1; }

if [ "${1:-}" = "--stdin" ]; then
  OUTPUT="${2:-/tmp/render-html-$(date +%Y%m%d-%H%M%S).png}"
  HTML_FILE="/tmp/render-html-$(date +%Y%m%d-%H%M%S).html"
  cat > "$HTML_FILE"
else
  HTML_FILE="${1:?html file path required (or --stdin)}"
  OUTPUT="${2:-/tmp/render-html-$(date +%Y%m%d-%H%M%S).png}"
fi

[[ "$HTML_FILE" != /* ]] && HTML_FILE="$PWD/$HTML_FILE"
[ -f "$HTML_FILE" ] || { echo "ERROR: file not found: $HTML_FILE" >&2; exit 1; }

URL="file://$HTML_FILE"
"$BU" tab new "$URL" >/dev/null
sleep 1
"$BU" screenshot "$OUTPUT" >/dev/null
"$BU" tab close >/dev/null 2>&1 || true

echo "OK $OUTPUT"
