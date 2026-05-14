#!/bin/zsh
# gen-image.sh — generate an image via OpenRouter, save to a local path.
# Reads OPENROUTER_API_KEY from the bot's .env.
#
# Usage:
#   gen-image.sh "<prompt>" [output_path] [model]
#   REF_IMAGE=path/to/photo.png gen-image.sh "<prompt>" [output_path] [model]
#   REF_IMAGE="path1.png:path2.png" gen-image.sh ...   (colon-separated for multiple refs)
#
# Defaults:
#   output_path: /tmp/gen-image-<timestamp>.png
#   model:       google/gemini-2.5-flash-image   (cheap, fast)
#
# Output: "OK saved to <path> (<bytes> bytes)"

set -e
source "${0:A:h}/_lib.sh"

PROMPT="${1:?prompt required as first arg (quote it)}"
OUTPUT="${2:-/tmp/gen-image-$(date +%Y%m%d-%H%M%S).png}"
MODEL="${3:-google/gemini-2.5-flash-image}"

[ -n "${OPENROUTER_API_KEY:-}" ] || { echo "ERROR: OPENROUTER_API_KEY not set in .env" >&2; exit 1; }

REF_IMAGE_LIST="${REF_IMAGE:-}"
PAYLOAD_FILE="$(mktemp -t gen-image-payload.XXXXXX.json)"
RESPONSE_FILE="$(mktemp -t gen-image-response.XXXXXX.json)"
trap 'rm -f "$PAYLOAD_FILE" "$RESPONSE_FILE"' EXIT

/usr/bin/python3 -c '
import json, sys, os, base64, mimetypes

model, prompt, refs, out_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

content = [{"type": "text", "text": prompt}]
if refs:
    for p in refs.split(":"):
        p = p.strip()
        if not p: continue
        if not os.path.isfile(p):
            print(f"ERROR: ref image not found: {p}", file=sys.stderr); sys.exit(1)
        mime = mimetypes.guess_type(p)[0] or "image/png"
        with open(p, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        content.append({"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}})

payload = {
  "model": model,
  "modalities": ["image", "text"],
  "messages": [{"role": "user", "content": content if len(content) > 1 else prompt}]
}
with open(out_path, "w") as f:
    json.dump(payload, f)
' "$MODEL" "$PROMPT" "$REF_IMAGE_LIST" "$PAYLOAD_FILE"

curl -fsS -X POST \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -H "HTTP-Referer: https://github.com/rapidclaw" \
  -H "X-Title: rapidclaw" \
  --data-binary "@$PAYLOAD_FILE" \
  -o "$RESPONSE_FILE" \
  https://openrouter.ai/api/v1/chat/completions

OUTPUT_PATH="$OUTPUT" RESPONSE_FILE="$RESPONSE_FILE" /usr/bin/python3 - <<'PY'
import json, sys, base64, os, urllib.request

output_path = os.environ["OUTPUT_PATH"]
response_file = os.environ["RESPONSE_FILE"]

try:
    with open(response_file) as f:
        data = json.loads(f.read(), strict=False)
except Exception as e:
    print(f"ERROR: response not JSON: {e}", file=sys.stderr)
    with open(response_file) as f: print(f.read()[:1000], file=sys.stderr)
    sys.exit(1)

if "error" in data:
    print(f"ERROR from API: {json.dumps(data['error'], indent=2)}", file=sys.stderr); sys.exit(1)

img_bytes = None
try: msg = data["choices"][0]["message"]
except (KeyError, IndexError):
    print("ERROR: no choices in response", file=sys.stderr)
    print(json.dumps(data, indent=2)[:2000], file=sys.stderr); sys.exit(1)

# Shape A: message.images = [{"image_url": {"url": "data:image/png;base64,..."}}]
if not img_bytes and isinstance(msg.get("images"), list) and msg["images"]:
    for it in msg["images"]:
        url = (it.get("image_url") or {}).get("url") or it.get("url", "")
        if url.startswith("data:image"):
            img_bytes = base64.b64decode(url.split(",", 1)[1]); break
        if url.startswith("http"):
            with urllib.request.urlopen(url) as r: img_bytes = r.read(); break

# Shape B: content is array with image_url items
if not img_bytes and isinstance(msg.get("content"), list):
    for item in msg["content"]:
        if item.get("type") in ("image_url", "image"):
            url = (item.get("image_url") or {}).get("url") or item.get("url", "")
            if url.startswith("data:image"):
                img_bytes = base64.b64decode(url.split(",", 1)[1]); break
            if url.startswith("http"):
                with urllib.request.urlopen(url) as r: img_bytes = r.read(); break

if not img_bytes:
    print("ERROR: no image in response. Full response (truncated):", file=sys.stderr)
    print(json.dumps(data, indent=2)[:3000], file=sys.stderr); sys.exit(1)

with open(output_path, "wb") as f: f.write(img_bytes)
print(f"OK saved to {output_path} ({len(img_bytes)} bytes)")
PY
