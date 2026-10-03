#!/usr/bin/env python3
"""Generate the native project without external tools or modifying legacy files.

Run after adding a Swift source. Stable object IDs keep the resulting diff small.
Only Sources/, Tests/, UITests/, Content/catalog.json and named resources are compiled.
The original 2017 project and its storage model remain untouched.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "HowToAdult.xcodeproj"
objects = {}


def uid(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()


def obj(label, isa, **attributes):
    identifier = uid(label)
    objects[identifier] = {"isa": isa, **attributes}
    return identifier


def value(data, indent=0):
    tab = "\t" * indent
    if isinstance(data, dict):
        return "{\n" + "".join(f"{tab}\t{key} = {value(val, indent + 1)};\n" for key, val in data.items()) + tab + "}"
    if isinstance(data, list):
        return "(\n" + "".join(f"{tab}\t{value(val, indent + 1)},\n" for val in data) + tab + ")"
    if isinstance(data, int):
        return str(data)
    return json.dumps(str(data), ensure_ascii=False)


def file(label, path, kind, tree="<group>"):
    return obj(label, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree=tree)


def group(label, path, children):
    return obj(label, "PBXGroup", children=children, path=path, sourceTree="<group>")


source_names = sorted(path.name for path in (ROOT / "Sources").glob("*.swift"))
test_names = sorted(path.name for path in (ROOT / "Tests").glob("*.swift") if not path.name.endswith("UITests.swift"))
if "AdultCoreTests.swift" not in test_names:
    test_names.append("AdultCoreTests.swift")

sources = [file(f"source:{name}", name, "sourcecode.swift") for name in source_names]
tests = [file(f"test:{name}", name, "sourcecode.swift") for name in test_names]
ui_test_names = sorted(path.name for path in (ROOT / "UITests").glob("*.swift"))
if not ui_test_names:
    ui_test_names = ["AdultUITests.swift"]
ui_tests = [file(f"uiTest:{name}", name, "sourcecode.swift") for name in ui_test_names]
assets = file("assets", "Assets.xcassets", "folder.assetcatalog")
catalog = file("catalog", "catalog.json", "text.json")
manifest = file("manifest", "PrivacyInfo.xcprivacy", "text.xml")
config_files = [manifest] + [file(f"config:{name}", name, "text.plist.xml") for name in ["iOS-Info.plist", "macOS-Info.plist", "iOS.entitlements", "macOS.entitlements"]]
products = []
targets = []
schemes = []


def configuration_list(label, settings):
    configurations = []
    for name in ["Debug", "Release"]:
        flags = {**settings}
        flags["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if name == "Debug" else "-O"
        flags["DEBUG_INFORMATION_FORMAT"] = "dwarf" if name == "Debug" else "dwarf-with-dsym"
        if name == "Debug":
            flags["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG $(inherited)"
            flags["ENABLE_TESTABILITY"] = "YES"
        configurations.append(obj(f"config:{label}:{name}", "XCBuildConfiguration", buildSettings=flags, name=name))
    return obj(f"configs:{label}", "XCConfigurationList", buildConfigurations=configurations, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


shared = {
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "DEVELOPMENT_TEAM": "EJLR2RPSV2",
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "MARKETING_VERSION": "1.0",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
}

for platform in ["iOS", "macOS"]:
    target_name = f"HowToAdult-{platform}"
    product = obj(f"product:{platform}", "PBXFileReference", explicitFileType="wrapper.application", path="How to Adult.app", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    products.append(product)
    build_sources = [obj(f"build:{platform}:{ref}", "PBXBuildFile", fileRef=ref) for ref in sources]
    resources = [obj(f"resource:{platform}:{ref}", "PBXBuildFile", fileRef=ref) for ref in [assets, catalog, manifest]]
    phases = [obj(f"phase:{platform}:sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=build_sources, runOnlyForDeploymentPostprocessing=0), obj(f"phase:{platform}:frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0), obj(f"phase:{platform}:resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0)]
    settings = {**shared, "PRODUCT_BUNDLE_IDENTIFIER": "com.nathanfennel.How-To-Adult", "PRODUCT_NAME": "How to Adult", "PRODUCT_MODULE_NAME": "HowToAdult", "INFOPLIST_FILE": f"Configuration/{platform}-Info.plist", "CODE_SIGN_ENTITLEMENTS": f"Configuration/{platform}.entitlements", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor", "GENERATE_INFOPLIST_FILE": "NO", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks" if platform == "iOS" else "$(inherited) @executable_path/../Frameworks"}
    if platform == "iOS":
        settings.update(SDKROOT="iphoneos", IPHONEOS_DEPLOYMENT_TARGET="17.0", TARGETED_DEVICE_FAMILY="1,2", SUPPORTED_PLATFORMS="iphoneos iphonesimulator", SUPPORTS_MACCATALYST="NO", SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD="NO", SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD="NO")
    else:
        settings.update(SDKROOT="macosx", MACOSX_DEPLOYMENT_TARGET="14.0", SUPPORTED_PLATFORMS="macosx", ENABLE_APP_SANDBOX="YES", ENABLE_HARDENED_RUNTIME="YES", ARCHS="$(ARCHS_STANDARD)")
    target = obj(f"target:{platform}", "PBXNativeTarget", buildConfigurationList=configuration_list(target_name, settings), buildPhases=phases, buildRules=[], dependencies=[], name=target_name, productName="How to Adult", productReference=product, productType="com.apple.product-type.application")
    targets.append(target)

    test_name = f"HowToAdultTests-{platform}"
    test_product = obj(f"testProduct:{platform}", "PBXFileReference", explicitFileType="wrapper.cfbundle", path=f"{test_name}.xctest", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    products.append(test_product)
    test_sources = [obj(f"buildTest:{platform}:{ref}", "PBXBuildFile", fileRef=ref) for ref in tests]
    test_resources = [obj(f"testResource:{platform}:catalog", "PBXBuildFile", fileRef=catalog)]
    test_phases = [obj(f"testPhase:{platform}:sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=test_sources, runOnlyForDeploymentPostprocessing=0), obj(f"testPhase:{platform}:frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0), obj(f"testPhase:{platform}:resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=test_resources, runOnlyForDeploymentPostprocessing=0)]
    proxy = obj(f"testProxy:{platform}", "PBXContainerItemProxy", containerPortal=uid("project"), proxyType=1, remoteGlobalIDString=target, remoteInfo=target_name)
    dependency = obj(f"testDependency:{platform}", "PBXTargetDependency", target=target, targetProxy=proxy)
    test_settings = {key: val for key, val in settings.items() if key not in ["INFOPLIST_FILE", "CODE_SIGN_ENTITLEMENTS", "ASSETCATALOG_COMPILER_APPICON_NAME", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "ENABLE_APP_SANDBOX", "ENABLE_HARDENED_RUNTIME"]}
    test_settings.update(PRODUCT_NAME=test_name, PRODUCT_MODULE_NAME="HowToAdultTests", PRODUCT_BUNDLE_IDENTIFIER=f"com.nathanfennel.How-To-AdultTests.{platform.lower()}", GENERATE_INFOPLIST_FILE="YES", BUNDLE_LOADER="$(TEST_HOST)", TEST_HOST="$(BUILT_PRODUCTS_DIR)/How to Adult.app/How to Adult" if platform == "iOS" else "$(BUILT_PRODUCTS_DIR)/How to Adult.app/Contents/MacOS/How to Adult", TEST_TARGET_NAME=target_name)
    test_target = obj(f"testTarget:{platform}", "PBXNativeTarget", buildConfigurationList=configuration_list(test_name, test_settings), buildPhases=test_phases, buildRules=[], dependencies=[dependency], name=test_name, productName=test_name, productReference=test_product, productType="com.apple.product-type.bundle.unit-test")
    targets.append(test_target)
    ui_test_name = f"HowToAdultUITests-{platform}"
    ui_test_product = obj(f"uiTestProduct:{platform}", "PBXFileReference", explicitFileType="wrapper.cfbundle", path=f"{ui_test_name}.xctest", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    products.append(ui_test_product)
    ui_test_sources = [obj(f"buildUITest:{platform}:{ref}", "PBXBuildFile", fileRef=ref) for ref in ui_tests]
    ui_test_phases = [obj(f"uiTestPhase:{platform}:sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=ui_test_sources, runOnlyForDeploymentPostprocessing=0), obj(f"uiTestPhase:{platform}:frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)]
    ui_test_settings = {key: val for key, val in test_settings.items() if key not in ["BUNDLE_LOADER", "TEST_HOST"]}
    ui_test_settings.update(PRODUCT_NAME=ui_test_name, PRODUCT_MODULE_NAME="HowToAdultUITests", PRODUCT_BUNDLE_IDENTIFIER=f"com.nathanfennel.How-To-AdultUITests.{platform.lower()}")
    ui_test_target = obj(f"uiTestTarget:{platform}", "PBXNativeTarget", buildConfigurationList=configuration_list(ui_test_name, ui_test_settings), buildPhases=ui_test_phases, buildRules=[], dependencies=[dependency], name=ui_test_name, productName=ui_test_name, productReference=ui_test_product, productType="com.apple.product-type.bundle.ui-testing")
    targets.append(ui_test_target)
    schemes.append((target_name, target, test_name, test_target, ui_test_name, ui_test_target))

main_group = obj("mainGroup", "PBXGroup", children=[group("sourcesGroup", "Sources", sources), group("testsGroup", "Tests", tests), group("uiTestsGroup", "UITests", ui_tests), group("resourcesGroup", "Resources", [assets]), group("contentGroup", "Content", [catalog]), group("configGroup", "Configuration", config_files), obj("productsGroup", "PBXGroup", name="Products", children=products, sourceTree="<group>")], sourceTree="<group>")
project = obj("project", "PBXProject", attributes={"BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "2660", "TargetAttributes": {identifier: {"CreatedOnToolsVersion": "26.6", "DevelopmentTeam": "EJLR2RPSV2", "ProvisioningStyle": "Automatic"} for identifier in targets}}, buildConfigurationList=configuration_list("project", shared), compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=uid("productsGroup"), projectDirPath="", projectRoot="", targets=targets)
PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + value({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}) + "\n")
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)

def reference(identifier, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:HowToAdult.xcodeproj"/>'

for target_name, target, test_name, test_target, ui_test_name, ui_test_target in schemes:
    app_ref = reference(target, target_name, "How to Adult.app")
    test_ref = reference(test_target, test_name, f"{test_name}.xctest")
    ui_test_ref = reference(ui_test_target, ui_test_name, f"{ui_test_name}.xctest")
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{test_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{ui_test_ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference><TestableReference skipped="NO">{ui_test_ref}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_dir / f"{target_name}.xcscheme").write_text(scheme)
print(f"Generated {PROJECT.name}: {len(sources)} Swift sources, {len(tests)} unit-test sources, {len(ui_tests)} UI-test sources, iOS + macOS only.")
