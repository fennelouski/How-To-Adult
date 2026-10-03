#!/usr/bin/env python3
"""Archive/export signed App Store packages from a frozen native revision.

This builds on the local Mac. It never uploads, registers an App Store Connect
record, runs Simulator, launches the app, or invokes visionOS tooling.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "How to Adult"
BUNDLE_ID = "com.nathanfennel.How-To-Adult"
TEAM = "EJLR2RPSV2"
INPUTS = ["Sources", "Configuration", "Resources", "Content", "HowToAdult.xcodeproj", "project.yml"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


def frozen_inputs(revision):
    commit = git("rev-parse", "--verify", revision + "^{commit}")
    if git("rev-parse", "HEAD") != commit:
        raise RuntimeError("The checkout must be at the requested frozen revision.")
    dirty = git("status", "--porcelain", "--untracked-files=all", "--", *INPUTS)
    if dirty:
        raise RuntimeError("Native inputs differ from the requested commit. Commit or restore them before archiving.")
    names = git("ls-files", "--", *INPUTS).splitlines()
    if not names or "Sources/AdultViews.swift" not in names:
        raise RuntimeError("The modern native app is not committed at this revision.")
    hashes = {name: sha((ROOT / name).read_bytes()) for name in names}
    return {"revision": commit, "files": hashes, "sha256": sha(json.dumps(hashes, sort_keys=True).encode())}


def export_options(platform):
    path = ROOT / "Configuration" / f"ExportOptions-{platform}.plist"
    options = plistlib.loads(path.read_bytes())
    if options.get("destination") != "export" or options.get("method") != "app-store-connect" or options.get("teamID") != TEAM:
        raise RuntimeError("Only local App Store exports for the configured team are permitted.")
    return path


def commands(platform, output):
    folder = output / platform
    archive = folder / f"{APP_NAME}.xcarchive"
    destination = "generic/platform=iOS" if platform == "iOS" else "generic/platform=macOS"
    return [
        ["xcodebuild", "-project", str(ROOT / "HowToAdult.xcodeproj"), "-scheme", f"HowToAdult-{platform}", "-configuration", "Release", "-destination", destination, "-derivedDataPath", str(folder / "DerivedData"), "-archivePath", str(archive), "-allowProvisioningUpdates", f"DEVELOPMENT_TEAM={TEAM}", "archive"],
        ["xcodebuild", "-exportArchive", "-archivePath", str(archive), "-exportPath", str(folder / "Export"), "-exportOptionsPlist", str(export_options(platform)), "-allowProvisioningUpdates"],
    ]


def run(args, log, records):
    started = datetime.now(timezone.utc).isoformat()
    with log.open("wb") as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    records.append({"command": args, "startedAt": started, "completedAt": datetime.now(timezone.utc).isoformat(), "exitCode": result.returncode, "log": str(log)})
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); inspect {log}")
    return log.read_text(errors="replace")


def inspect_app(app, platform, logs, records, distribution):
    contents = app / "Contents" if platform == "macOS" else app
    resources = contents / "Resources" if platform == "macOS" else app
    info = plistlib.loads((contents / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise RuntimeError("Unexpected app bundle identifier.")
    if (resources / "catalog.json").read_bytes() != (ROOT / "Content/catalog.json").read_bytes():
        raise RuntimeError("Packaged guide library differs from the frozen source.")
    if (resources / "PrivacyInfo.xcprivacy").read_bytes() != (ROOT / "Configuration/PrivacyInfo.xcprivacy").read_bytes():
        raise RuntimeError("Packaged privacy manifest differs from the frozen source.")
    icon = info.get("CFBundleIconName") if platform == "macOS" else info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName")
    if icon != "AppIcon" or (platform == "iOS" and set(info.get("UIDeviceFamily", [])) != {1, 2}):
        raise RuntimeError("Primary app icon or iPhone/iPad device families are missing.")
    if any(app.rglob("*.xctest")):
        raise RuntimeError("A shipping app must not contain test bundles.")
    binary = (contents / "MacOS" if platform == "macOS" else app) / info["CFBundleExecutable"]
    prefix = "export" if distribution else "archive"
    architectures = run(["xcrun", "lipo", "-archs", str(binary)], logs / f"{prefix}-architectures.log", records).split()
    if set(architectures) != ({"arm64", "x86_64"} if platform == "macOS" else {"arm64"}):
        raise RuntimeError("Unexpected shipping architectures.")
    run(["codesign", "--verify", "--deep", "--strict", str(app)], logs / f"{prefix}-signature-verify.log", records)
    details = run(["codesign", "-dvvv", str(app)], logs / f"{prefix}-signature-details.log", records)
    if f"TeamIdentifier={TEAM}" not in details:
        raise RuntimeError("The app signature belongs to another team.")
    if distribution and not any(name in details for name in ["Authority=Apple Distribution", "Authority=3rd Party Mac Developer Application"]):
        raise RuntimeError("The exported app does not have an App Store distribution signature.")
    text = run(["codesign", "-d", "--entitlements", ":-", str(app)], logs / f"{prefix}-entitlements.log", records)
    start = text.find("<?xml")
    end = text.find("</plist>", start)
    if start < 0 or end < 0:
        raise RuntimeError("Cannot inspect the signed app entitlements.")
    entitlements = plistlib.loads(text[start:end + len("</plist>")].encode())
    if distribution and (entitlements.get("get-task-allow") or entitlements.get("com.apple.security.get-task-allow")):
        raise RuntimeError("The exported app permits debugger attachment.")
    if platform == "macOS" and (entitlements.get("com.apple.security.app-sandbox") is not True or entitlements.get("com.apple.security.network.client") is not True):
        raise RuntimeError("The signed Mac app is missing its declared sandbox/network entitlement.")
    return {"path": str(app), "bundleIdentifier": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"], "minimumOS": info.get("MinimumOSVersion", info.get("LSMinimumSystemVersion")), "architectures": architectures, "distributionSignature": distribution, "catalogSHA256": sha((resources / "catalog.json").read_bytes()), "privacyManifestSHA256": sha((resources / "PrivacyInfo.xcprivacy").read_bytes())}


def inspect_export(folder, platform, logs, records):
    exports = list((folder / "Export").glob("*.ipa" if platform == "iOS" else "*.pkg"))
    if len(exports) != 1:
        raise RuntimeError("Expected exactly one exported IPA or installer package.")
    package = exports[0]
    inspection = folder / "Inspection"
    inspection.mkdir()
    if platform == "iOS":
        with zipfile.ZipFile(package) as archive:
            for entry in archive.infolist():
                if not (inspection / entry.filename).resolve().is_relative_to(inspection.resolve()):
                    raise RuntimeError("Unsafe archive member path.")
            archive.extractall(inspection)
        apps = list((inspection / "Payload").glob("*.app"))
    else:
        signature = run(["pkgutil", "--check-signature", str(package)], logs / "installer-signature.log", records)
        if not any(name in signature for name in ["3rd Party Mac Developer Installer", "Mac Installer Distribution"]):
            raise RuntimeError("The package lacks an App Store installer signature.")
        expanded = inspection / "expanded-package"
        run(["pkgutil", "--expand-full", str(package), str(expanded)], logs / "installer-expansion.log", records)
        apps = list(expanded.rglob(f"{APP_NAME}.app"))
    if len(apps) != 1:
        raise RuntimeError("Cannot identify exactly one app in the exported package.")
    app = inspect_app(apps[0], platform, logs, records, distribution=True)
    return {"path": str(package), "bytes": package.stat().st_size, "sha256": sha(package.read_bytes()), "app": app}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", required=True, help="The frozen native commit; must match HEAD")
    parser.add_argument("--platform", choices=["iOS", "macOS", "both"], default="both")
    parser.add_argument("--output", type=Path, help="A new output directory; existing artifacts are never replaced")
    parser.add_argument("--plan", action="store_true", help="Read-only validation and command plan; no archive/export")
    args = parser.parse_args()
    source = frozen_inputs(args.revision)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = (args.output or Path.home() / "Library/Application Support/CodexReleaseArtifacts/HowToAdult" / f"Revision-{source['revision'][:12]}-{stamp}").resolve()
    platforms = ["iOS", "macOS"] if args.platform == "both" else [args.platform]
    plans = {platform: commands(platform, output) for platform in platforms}
    report = {"source": source, "output": str(output), "mode": "local-app-store-export", "uploaded": False, "appStoreConnectRegistrationAttempted": False, "platforms": {}, "commands": []}
    if args.plan:
        print(json.dumps({**report, "plan": plans}, indent=2))
        return
    if output.is_relative_to(ROOT):
        raise RuntimeError("Keep release artifacts outside the source checkout.")
    output.mkdir(parents=True, exist_ok=False)
    report_file = output / "release-verification.json"
    try:
        for platform in platforms:
            if frozen_inputs(args.revision) != source:
                raise RuntimeError("Native inputs changed while release work was running.")
            folder = output / platform
            logs = folder / "Logs"
            logs.mkdir(parents=True)
            archive_command, export_command = plans[platform]
            run(archive_command, logs / "archive.log", report["commands"])
            archive_app = folder / f"{APP_NAME}.xcarchive/Products/Applications/{APP_NAME}.app"
            report["platforms"][platform] = {"archive": inspect_app(archive_app, platform, logs, report["commands"], distribution=False)}
            if frozen_inputs(args.revision) != source:
                raise RuntimeError("Native inputs changed after archiving.")
            run(export_command, logs / "export.log", report["commands"])
            report["platforms"][platform]["export"] = inspect_export(folder, platform, logs, report["commands"])
            report_file.write_text(json.dumps(report, indent=2) + "\n")
        if frozen_inputs(args.revision) != source:
            raise RuntimeError("Native inputs changed before verification completed.")
        report["completedAt"] = datetime.now(timezone.utc).isoformat()
    except Exception as error:
        report["error"] = str(error)
        raise
    finally:
        report_file.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Signed packages verified. No upload attempted. Record: {report_file}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, FileExistsError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
