#!/usr/bin/env bash
# Copyright (c) 2026 Md. Mehedi Hasan
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail
shopt -s nullglob

echo "- Resolving repository"
REPOSITORY="$(git -C "$SRC_DIR" config --get remote.origin.url |
  sed -nE 's#^(https://github\.com/|git@github\.com:)([^/]+)/.*#\2#p')/static_resources"
BRANCH=sixteen
BUILD_TYPE="-${BUILD_TYPE}"
RELEASE_WORK_DIR="$(mktemp -d)"
CHUNK_SIZE=1610612736
RELEASE_CHUNKS_DIR="$RELEASE_WORK_DIR/chunks"
mkdir -p "$RELEASE_CHUNKS_DIR"; trap 'rm -rf "$RELEASE_WORK_DIR"' EXIT

TARGET_FILES=("$OUT_DIR"/*target*.zip)
TARGET_FILE="${TARGET_FILES[0]}"; TARGET_NAME="${TARGET_FILE##*/}"

ROM_FILES=("$OUT_DIR"/UN1CA*.zip)
ROM_FILE="${ROM_FILES[0]}"; ROM_FILENAME="${ROM_FILE##*/}"
echo "- Releasing: $ROM_FILENAME"

UPLOAD_PATHS=()
echo "- Preparing target"
if [ "$(wc -c < "$TARGET_FILE")" -gt "$CHUNK_SIZE" ]; then
  split -b "$CHUNK_SIZE" -d -a 2 "$TARGET_FILE" "$RELEASE_CHUNKS_DIR/$TARGET_NAME."
  UPLOAD_PATHS+=("$RELEASE_CHUNKS_DIR/$TARGET_NAME".*)
else
  UPLOAD_PATHS+=("$TARGET_FILE")
fi

echo "- Preparing ROM"
if [ "$(wc -c < "$ROM_FILE")" -gt "$CHUNK_SIZE" ]; then
  split -b "$CHUNK_SIZE" -d -a 2 "$ROM_FILE" "$RELEASE_CHUNKS_DIR/$ROM_FILENAME."
  ROM_SPLIT=true
  UPLOAD_PATHS+=("$RELEASE_CHUNKS_DIR/$ROM_FILENAME".*)
else
  ROM_SPLIT=false
  UPLOAD_PATHS+=("$ROM_FILE")
fi

echo "- Generating OTA manifest"
mv "$TARGET_FILE" "$SRC_DIR/"
"$SRC_DIR/scripts/generate_ota_manifest.sh" "$OUT_DIR"
MANIFEST="$SRC_DIR/manifest.json"
mv "$SRC_DIR/$TARGET_NAME" "$OUT_DIR/"

CHUNK_URLS=()
if [ "$ROM_SPLIT" = true ]; then
  for CHUNK in "$RELEASE_CHUNKS_DIR/$ROM_FILENAME".*; do
    CHUNK_URLS+=("https://github.com/$REPOSITORY/releases/download/$ROM_VERSION/${CHUNK##*/}")
  done
else
  CHUNK_URLS+=("https://github.com/$REPOSITORY/releases/download/$ROM_VERSION/$ROM_FILENAME")
fi

echo "- Injecting chunk URLs into manifest"
python3 - "$MANIFEST" "${CHUNK_URLS[@]}" <<'PY'
import sys
p,*u=sys.argv[1:];s=open(p,encoding="utf-8").read()
open(p,"w",encoding="utf-8").write(s.replace('["INSERTURLHERE"]',"["+",".join(f'"{x}"' for x in u)+"]",1))
PY

echo "- Creating release $ROM_VERSION"
gh release view "$ROM_VERSION" --repo "$REPOSITORY" >/dev/null 2>&1 ||
  gh release create "$ROM_VERSION" --repo "$REPOSITORY" --title "$ROM_VERSION" --notes "UN1CA $ROM_VERSION"

echo "- Uploading to release"
gh release upload "$ROM_VERSION" --repo "$REPOSITORY" --clobber "${UPLOAD_PATHS[@]}"

MANIFEST_NAME="manifest${BUILD_TYPE}.json"
MANIFEST_PATH="updates/$MANIFEST_NAME"
COMMIT_MESSAGE="updates: ${ROM_VERSION}${BUILD_TYPE}"
CURRENT_MANIFEST="$RELEASE_WORK_DIR/current_manifest.json"
UPDATED_MANIFEST="$RELEASE_WORK_DIR/updated_manifest.json"

echo "- Fetching current $MANIFEST_NAME"
gh api "repos/$REPOSITORY/contents/$MANIFEST_PATH?ref=$BRANCH" --jq .content 2>/dev/null |
  tr -d '\n' | base64 -d > "$CURRENT_MANIFEST" || true
[ -s "$CURRENT_MANIFEST" ] || echo '{"response":[]}' > "$CURRENT_MANIFEST"

echo "- Merging new entry into $MANIFEST_NAME"
python3 - "$CURRENT_MANIFEST" "$MANIFEST" "$UPDATED_MANIFEST" <<'PY'
import json,re,sys
c,n,o=sys.argv[1:];s=open(c,encoding="utf-8").read()
try: j=json.loads(s)
except json.JSONDecodeError: j=json.loads(re.sub(r",(\s*[}\]])",r"\1",s))
e=json.load(open(n,encoding="utf-8"))["response"][0]
j["response"]=[x for x in j.get("response",[]) if x.get("filename")!=e["filename"]]+[e]
with open(o,"w",encoding="utf-8") as f: json.dump(j,f,indent=2,ensure_ascii=False); f.write("\n")
PY

echo "- Committing manifest and changelog"
GRAPHQL_QUERY="$(printf 'mutation(%si:CreateCommitOnBranchInput!){createCommitOnBranch(input:%si){commit{oid}}}' '$' '$')"
HEAD_SHA="$(gh api "repos/$REPOSITORY/git/ref/heads/$BRANCH" --jq .object.sha)"
CHANGELOG_B64="$(printf '%b\n' "$CHANGELOG_TEXT" | base64 -w0)"
MANIFEST_B64="$(base64 -w0 "$UPDATED_MANIFEST")"

REQUEST_BODY="$(jq -nc \
  --arg query "$GRAPHQL_QUERY" \
  --arg repo "$REPOSITORY" --arg branch "$BRANCH" --arg head "$HEAD_SHA" \
  --arg p1 "$MANIFEST_PATH" --arg c1 "$MANIFEST_B64" \
  --arg p2 "updates/$ROM_VERSION.txt" --arg c2 "$CHANGELOG_B64" \
  --arg msg "$COMMIT_MESSAGE" \
  '{query:$query,variables:{i:{
    branch:{repositoryNameWithOwner:$repo,branchName:$branch},
    message:{headline:$msg},
    fileChanges:{additions:[{path:$p1,contents:$c1},{path:$p2,contents:$c2}]},
    expectedHeadOid:$head
  }}}')"
echo "$REQUEST_BODY" | gh api graphql --input -
echo "- Commit done"

echo "===== Final $MANIFEST_NAME ====="; cat "$UPDATED_MANIFEST"; echo "===================="