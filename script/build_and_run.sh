#!/usr/bin/env bash
set -euo pipefail

adult_mode="${1:-run}"
case "$adult_mode" in
  run|--debug|--logs|--telemetry|--verify) ;;
  --help|-h)
    printf '%s\n' 'Usage: ./script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify]'
    exit 0
    ;;
  *) printf '%s\n' 'Unknown mode. Use --help.' >&2; exit 2 ;;
esac

adult_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adult_app_name="How to Adult"
adult_bundle_id="com.nathanfennel.How-To-Adult"
adult_build_root="$adult_project_root/build/macos"
adult_app_bundle="$adult_build_root/Build/Products/Debug/$adult_app_name.app"
adult_app_binary="$adult_app_bundle/Contents/MacOS/$adult_app_name"

# Stop only this checkout's existing local build, never another app or install.
python3 - "$adult_app_binary" "$adult_app_name" <<'PY'
import os, signal, subprocess, sys, time
binary, name = sys.argv[1:]
result = subprocess.run(['pgrep', '-x', name], capture_output=True, text=True)
owned = []
for item in result.stdout.split():
    pid = int(item)
    path = subprocess.run(['ps', '-p', str(pid), '-o', 'comm='], capture_output=True, text=True).stdout.strip()
    owner = subprocess.run(['ps', '-p', str(pid), '-o', 'uid='], capture_output=True, text=True).stdout.strip()
    if path == binary and owner == str(os.getuid()):
        try:
            os.kill(pid, signal.SIGTERM)
            owned.append(pid)
        except ProcessLookupError:
            pass
for _ in range(30):
    alive = []
    for pid in owned:
        try:
            os.kill(pid, 0)
            alive.append(pid)
        except ProcessLookupError:
            pass
    if not alive:
        break
    time.sleep(0.1)
else:
    raise SystemExit('The previous local app did not exit. It was not force-quit.')
PY

xcodebuild -project "$adult_project_root/HowToAdult.xcodeproj" \
  -scheme HowToAdult-macOS -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$adult_build_root" CODE_SIGNING_ALLOWED=NO build

python3 - "$adult_app_bundle/Contents/Info.plist" "$adult_bundle_id" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleIdentifier') != sys.argv[2]:
    raise SystemExit('The built app has an unexpected bundle identifier.')
PY

# Local debug signature only. App Store exports use the separate release script.
codesign --force --sign - --entitlements "$adult_project_root/Configuration/macOS.entitlements" "$adult_app_bundle"

case "$adult_mode" in
  run) /usr/bin/open -n "$adult_app_bundle" ;;
  --debug) lldb -- "$adult_app_binary" ;;
  --logs)
    /usr/bin/open -n "$adult_app_bundle"
    /usr/bin/log stream --info --style compact --predicate "process == \"$adult_app_name\""
    ;;
  --telemetry)
    /usr/bin/open -n "$adult_app_bundle"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$adult_bundle_id\""
    ;;
  --verify)
    /usr/bin/open -n "$adult_app_bundle"
    python3 - "$adult_app_binary" "$adult_app_name" <<'PY'
import subprocess, sys, time
for _ in range(30):
    result = subprocess.run(['pgrep', '-x', sys.argv[2]], capture_output=True, text=True)
    for pid in result.stdout.split():
        path = subprocess.run(['ps', '-p', pid, '-o', 'comm='], capture_output=True, text=True).stdout.strip()
        if path == sys.argv[1]:
            print('The local How to Adult process is running.')
            raise SystemExit(0)
    time.sleep(0.1)
raise SystemExit('The local app did not stay running.')
PY
    ;;
esac
