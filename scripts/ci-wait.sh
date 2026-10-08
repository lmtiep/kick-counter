#!/usr/bin/env bash
# Waits for the CI run of HEAD, prints failed logs, downloads artifacts to ci-artifacts/.
set -euo pipefail
cd "$(dirname "$0")/.."
SHA="$(git rev-parse HEAD)"
RUN_ID=""
for _ in $(seq 1 30); do
  RUN_ID="$(gh run list --workflow ci.yml --commit "$SHA" --limit 1 --json databaseId -q '.[0].databaseId')"
  [[ -n "$RUN_ID" ]] && break
  sleep 5
done
[[ -n "$RUN_ID" ]] || { echo "No CI run found for $SHA — was it pushed?" >&2; exit 1; }

STATUS=0
gh run watch "$RUN_ID" --exit-status --interval 20 > /dev/null || STATUS=$?
rm -rf ci-artifacts && mkdir -p ci-artifacts
gh run download "$RUN_ID" --dir ci-artifacts 2>/dev/null || true
# The shards upload screenshots-1, screenshots-2, …: gather them in ci-artifacts/screenshots.
mkdir -p ci-artifacts/screenshots
for dir in ci-artifacts/screenshots-*; do
  [[ -d "$dir" ]] || continue
  cp -R "$dir"/. ci-artifacts/screenshots/
  rm -rf "$dir"
done
if [[ $STATUS -ne 0 ]]; then
  gh run view "$RUN_ID" --log-failed | tail -150
  echo "CI FAILED: $(gh run view "$RUN_ID" --json url -q .url)" >&2
else
  echo "CI PASSED: $(gh run view "$RUN_ID" --json url -q .url)"
fi
exit $STATUS
