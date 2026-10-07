"""Export the signed Play AAB using catalog-resolved signing files; never publish."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2.stable"
SOURCE_SHA256 = "a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3"
FORBIDDEN = ("android/", "build/", "tests/", "tools/", "scripts/", "docs/", ".github/",
             "firebase/", "release/", "play-store/", "assets/art/raw/", "assets/art/concepts/",
             "assets/art/style/")


def invoke(command, environment, secret, timeout):
    result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                            text=True, timeout=timeout)
    output = result.stdout + result.stderr
    print(output.replace(secret, "[REDACTED]"), end="")
    if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
        raise SystemExit("Android export failed; inspect the output above")


def install_template(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise SystemExit("Android source template checksum does not match Godot 4.7.2")
    build = ROOT / "android/build"
    marker = ROOT / "android/.build_version"
    if build.exists():
        if not marker.is_file() or marker.read_text().strip() != VERSION:
            raise SystemExit("Existing Android template has a different or unknown version")
    else:
        build.mkdir(parents=True)
        with zipfile.ZipFile(archive) as template:
            template.extractall(build)
        marker.write_text(VERSION + "\n")
        (ROOT / "android/.gdignore").touch()
    if not (build / "libs/release/godot-lib.template_release.aar").is_file():
        raise SystemExit("Android release template is missing")
    (build / "gradlew").chmod(0o755)


def check_resources(output):
    with zipfile.ZipFile(output) as bundle:
        names = set(bundle.namelist())
    roots = ("base/assets/", "assetPackInstallTime/assets/")
    assets = {name[len(root):] for name in names for root in roots if name.startswith(root)}
    if any(name.startswith(FORBIDDEN) for name in assets):
        raise SystemExit("Development resources leaked into the AAB")
    required = {path.relative_to(ROOT).as_posix() for path in (ROOT / "data").rglob("*.json")}
    required.add("assets/fonts/OFL-1.1-DoHyeon.txt")
    if required - assets:
        raise SystemExit("AAB is missing runtime data or the font license")
    libraries = {name for name in names if name.startswith("base/lib/") and name.endswith(".so")}
    if not libraries or any(not name.startswith("base/lib/arm64-v8a/") for name in libraries):
        raise SystemExit("AAB native architectures do not match the ARM64 preset")


def check_manifest(bundletool, output):
    subprocess.run(["java", "-jar", str(bundletool), "validate", "--bundle=" + str(output)],
                   check=True, timeout=60)
    manifest = subprocess.check_output(["java", "-jar", str(bundletool), "dump", "manifest",
                                      "--bundle=" + str(output), "--module=base"], timeout=60)
    root = ET.fromstring(manifest)
    android = "{http://schemas.android.com/apk/res/android}"
    sdk, application = root.find("uses-sdk"), root.find("application")
    if (root.get("package") != "com.seoleeapps.sendlaneduel"
            or root.get(android + "versionCode") != "2"
            or root.get(android + "versionName") != "0.1.1"
            or sdk is None or sdk.get(android + "minSdkVersion") != "28"
            or sdk.get(android + "targetSdkVersion") != "36"
            or application is None or application.get(android + "appCategory") != "0"
            or application.get(android + "isGame") != "true"
            or application.get(android + "debuggable", "false") != "false"
            or root.findall("uses-permission")):
        raise SystemExit("AAB manifest does not match the offline game release preset")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--bundletool", type=Path, required=True)
    parser.add_argument("--upload-keystore", type=Path, required=True)
    parser.add_argument("--upload-env", type=Path, required=True)
    args = parser.parse_args()
    if not shutil.which(args.godot):
        parser.error("Godot executable is missing")
    version = subprocess.check_output([args.godot, "--version"], text=True, timeout=10).strip()
    if not version.startswith(VERSION + "."):
        parser.error("Use Godot " + VERSION)
    if not args.upload_keystore.is_file() or not args.upload_env.is_file():
        parser.error("Resolve app/send-lane-duel/google-play/upload-key before exporting")
    values = dict(line.split("=", 1) for line in args.upload_env.read_text().splitlines()
                  if "=" in line and not line.lstrip().startswith("#"))
    password = values.get("GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD", "")
    alias = values.get("GOOGLE_PLAY_UPLOAD_KEY_ALIAS", "")
    if not password or alias != "send-lane-duel-upload":
        parser.error("Upload signing companion file is incomplete")
    environment = os.environ.copy()
    environment.update({
        "GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(args.upload_keystore.resolve()),
        "GODOT_ANDROID_KEYSTORE_RELEASE_USER": alias,
        "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": password,
    })
    install_template(args.template)
    output = ROOT / "build/android/three-purses.aab"
    output.parent.mkdir(parents=True, exist_ok=True)
    invoke([args.godot, "--headless", "--editor", "--import", "--quit"], environment, password, 120)
    invoke([args.godot, "--headless", "--path", str(ROOT), "--export-release", "Android Release",
            str(output)], environment, password, 600)
    if not output.is_file() or not output.stat().st_size:
        raise SystemExit("Godot did not produce an AAB")
    check_resources(output)
    check_manifest(args.bundletool.resolve(), output)
    print("AAB:", output)
    print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
