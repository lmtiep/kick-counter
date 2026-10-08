#!/usr/bin/env bash
# Full quality gate. Runs on GitHub Actions (requires Xcode + XcodeGen).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Which UI tests this job runs (decided before anything slow, so idle shards exit at once):
# - push to main (a merged pull request, already fully tested): no UI tests, build only;
# - branch push with a "CI-Only-Testing: ClassA, ClassB" HEAD trailer: those classes, on shard 1;
# - otherwise (pull requests, manual runs, branch pushes without a trailer): the full suite,
#   split across CI_SHARD_TOTAL parallel jobs (this is job CI_SHARD_INDEX, 1-based).
# Class names must match [A-Za-z0-9_]+ (no shell injection from commit messages); a trailer with
# an invalid name is ignored (full suite). Names may be separated by commas and/or spaces.
# GITHUB_EVENT_NAME / GITHUB_REF are default GitHub Actions variables; run locally (unset), this
# counts as a branch push.
SHARD_INDEX="${CI_SHARD_INDEX:-1}"
SHARD_TOTAL="${CI_SHARD_TOTAL:-1}"
UI_TEST_TARGET="KickCounterUITests"
MODE="full"
CLASSES=()
TRAILER="$(git log -1 --format=%B | sed -n 's/^CI-Only-Testing:[[:space:]]*//p' | head -1)"
if [[ "${GITHUB_EVENT_NAME:-push}" == "push" && "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
  MODE="main"
  echo "==> Push to main: build only, no UI tests (the pull request ran the full suite)"
elif [[ -n "$TRAILER" && "${GITHUB_EVENT_NAME:-push}" != "push" ]]; then
  echo "==> CI-Only-Testing trailer ignored: event is ${GITHUB_EVENT_NAME}"
elif [[ -n "$TRAILER" ]]; then
  VALID=1
  for raw in $(printf '%s' "$TRAILER" | tr ',' ' '); do
    if [[ "$raw" =~ ^[A-Za-z0-9_]+$ ]]; then
      CLASSES+=("$raw")
    else
      VALID=0
    fi
  done
  if [[ $VALID -eq 1 && ${#CLASSES[@]} -gt 0 ]]; then
    MODE="scoped"
    echo "==> UI tests: scoped to ${CLASSES[*]} (CI-Only-Testing trailer)"
  else
    CLASSES=()
    echo "==> UI tests: full suite (CI-Only-Testing trailer ignored: invalid class name)"
  fi
fi
if [[ "$MODE" != "full" && "$SHARD_INDEX" -gt 1 ]]; then
  echo "==> Shard $SHARD_INDEX/$SHARD_TOTAL: nothing to do in $MODE mode"
  exit 0
fi
if [[ "$MODE" == "full" && "$SHARD_TOTAL" -gt 1 ]]; then
  # Screenshot classes are the slowest, so they are dealt out first; every class lands
  # on exactly one shard (round robin over a stable order).
  ALL_CLASSES="$(grep -ho 'class [A-Za-z0-9_]*: XCTestCase' UITests/*.swift | awk '{print $2}' | tr -d ':' | sort -u)"
  ORDERED="$(printf '%s\n' "$ALL_CLASSES" | grep Screenshot || true)
$(printf '%s\n' "$ALL_CLASSES" | grep -v Screenshot || true)"
  i=0
  for name in $ORDERED; do
    if [[ $(( i % SHARD_TOTAL + 1 )) -eq $SHARD_INDEX ]]; then CLASSES+=("$name"); fi
    i=$(( i + 1 ))
  done
  if [[ ${#CLASSES[@]} -eq 0 ]]; then
    echo "==> Shard $SHARD_INDEX/$SHARD_TOTAL: no UI test classes left for this shard"
    exit 0
  fi
  echo "==> UI tests: full suite, shard $SHARD_INDEX/$SHARD_TOTAL: ${CLASSES[*]}"
elif [[ "$MODE" == "full" ]]; then
  echo "==> UI tests: full suite"
fi

echo "==> KickCore unit tests"
scripts/test-core.sh

if [[ -d Packages/KickData ]]; then
  echo "==> KickData unit tests"
  (cd Packages/KickData && swift test)
fi

echo "==> Generating Xcode project"
xcodegen generate --quiet

DEVICE_ID="$(xcrun simctl list devices available | grep -m1 -E '^[[:space:]]+iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')"
[[ -n "$DEVICE_ID" ]] || { echo "No available iPhone simulator" >&2; exit 1; }

echo "==> Booting simulator $DEVICE_ID"
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b

XCODE_ACTION="test"
[[ "$MODE" == "main" ]] && XCODE_ACTION="build"
ONLY_TESTING_ARGS=()
for name in ${CLASSES[@]+"${CLASSES[@]}"}; do
  ONLY_TESTING_ARGS+=("-only-testing:$UI_TEST_TARGET/$name")
done

# A build number other than project.yml's "1", so a hard-coded CFBundleVersion is caught.
CI_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-4242}"
MARKETING_VERSION="$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml | head -1)"
rm -rf build && mkdir -p build/screenshots
echo "==> xcodebuild $XCODE_ACTION on simulator $DEVICE_ID (build $CI_BUILD_NUMBER)"
STATUS=0
xcodebuild -project KickCounter.xcodeproj -scheme KickCounter \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/KickCounter.xcresult \
  ${ONLY_TESTING_ARGS[@]+"${ONLY_TESTING_ARGS[@]}"} \
  CURRENT_PROJECT_VERSION="$CI_BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO -quiet "$XCODE_ACTION" || STATUS=$?

echo "==> Checking bundle versions"
scripts/check-bundle-versions.sh \
  build/DerivedData/Build/Products/Debug-iphonesimulator/KickCounter.app \
  "$CI_BUILD_NUMBER" "$MARKETING_VERSION" || STATUS=1

if [[ "$XCODE_ACTION" == "test" ]]; then
  echo "==> Exporting screenshots"
  xcrun xcresulttool export attachments --path build/KickCounter.xcresult --output-path build/screenshots || true
  python3 - <<'PY'
import json, os, re
d = "build/screenshots"
manifest = os.path.join(d, "manifest.json")
if os.path.exists(manifest):
    for test in json.load(open(manifest)):
        for a in test.get("attachments", []):
            src = os.path.join(d, a["exportedFileName"])
            name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            # upload-artifact rejects " : < > | * ? \r \n (e.g. failure debug descriptions).
            name = re.sub(r'[":<>|*?\r\n]', "_", name)
            if os.path.exists(src):
                os.rename(src, os.path.join(d, name))
PY
fi

[[ $STATUS -eq 0 ]] && echo "==> All checks passed"
exit $STATUS
