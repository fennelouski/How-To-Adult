#!/usr/bin/env python3
"""Two UI checks on one newly created, exclusively owned headless QA phone."""
from pathlib import Path
import datetime
import hashlib
import json
import plistlib
import subprocess
import sys

ROOT = Path('/Users/nathan/Documents/GitHub/How-To-Adult')
AUDIT = ROOT / 'app-store-audit/2026-10-04-release'
TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-18-6'
METHODS = ['testDarkAppearanceAndAccessibilityText', 'testNativeShareAndNotificationDenialRecovery']

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def call(argv, required=True):
    result = subprocess.run(argv, capture_output=True, text=True)
    action = {'atUTC': now(), 'command': argv, 'exit': result.returncode,
              'stdout': result.stdout.strip(), 'stderr': result.stderr.strip()}
    receipt['actions'].append(action)
    if required and result.returncode:
        raise RuntimeError(f'Command failed: {argv[0:3]}')
    return result

def native_guard():
    f = json.loads((ROOT / 'app-store-audit/2026-10-03-how-to-adult/native-inputs-live-privacy-final.json').read_text())
    assert all(sha(ROOT / p) == h for p, h in f['files'].items())
    assert sha(ROOT / 'UITests/AdultUITests.swift') == '0e7e9b4418695ff3e14dfc54723549d942484705e3717fff1adc768f13bd8ad8'
    assert sha(PLAN) == build['isolatedUIOnlyPlanSHA256']
    for relative, expected in build['originalAppFilesBefore'].items():
        assert sha(Path(build['originalReleaseApp']) / relative) == expected, relative

def host_normal_snapshot():
    home = Path.home()
    roots = [home / 'Library/Preferences/com.nathanfennel.How-To-Adult.plist',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Documents',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Library/Application Support',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Library/Preferences']
    files = {}
    for root in roots:
        if root.is_file(): files[str(root)] = sha(root)
        elif root.exists():
            for p in sorted(root.rglob('*')):
                if p.is_file() and not p.is_symlink(): files[str(p)] = sha(p)
    return files

build = json.loads((AUDIT / 'ios-completion-build-receipt.json').read_text())
assert build['buildExit'] == 0
PLAN = Path(build['isolatedUIOnlyPlan'])
receipt = {'startedAtUTC': now(), 'scope': 'Two exact UI-only methods, original verified Release1.0(1) app',
           'nativeInputChanges': 0, 'actions': [], 'runs': [], 'device': None,
           'existingDevicesModified': False, 'notificationPermission': 'Only the newly created QA app/device may be denied',
           'limits': ['Actual physical haptics, Mac consent/runtime, and notification delivery/tap are not established by these checks.']}
owned = None
appearance = None
content_size = None
status = 1
receipt['normalHostBefore'] = host_normal_snapshot()
try:
    native_guard()
    devices_before = json.loads(call(['xcrun','simctl','list','devices','-j']).stdout)['devices']
    before_ids = {d['udid'] for ds in devices_before.values() for d in ds}
    name = 'HowToAdult-Completion-QA-Phone-20261004-' + datetime.datetime.now().strftime('%H%M%S')
    owned = call(['xcrun','simctl','create',name,TYPE,RUNTIME]).stdout.strip()
    assert owned not in before_ids
    devices = json.loads(call(['xcrun','simctl','list','devices','-j']).stdout)['devices']
    found = [d for runtime, ds in devices.items() if runtime == RUNTIME for d in ds if d['udid']==owned]
    assert len(found)==1 and found[0]['name']==name and found[0]['state']=='Shutdown'
    assert found[0]['deviceTypeIdentifier']==TYPE
    receipt['device'] = found[0]
    receipt['ownership'] = 'Created exclusively for this two-method plan; no prior apps/notifications or user data'
    call(['xcrun','simctl','boot',owned])
    call(['xcrun','simctl','bootstatus',owned,'-b'])
    appearance = call(['xcrun','simctl','ui',owned,'appearance']).stdout.strip()
    content_size = call(['xcrun','simctl','ui',owned,'content_size']).stdout.strip()
    receipt['appearanceBefore'] = appearance
    receipt['contentSizeBefore'] = content_size
    for index, method in enumerate(METHODS):
        if index == 0:
            call(['xcrun','simctl','ui',owned,'appearance','dark'])
            call(['xcrun','simctl','ui',owned,'content_size','accessibility-extra-extra-extra-large'])
        else:
            call(['xcrun','simctl','ui',owned,'appearance',appearance])
            call(['xcrun','simctl','ui',owned,'content_size',content_size])
        traits = {k: call(['xcrun','simctl','ui',owned,k]).stdout.strip() for k in ('appearance','content_size')}
        native_guard()
        result = Path('/tmp') / f'howtoadult-completion-{owned}-{index+1}.xcresult'
        assert not result.exists()
        command = ['xcodebuild','test-without-building','-xctestrun',str(PLAN),
                   '-destination',f'id={owned}','-parallel-testing-enabled','NO',
                   '-maximum-concurrent-test-simulator-destinations','1', '-jobs','2',
                   '-only-testing:HowToAdultUITests-iOS/AdultUITests/' + method,
                   '-resultBundlePath',str(result)]
        log = AUDIT / f'ios-completion-{index+1}.log'
        with log.open('w') as output:
            code = subprocess.run(command,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT).returncode
        receipt['runs'].append({'method':method,'command':command,'exit':code,'actualSystemTraits':traits,
                                'resultBundle':str(result),'log':str(log),'logSHA256':sha(log)})
        native_guard()
    status = 0 if all(run['exit']==0 for run in receipt['runs']) else 1
except Exception as error:
    receipt['error'] = repr(error)
finally:
    if owned:
        if appearance is not None:
            call(['xcrun','simctl','ui',owned,'appearance',appearance],required=False)
        if content_size is not None:
            call(['xcrun','simctl','ui',owned,'content_size',content_size],required=False)
        receipt['appearanceAfter'] = call(['xcrun','simctl','ui',owned,'appearance'],required=False).stdout.strip()
        receipt['contentSizeAfter'] = call(['xcrun','simctl','ui',owned,'content_size'],required=False).stdout.strip()
        receipt['shutdownExit'] = call(['xcrun','simctl','shutdown',owned],required=False).returncode
        final_devices=json.loads(call(['xcrun','simctl','list','devices','-j'],required=False).stdout)['devices']
        receipt['finalState'] = next(d['state'] for ds in final_devices.values() for d in ds if d['udid']==owned)
        if receipt['finalState']!='Shutdown': status=1
    receipt['normalHostAfter'] = host_normal_snapshot()
    receipt['normalHostUnchanged'] = receipt['normalHostBefore']==receipt['normalHostAfter']
    if not receipt['normalHostUnchanged']:status=1
    try:
        native_guard()
        receipt['nativeSourceAndOriginalReleaseAppUnchanged']=True
    except Exception as error:
        receipt['postflightGuardError']=repr(error)
        status=1
    receipt['finishedAtUTC']=now()
    receipt['wrapperExit']=status
    receipt['actualResultSummaryRequired']='Read and export each xcresult sequentially only after final device Shutdown; exit0 alone is not a passed-test count.'
    (AUDIT / 'ios-completion-runtime-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:receipt.get(k) for k in ('device','runs','finalState','normalHostUnchanged','wrapperExit')},indent=2))
sys.exit(status)
