#!/usr/bin/env bash
set -euo pipefail

adult_mode="${1:-run}"
case "$adult_mode" in
  run|--debug|--logs|--telemetry|--verify|--qa-dark-large) ;;
  --help|-h)
    printf '%s\n' 'Usage: ./script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify|--qa-dark-large]'
    exit 0
    ;;
  *) printf '%s\n' 'Unknown mode. Use --help.' >&2; exit 2 ;;
esac

adult_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adult_app_name="How to Adult"
adult_bundle_id="com.nathanfennel.How-To-Adult"
adult_team_id="EJLR2RPSV2"
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
  -derivedDataPath "$adult_build_root" -allowProvisioningUpdates \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM="$adult_team_id" build

python3 - "$adult_app_bundle/Contents/Info.plist" "$adult_bundle_id" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleIdentifier') != sys.argv[2]:
    raise SystemExit('The built app has an unexpected bundle identifier.')
PY

# Keep Xcode's development identity so the sandbox container has a stable owner.
# Verify its nested signatures explicitly; do not replace them with ad hoc ones.
for adult_dylib in "$adult_app_bundle/Contents/MacOS/"*.dylib; do
  [[ -f "$adult_dylib" ]] || continue
  if [[ -L "$adult_dylib" ]]; then
    printf '%s\n' "Refusing to sign a linked debug dylib: $adult_dylib" >&2
    exit 1
  fi
  codesign --verify --strict "$adult_dylib"
done
codesign --verify --strict "$adult_app_bundle"
python3 - "$adult_app_bundle" "$adult_bundle_id" "$adult_team_id" <<'PY'
import plistlib, subprocess, sys
app, bundle_id, team_id = sys.argv[1:]
details = subprocess.run(['codesign', '-dvvv', app], capture_output=True, text=True, check=True).stderr
if f'Identifier={bundle_id}\n' not in details or f'TeamIdentifier={team_id}\n' not in details:
    raise SystemExit('The local app must retain its configured bundle and development team identity.')
if 'Authority=Apple Development:' not in details:
    raise SystemExit('The local app does not have an Apple Development signature.')
result = subprocess.run(['codesign', '-d', '--entitlements', ':-', app], capture_output=True, check=True)
entitlements = plistlib.loads(result.stdout)
if entitlements.get('com.apple.security.app-sandbox') is not True or entitlements.get('com.apple.security.network.client') is not True:
    raise SystemExit('The signed local app is missing its configured sandbox or network entitlement.')
app_id = entitlements.get('com.apple.application-identifier')
if app_id is not None and app_id != f'{team_id}.{bundle_id}':
    raise SystemExit('The local application-identifier entitlement does not match its configured identity.')
print(f'Local Apple Development signature verified: Identifier={bundle_id}; TeamIdentifier={team_id}; application-identifier={app_id or "not declared by Xcode"}.')
PY

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
  --verify|--qa-dark-large)
    if [[ "$adult_mode" == --qa-dark-large ]]; then
      /usr/bin/open -n "$adult_app_bundle" --args --qa-dark --qa-accessibility-text
    else
      /usr/bin/open -n "$adult_app_bundle"
    fi
    python3 - "$adult_app_binary" "$adult_app_name" <<'PY'
import subprocess, sys, time
running_since = None
running_pid = None
for _ in range(30):
    result = subprocess.run(['pgrep', '-x', sys.argv[2]], capture_output=True, text=True)
    matching_pid = None
    for pid in result.stdout.split():
        path = subprocess.run(['ps', '-p', pid, '-o', 'comm='], capture_output=True, text=True).stdout.strip()
        if path == sys.argv[1]:
            matching_pid = pid
            break
    if matching_pid is not None:
        if matching_pid != running_pid:
            running_pid = matching_pid
            running_since = time.monotonic()
        elif time.monotonic() - running_since >= 1:
            print(f'The local How to Adult process {running_pid} stayed running for at least one second.')
            raise SystemExit(0)
    else:
        running_pid = None
        running_since = None
    time.sleep(0.1)
raise SystemExit('The local app did not stay running.')
PY
    ;;
esac
