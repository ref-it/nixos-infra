#!/usr/bin/env bash
# Updates the OCI image pins in oci-images/<name>.json.
#
# Usage:
#   ./update-oci-images.sh              update all images to their newest tag
#   ./update-oci-images.sh <name>       update only oci-images/<name>.json
#   ./update-oci-images.sh <name> <tag> pin <name> to exactly <tag>
#
# "Newest tag" is the highest version (sort -V) among the registry's tags
# matching the pin's tagPattern (extended regex).
#
# New image: create oci-images/<name>.json with imageName, finalImageName,
# finalImageTag (any existing tag) and tagPattern, then run
# ./update-oci-images.sh <name> <tag> to fill in digest and hash.
#
# Afterwards: review the diff, build and deploy the affected hosts.
set -euo pipefail

cd "$(dirname "$0")"
DIR=oci-images

for cmd in jq skopeo nix-prefetch-docker; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd', run this inside 'nix develop'." >&2; exit 1; }
done

update() {
  local name=$1 tag=${2:-} file="$DIR/$1.json"
  [[ -f $file ]] || { echo "$name: no $file" >&2; return 1; }

  local image current pattern os arch
  image=$(jq -r .imageName "$file")
  current=$(jq -r .finalImageTag "$file")
  pattern=$(jq -r '.tagPattern // empty' "$file")
  os=$(jq -r '.os // "linux"' "$file")
  arch=$(jq -r '.arch // "amd64"' "$file")

  if [[ -z $tag ]]; then
    [[ -n $pattern ]] || { echo "$name: no tagPattern, pass a tag explicitly" >&2; return 1; }
    tag=$(skopeo list-tags "docker://$image" | jq -r '.Tags[]' | grep -E "$pattern" | sort -V | tail -1 || true)
    [[ -n $tag ]] || { echo "$name: no tag matching $pattern" >&2; return 1; }
  fi

  if [[ $tag == "$current" ]]; then
    echo "$name: already at $image:$current"
    return 0
  fi

  echo "$name: $image $current -> $tag"
  local pin
  pin=$(nix-prefetch-docker --quiet --json --image-name "$image" --image-tag "$tag" --os "$os" --arch "$arch")

  # Keep script-only keys (tagPattern, ...) and key order; write atomically so a
  # failed run never leaves a broken pin behind.
  jq --argjson new "$pin" '. * $new' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

if [[ $# -ge 1 ]]; then
  update "$1" "${2:-}"
else
  failed=0
  for file in "$DIR"/*.json; do
    update "$(basename "$file" .json)" || failed=1
  done
  exit $failed
fi
