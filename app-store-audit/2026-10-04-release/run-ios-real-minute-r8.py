#!/usr/bin/env python3
"""One targeted denied-recovery tail on root's existing private phone; no other device actions."""
from pathlib import Path
import datetime
import hashlib
import json
import plistlib
import subprocess
import sys

ROOT = Path('/Users/nathan/Documents/GitHub/How-To-Adult')
AUDIT = ROOT / 'app-store-audit/2026-10-04-release'
OWNED = '1E5F4647-2BA3-4F26-8E75-9803F528D1BA'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-18-6'
NAME = 'HowToAdult-Completion-QA-Phone-20261004-123824'
METHOD = 'testRealReminderDeliveryAndTapRoute'
TARGET = 'HowToAdultUITests-iOS'
RESULT = Path('/tmp/howtoadult-real-minute-r8-1E5F4647-20261004.xcresult')
RECEIPT = AUDIT / 'ios-real-minute-r8-runtime-receipt.json'

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def files(root):
    return {str(p.relative_to(root)): sha(p) for p in sorted(root.rglob('*')) if p.is_file()}

def call(argv, required=True):
    value = subprocess.run(argv, capture_output=True, text=True)
    receipt['actions'].append({'atUTC': now(), 'command': argv, 'exit': value.returncode,
        'stdout': value.stdout[:1500], 'stdoutSHA256': hashlib.sha256(value.stdout.encode()).hexdigest(),
        'stderr': value.stderr[:1500]})
    if required and value.returncode:
        raise RuntimeError(f'Command failed: {argv[:3]}')
    return value

def device():
    inventory = json.loads(call(['xcrun', 'simctl', 'list', 'devices', '-j']).stdout)['devices']
    matches = [d for runtime, entries in inventory.items() if runtime == RUNTIME
               for d in entries if d['udid'] == OWNED]
    assert len(matches) == 1
    value = matches[0]
    assert value['name'] == NAME and value['isAvailable']
    assert value['deviceTypeIdentifier'] == 'com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max'
    return value

def traits(required=True):
    return {name: call(['xcrun', 'simctl', 'ui', OWNED, name], required).stdout.strip()
            for name in ('appearance', 'content_size')}

def guard():
    assert sha(AUDIT / 'ios-real-minute-r8-freeze.json') == freeze_sha
    assert frozen['shippingAggregateSHA256'] == 'cd9e1ee587f615268ee1157e9fb9693d3078762059a06dae11bcf48e06abb9df'
    assert all(sha(ROOT / p) == h for p, h in frozen['shippingInputs'].items())
    assert sha(ROOT / frozen['testFile']) == frozen['testSHA256']
    assert files(Path(frozen['originalReleaseApp'])) == frozen['originalAppFiles']
    assert sha(Path(frozen['originalReleaseApp']) / 'How to Adult') == 'd7f1b727171bbc1cca494056ff608689cd9be26a8fa9bc39936f14fea59cc7db'
    assert sha(PLAN) == build['isolatedUIOnlyPlanSHA256']
    assert files(RUNNER) == build['runnerFiles']
    plan = plistlib.loads(PLAN.read_bytes())
    assert set(plan) == {TARGET, '__xctestrun_metadata__'}
    assert plan[TARGET]['UITargetAppPath'] == frozen['originalReleaseApp']
    assert plan[TARGET]['OnlyTestIdentifiers'] == ['AdultUITests/' + METHOD]

def normal_host_snapshot():
    home = Path.home()
    roots = [home / 'Library/Preferences/com.nathanfennel.How-To-Adult.plist',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Documents',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Library/Application Support',
             home / 'Library/Containers/com.nathanfennel.How-To-Adult/Data/Library/Preferences']
    result = {}
    for root in roots:
        if root.is_file():
            result[str(root)] = sha(root)
        elif root.exists():
            for p in sorted(root.rglob('*')):
                if p.is_file() and not p.is_symlink():
                    result[str(p)] = sha(p)
    return result

assert not RECEIPT.exists() and not RESULT.exists(), 'Preserve prior runtime receipts.'
tail = json.loads((AUDIT / 'ios-denied-tail-r4-summary.json').read_text())
assert tail['totalTestCount'] == 1 and tail['passedTests'] == 1 and tail['failedTests'] == 0, 'Phase B requires the approved denied-recovery tail to pass first.'
phase_b = json.loads((AUDIT / 'ios-notification-header-r6-summary.json').read_text())
assert phase_b['totalTestCount'] == 1 and phase_b['passedTests'] == 1 and phase_b['failedTests'] == 0, 'Phase C requires actual Settings recovery/picker1PASS.'
frozen = json.loads((AUDIT / 'ios-real-minute-r8-freeze.json').read_text())
freeze_sha = sha(AUDIT / 'ios-real-minute-r8-freeze.json')
build = json.loads((AUDIT / 'ios-real-minute-r8-build-receipt.json').read_text())
assert build['buildExit'] == 0
PLAN = Path(build['isolatedUIOnlyPlan'])
RUNNER = PLAN.parent / 'Release-iphonesimulator/HowToAdultUITests-iOS-Runner.app'
receipt = {'startedAtUTC': now(), 'scope': 'Sole actual DatePicker scheduling, native pending-record and real SpringBoard notification delivery/tap route on private1E5; no synthetic notifications',
    'authorization': 'Root read phaseC r6 plan and actual expanded picker AX/PNG; explicitly authorized sole fresh phaseC runner/runtime after phaseB1PASS.',
    'wrapperSHA256': sha(Path(__file__)), 'testOnlyFreezeSHA256': freeze_sha,
    'buildReceiptSHA256': sha(AUDIT / 'ios-real-minute-r8-build-receipt.json'),
    'ownedPhone': OWNED, 'shippingInputCount': 35, 'shippingInputChanges': 0,
    'originalReleaseExecutableSHA256': frozen['originalReleaseExecutableSHA256'],
    'actions': [], 'normalHostBefore': normal_host_snapshot(),
    'otherDeviceActions': 0, 'notificationDeliveryOrTapClaim': 'Requires actual processed-result and native attachment review; this wrapper alone makes no success claim',
    'retainedEvidence': ['ios-completion-1-summary.json: dark/largest method1/1PASS',
                         'ios-completion-2-summary.json: prior Share selector method1/1FAIL',
                         'ios-share-selector-r2-summary.json: close-selector1/1FAIL',
                         'ios-share-dismissal-r3-summary.json: denied-tail assumption1/1FAIL']}
