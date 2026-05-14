#!/bin/zsh
# x-intent.sh — build a Twitter/X intent URL that opens the X composer prefilled.
# The user clicks → reviews → posts in their real X session. No automated
# composer dance, no API write scopes needed.
#
# Usage:
#   x-intent.sh reply <tweet_id> "<text>"
#   x-intent.sh tweet "<text>"
#   x-intent.sh quote <original_url> "<text>"
#   x-intent.sh rt    <tweet_id>
#   x-intent.sh like  <tweet_id>

set -e

ACTION="${1:?usage: x-intent.sh <reply|tweet|quote|rt|like> [args]}"
shift

enc() { /usr/bin/python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$1"; }

case "$ACTION" in
  reply)
    TWEET_ID="${1:?tweet_id required}"
    TEXT="$(enc "${2:?text required}")"
    echo "https://twitter.com/intent/tweet?in_reply_to=${TWEET_ID}&text=${TEXT}"
    ;;
  tweet)
    TEXT="$(enc "${1:?text required}")"
    echo "https://twitter.com/intent/tweet?text=${TEXT}"
    ;;
  quote)
    ORIG_URL="$(enc "${1:?original tweet URL required}")"
    TEXT="$(enc "${2:?text required}")"
    echo "https://twitter.com/intent/tweet?text=${TEXT}&url=${ORIG_URL}"
    ;;
  rt|retweet)
    TWEET_ID="${1:?tweet_id required}"
    echo "https://twitter.com/intent/retweet?tweet_id=${TWEET_ID}"
    ;;
  like)
    TWEET_ID="${1:?tweet_id required}"
    echo "https://twitter.com/intent/like?tweet_id=${TWEET_ID}"
    ;;
  *)
    echo "ERROR: unknown action '$ACTION' (use reply|tweet|quote|rt|like)" >&2
    exit 1
    ;;
esac
