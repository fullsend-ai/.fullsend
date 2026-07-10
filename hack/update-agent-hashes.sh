#!/usr/bin/env bash
set -euo pipefail

NEW_SHA="$1"
CONFIG="config.yaml"

# Update commit SHAs in URLs first
sed -i -E "s|/agents/[a-f0-9]{40}/|/agents/${NEW_SHA}/|g" "$CONFIG"

# Recompute content hashes
grep -oP 'harness/[^#]+\.yaml' "$CONFIG" | while read -r path; do
    url="https://raw.githubusercontent.com/fullsend-ai/agents/${NEW_SHA}/${path}"
    hash=$(curl -sfL "$url" | sha256sum | awk '{print $1}')
    if [ -n "$hash" ]; then
        sed -i "s|${path}#sha256=[a-f0-9]\{64\}|${path}#sha256=${hash}|" "$CONFIG"
    fi
done
