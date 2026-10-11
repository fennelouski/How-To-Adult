#!/usr/bin/env python3
"""Compile only a matching Release QA runner; retain the verified original app."""
from pathlib import Path
import datetime
import hashlib
import json
import plistlib
import subprocess

ROOT = Path('/Users/nathan/Documents/GitHub/How-To-Adult')
AUDIT = ROOT / 'app-store-audit/2026-10-04-release'
DD = Path('/tmp/howtoadult-notification-apps-r5-20261004')
ORIGINAL_APP = Path('/tmp/howtoadult-live-phone-20261003/Build/Products/Release-iphonesimulator/How to Adult.app')

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def source_guard():
    freeze = json.loads((ROOT / 'app-store-audit/2026-10-03-how-to-adult/native-inputs-live-privacy-final.json').read_text())
    for relative, expected in freeze['files'].items():
        assert sha(ROOT / relative) == expected, relative
    assert sha(ROOT / 'UITests/AdultUITests.swift') == 'bbc06426fa032ec203b5e7e01c9340a9556eb93ed3753faf798f27370eacdc2e'
    assert freeze['sha256'] == 'cd9e1ee587f615268ee1157e9fb9693d3078762059a06dae11bcf48e06abb9df'
    return freeze

def original_app_guard():
    expected = json.loads((ROOT / 'app-store-audit/2026-10-03-how-to-adult/native-builds-live-privacy-final.json').read_text())
    assert sha(ORIGINAL_APP / 'How to Adult') == expected['executableSHA256']
    info = plistlib.loads((ORIGINAL_APP / 'Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.nathanfennel.How-To-Adult'
    assert info['CFBundleShortVersionString'] == '1.0'
    assert info['CFBundleVersion'] == '1'
    files = {str(p.relative_to(ORIGINAL_APP)): sha(p) for p in sorted(ORIGINAL_APP.rglob('*')) if p.is_file()}
    held = json.loads((AUDIT / 'ios-notification-apps-r5-freeze.json').read_text())
    assert files == held['originalAppFiles'], 'Original Release app must match all 45 held files.'
    assert sha(ORIGINAL_APP / 'How to Adult') == held['originalReleaseExecutableSHA256']
    return files

assert not DD.exists(), 'Preserve prior derived-data artifacts; choose an empty candidate root.'
assert not (AUDIT / 'ios-notification-apps-r5-build-receipt.json').exists()
freeze = source_guard()
before = original_app_guard()
command = ['xcodebuild', 'build-for-testing', '-project', 'HowToAdult.xcodeproj',
           '-scheme', 'HowToAdult-iOS', '-configuration', 'Release',
           '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', str(DD),
           '-jobs', '2', 'CODE_SIGNING_ALLOWED=NO', 'ENABLE_TESTABILITY=YES']
receipt = {'startedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'nativeInputsSHA256': freeze['sha256'], 'command': command,
           'originalReleaseApp': str(ORIGINAL_APP), 'originalAppFilesBefore': before,
           'testOnlyFreezeSHA256': sha(AUDIT / 'ios-notification-apps-r5-freeze.json'),
           'testFileSHA256': sha(ROOT / 'UITests/AdultUITests.swift'),
           'priorFailedBuildRuntimeEvidencePreserved': True,
           'deviceActions': 0, 'scope': 'New test-only Release runner. Runtime target remains the verified original Release1.0(1) app.'}
log = AUDIT / 'ios-notification-apps-r5-build.log'
with log.open('w') as output:
    code = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT).returncode
receipt['buildExit'] = code
receipt['buildLogSHA256'] = sha(log)
receipt['finishedAtUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt['originalAppFilesAfter'] = original_app_guard()
assert before == receipt['originalAppFilesAfter']
source_guard()
if code == 0:
    products = DD / 'Build/Products'
    generated = list(products.glob('*.xctestrun'))
    assert len(generated) == 1, generated
    plan = plistlib.loads(generated[0].read_bytes())
    ui = plan['HowToAdultUITests-iOS']
    ui['UITargetAppPath'] = str(ORIGINAL_APP)
    ui['OnlyTestIdentifiers'] = [
        'AdultUITests/testNativeNotificationSettingsAndPickerReconnaissance']
    ui['DependentProductPaths'] = [str(ORIGINAL_APP),
        '__TESTROOT__/Release-iphonesimulator/HowToAdultUITests-iOS-Runner.app',
        '__TESTROOT__/Release-iphonesimulator/HowToAdultUITests-iOS-Runner.app/PlugIns/HowToAdultUITests-iOS.xctest']
    isolated = {'HowToAdultUITests-iOS': ui, '__xctestrun_metadata__': plan['__xctestrun_metadata__']}
    destination = products / 'HowToAdult-Notification-Apps-R5-UI-only.xctestrun'
    destination.write_bytes(plistlib.dumps(isolated))
    runner = products / 'Release-iphonesimulator/HowToAdultUITests-iOS-Runner.app'
    receipt['isolatedUIOnlyPlan'] = str(destination)
    receipt['isolatedUIOnlyPlanSHA256'] = sha(destination)
    receipt['runnerFiles'] = {str(p.relative_to(runner)): sha(p) for p in sorted(runner.rglob('*')) if p.is_file()}
    receipt['methods'] = ui['OnlyTestIdentifiers']
    receipt['unitMethodsSelected'] = 0
    receipt['runtimeRuns'] = 0
(AUDIT / 'ios-notification-apps-r5-build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({k: receipt[k] for k in ('buildExit','nativeInputsSHA256','originalReleaseApp','deviceActions')}, indent=2))
raise SystemExit(code)
