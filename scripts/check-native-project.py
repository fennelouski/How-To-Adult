#!/usr/bin/env python3
"""Check registered native targets and the independently rendered vision icon."""
import json
import plistlib
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
project = json.loads(subprocess.check_output([
    "plutil", "-convert", "json", "-o", "-", str(root / "HowToAdult.xcodeproj/project.pbxproj")
]))
objects = project["objects"]
apps = {item["name"]: item for item in objects.values()
        if item.get("productType") == "com.apple.product-type.application"}
assert set(apps) == {"HowToAdult-iOS", "HowToAdult-macOS", "HowToAdult-visionOS"}
for name, app in apps.items():
    for identifier in objects[app["buildConfigurationList"]]["buildConfigurations"]:
        settings = objects[identifier]["buildSettings"]
        assert settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.nathanfennel.How-To-Adult"
        assert settings["SDKROOT"] == {"HowToAdult-iOS": "iphoneos", "HowToAdult-macOS": "macosx", "HowToAdult-visionOS": "xros"}[name]
        info = plistlib.loads((root / settings["INFOPLIST_FILE"]).read_bytes())
        assert info["AdultCatalogURL"].startswith("https://")
        if name.endswith("visionOS"):
            assert settings["TARGETED_DEVICE_FAMILY"] == "7"
            assert info["UIApplicationSceneManifest"]["UIApplicationSupportsMultipleScenes"]
            assert "UISupportedInterfaceOrientations" not in info
    assert (root / "HowToAdult.xcodeproj/xcshareddata/xcschemes" / (name + ".xcscheme")).is_file()
stack = root / "Resources/Assets.xcassets/VisionIcon.solidimagestack"
for layer, color_type in [("Front", 6), ("Back", 2)]:
    png = (stack / (layer + ".solidimagestacklayer") / "Content.imageset/Layer.png").read_bytes()
    assert png[:8] == b"\x89PNG\r\n\x1a\n" and png[25] == color_type
print("PASS: three native targets, vision scenes, catalog route and separate alpha/opaque icon layers")
