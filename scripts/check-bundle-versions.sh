#!/usr/bin/env bash
# Fails unless the built app and its widget extension carry the expected
# version numbers (they must follow MARKETING_VERSION / CURRENT_PROJECT_VERSION).
# Usage: scripts/check-bundle-versions.sh <path/to/KickCounter.app> <expected CFBundleVersion> <expected CFBundleShortVersionString>
set -euo pipefail
APP="$1"
EXPECTED_BUILD="$2"
EXPECTED_VERSION="$3"
PLIST_BUDDY=/usr/libexec/PlistBuddy
STATUS=0
for PLIST in "$APP/Info.plist" "$APP/PlugIns/KickCounterWidgets.appex/Info.plist"; do
  if [[ ! -f "$PLIST" ]]; then
    echo "Missing $PLIST" >&2
    STATUS=1
    continue
  fi
  BUILD="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || echo '<missing>')"
  VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo '<missing>')"
  if [[ "$BUILD" != "$EXPECTED_BUILD" || "$VERSION" != "$EXPECTED_VERSION" ]]; then
    echo "Version mismatch in $PLIST: CFBundleVersion=$BUILD (expected $EXPECTED_BUILD), CFBundleShortVersionString=$VERSION (expected $EXPECTED_VERSION)" >&2
    STATUS=1
  else
    echo "OK $PLIST: $VERSION ($BUILD)"
  fi
done

# A normal (non-TestFlight-content-preview) build must not show unreviewed
# pregnancy content. See docs/release-checklist.md / final-fix-wave.md item 1.
MAIN_PLIST="$APP/Info.plist"
if [[ -f "$MAIN_PLIST" ]]; then
  CONTENT_PREVIEW_FLAG="$("$PLIST_BUDDY" -c 'Print :LunaContentPreview' "$MAIN_PLIST" 2>/dev/null || echo '<missing>')"
  if [[ "$CONTENT_PREVIEW_FLAG" != "NO" ]]; then
    echo "Expected LunaContentPreview=NO in $MAIN_PLIST, got $CONTENT_PREVIEW_FLAG" >&2
    STATUS=1
  else
    echo "OK $MAIN_PLIST: LunaContentPreview=$CONTENT_PREVIEW_FLAG"
  fi
fi
# App Store processing rejects an App Intent whose description (its key or its text)
# mentions Siri (error 90626), after the upload has already succeeded.
INTENTS="$APP/Metadata.appintents/extract.actionsdata"
if [[ -f "$INTENTS" ]]; then
  if ! python3 -I - "$INTENTS" <<'PY'
import json, sys
actions = json.load(open(sys.argv[1])).get("actions", {})
bad = [name for name, action in actions.items()
       if "siri" in json.dumps(action.get("descriptionMetadata") or {}).lower()]
for name in bad:
    print(f"App Intent {name}: its description mentions Siri (App Store error 90626)", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
  then
    STATUS=1
  else
    echo "OK $INTENTS: no App Intent description mentions Siri"
  fi
fi
exit $STATUS
