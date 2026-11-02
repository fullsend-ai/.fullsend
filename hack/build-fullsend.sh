#!/usr/bin/env bash
# Build the installer and validator from the same reviewed Fullsend revision.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
destination=${1:?usage: build-fullsend.sh OUTPUT_DIRECTORY}
revision=$(cat "$root/fullsend-cli-revision")
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'fullsend-cli-revision must contain one complete commit SHA' >&2
  exit 1
fi
mkdir -p "$destination"
destination=$(cd "$destination" && pwd)
source_dir=$(mktemp -d)
trap 'rm -rf "$source_dir"' EXIT
git -C "$source_dir" init --quiet
git -C "$source_dir" fetch --quiet --depth 1 https://github.com/fullsend-ai/fullsend.git "$revision"
git -C "$source_dir" checkout --quiet --detach FETCH_HEAD
cp -R "$root/hack/manifest-validator" "$source_dir/cmd/fleet-manifest-validate"
(
  cd "$source_dir"
  go test ./cmd/fleet-manifest-validate
  go build -o "$destination/fullsend" ./cmd/fullsend
  go build -o "$destination/validate-manifest" ./cmd/fleet-manifest-validate
)
echo "Built installer and validator from $revision"
