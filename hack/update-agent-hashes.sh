#!/usr/bin/env bash
set -euo pipefail

NEW_SHA="${1:-}"
[[ $# -eq 1 && "$NEW_SHA" =~ ^[a-f0-9]{40}$ ]] || { echo "usage: $0 <40-char-sha>" >&2; exit 1; }

CONFIG="config.yaml"
CONFIG_DIR=$(dirname "$CONFIG")
TMPFILE=$(mktemp -p "$CONFIG_DIR" "$(basename "$CONFIG").tmp.XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT

cp "$CONFIG" "$TMPFILE"

sed -i -E "s|/agents/[a-f0-9]{40}/|/agents/${NEW_SHA}/|g" "$TMPFILE"

grep -o 'harness/[^#]*\.yaml' "$TMPFILE" | while read -r path; do
    url="https://raw.githubusercontent.com/fullsend-ai/agents/${NEW_SHA}/${path}"
    if ! hash=$(curl -sfL "$url" | sha256sum | awk '{print $1}'); then
        echo "fetch failed: $url" >&2
        exit 1
    fi
    esc_path=$(printf '%s' "$path" | sed 's/[.[\*^$/]/\\&/g')
    sed -i "s|${esc_path}#sha256=[a-f0-9]\{64\}|${path}#sha256=${hash}|g" "$TMPFILE"
done

mv -f "$TMPFILE" "$CONFIG"
trap - EXIT
