#!/usr/bin/env bash
# Build the installer and validator from github.fullsend_ref in repos.yaml.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
destination=${1:?usage: build-fullsend.sh OUTPUT_DIRECTORY}
fullsend_ref=$(ruby -ryaml -e '
manifest = YAML.safe_load_file(ARGV.fetch(0), aliases: true)
github = manifest.is_a?(Hash) ? manifest["github"] : nil
ref = github.is_a?(Hash) ? github["fullsend_ref"] : nil
unless ref.is_a?(String) && !ref.empty? && ref != "none"
  abort "repos.yaml must set github.fullsend_ref to a Fullsend ref"
end
unless /\A[a-zA-Z0-9._-]+\z/.match?(ref)
  abort "github.fullsend_ref contains invalid characters: #{ref.inspect}"
end
puts ref
' "$root/repos.yaml")
if ! git check-ref-format --branch "$fullsend_ref" >/dev/null 2>&1; then
  echo "github.fullsend_ref is not a valid Git ref: $fullsend_ref" >&2
  exit 1
fi
mkdir -p "$destination"
destination=$(cd "$destination" && pwd)
source_dir=$(mktemp -d)
trap 'rm -rf "$source_dir"' EXIT
git -C "$source_dir" init --quiet
git -C "$source_dir" fetch --quiet --depth 1 https://github.com/fullsend-ai/fullsend.git "$fullsend_ref"
revision=$(git -C "$source_dir" rev-parse --verify 'FETCH_HEAD^{commit}')
git -C "$source_dir" checkout --quiet --detach "$revision"
printf '%s\n' "$fullsend_ref" > "$destination/fullsend-source-ref"
printf '%s\n' "$revision" > "$destination/fullsend-source-revision"
cp -R "$root/hack/manifest-validator" "$source_dir/cmd/fleet-manifest-validate"
(
  cd "$source_dir"
  go test ./cmd/fleet-manifest-validate
  go build -o "$destination/fullsend" ./cmd/fullsend
  go build -o "$destination/validate-manifest" ./cmd/fleet-manifest-validate
)
echo "Built installer and validator from $revision (github.fullsend_ref=$fullsend_ref)"