status = 1
boot_attempted = False
before = None
try:
    guard()
    current = device()
    assert current['state'] == 'Shutdown'
    receipt['preflightDevice'] = current
    boot_attempted = True
    call(['xcrun', 'simctl', 'boot', OWNED])
    call(['xcrun', 'simctl', 'bootstatus', OWNED, '-b'])
    before = traits()
    assert before == {'appearance': 'light', 'content_size': 'large'}
    receipt['traitsBefore'] = before
    base = ['xcodebuild', 'test-without-building', '-xctestrun', str(PLAN),
        '-destination', 'platform=iOS Simulator,id=' + OWNED, '-parallel-testing-enabled', 'NO',
        '-maximum-concurrent-test-simulator-destinations', '1', '-jobs', '2',
        '-only-testing:' + TARGET + '/AdultUITests/' + METHOD]
    enumeration = AUDIT / 'ios-real-minute-r8-enumeration.json'
    enum_command = base + ['-enumerate-tests', '-test-enumeration-style', 'flat',
        '-test-enumeration-format', 'json', '-test-enumeration-output-path', str(enumeration)]
    with (AUDIT / 'ios-real-minute-r8-enumeration.log').open('w') as output:
        value = subprocess.run(enum_command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    receipt['enumerationCommand'] = enum_command
    receipt['enumerationExit'] = value.returncode
    assert value.returncode == 0
    data = json.loads(enumeration.read_text())
    enabled = [test['identifier'] for group in data['values'] for test in group.get('enabledTests', [])]
    assert len(enabled) == 1 and enabled[0].removesuffix('()') == TARGET + '/AdultUITests/' + METHOD, enabled
    receipt['enumeratedEnabledTests'] = enabled
    receipt['enumerationSHA256'] = sha(enumeration)
    guard()
    command = base + ['-resultBundlePath', str(RESULT)]
    log = AUDIT / 'ios-real-minute-r8-runtime.log'
    receipt['command'] = command
    with log.open('w') as output:
        value = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
    receipt.update(testExit=value.returncode, resultBundle=str(RESULT), log=log.name, logSHA256=sha(log))
    status = 0 if value.returncode == 0 else 1
except BaseException as error:
    receipt['wrapperFailure'] = repr(error)
finally:
    if boot_attempted:
        # Root authorized restoring only these private system traits. Usually no writes are needed.
        observed = traits(required=False)
        receipt['traitsBeforeRestoration'] = observed
        for key, expected in {'appearance': 'light', 'content_size': 'large'}.items():
            if observed[key] != expected:
                call(['xcrun', 'simctl', 'ui', OWNED, key, expected], required=False)
        receipt['traitsAfter'] = traits(required=False)
        receipt['shutdownExit'] = call(['xcrun', 'simctl', 'shutdown', OWNED], required=False).returncode
        try:
            receipt['finalDeviceState'] = device()['state']
        except BaseException as error:
            receipt['finalStateError'] = repr(error)
        if receipt.get('finalDeviceState') != 'Shutdown':
            status = 1
    receipt['normalHostAfter'] = normal_host_snapshot()
    receipt['normalHostUnchanged'] = receipt['normalHostBefore'] == receipt['normalHostAfter']
    try:
        guard()
        receipt['sourceOriginalAppRunnerAndPlanUnchanged'] = True
    except BaseException as error:
        receipt['postflightGuardFailure'] = repr(error)
        status = 1
    if not receipt['normalHostUnchanged']:
        status = 1
    if receipt.get('traitsAfter') != {'appearance': 'light', 'content_size': 'large'}:
        status = 1
    receipt['finishedAtUTC'] = now()
    receipt['wrapperExit'] = status
    receipt['processedTestCountRequired'] = 'Export actual xcresult summary and attachments only after final Shutdown; exit0 alone is not a test count.'
    RECEIPT.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: receipt.get(k) for k in ['testExit', 'wrapperFailure', 'finalDeviceState',
        'normalHostUnchanged', 'sourceOriginalAppRunnerAndPlanUnchanged', 'traitsAfter', 'wrapperExit']}, indent=2))
sys.exit(status)
