#!/usr/bin/env bash
# Full quality gate. Runs on GitHub Actions (requires Xcode + XcodeGen).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

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

# Scoped UI testing: a HEAD commit trailer "CI-Only-Testing: ClassA, ClassB" runs
# only those UI test classes. Names must match [A-Za-z0-9_]+ (no shell injection
# from commit messages); anything invalid ignores the trailer (full suite).
UI_TEST_TARGET="KickCounterUITests"
ONLY_TESTING_ARGS=()
TRAILER="$(git log -1 --format=%B | sed -n 's/^CI-Only-Testing:[[:space:]]*//p' | head -1)"
if [[ -n "$TRAILER" ]]; then
  VALID=1
  CLASSES=()
  IFS=',' read -r -a RAW_CLASSES <<< "$TRAILER"
  for raw in "${RAW_CLASSES[@]}"; do
    name="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ "$name" =~ ^[A-Za-z0-9_]+$ ]]; then
      CLASSES+=("$name")
    else
      VALID=0
    fi
  done
  if [[ $VALID -eq 1 && ${#CLASSES[@]} -gt 0 ]]; then
    for name in "${CLASSES[@]}"; do
      ONLY_TESTING_ARGS+=("-only-testing:$UI_TEST_TARGET/$name")
    done
    echo "==> UI tests: scoped to ${CLASSES[*]} (CI-Only-Testing trailer)"
  else
    echo "==> UI tests: full suite (CI-Only-Testing trailer ignored: invalid class name)"
  fi
else
  echo "==> UI tests: full suite"
fi

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
