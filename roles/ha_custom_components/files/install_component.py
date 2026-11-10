"""Install one pinned custom integration release inside the Home Assistant container.

Run with: python3 -c "<this file>" <name> <version> <url> <sha256> [check]
Downloads the release zip, verifies its sha256, unpacks it to a staging
directory, then swaps it into /config/custom_components/<name>. The previous
version is kept as .<name>.previous until the role confirms HA restarted.
Prints one status line: unchanged | would-install | installed | error: ...
"""
import hashlib
import io
import os
import shutil
import sys
import urllib.request
import zipfile

BASE = "/config/custom_components"


def main(name, version, url, sha256, check=False):
    target = os.path.join(BASE, name)
    marker = os.path.join(target, ".installed_version")
    current = open(marker).read().strip() if os.path.exists(marker) else None
    if current == version:
        print(f"unchanged {name} {version}")
        return 0
    if check:
        print(f"would-install {name} {current or 'none'} -> {version}")
        return 0

    data = urllib.request.urlopen(url, timeout=60).read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != sha256:
        print(f"error: sha256 mismatch for {url}: got {digest}")
        return 1

    staging = os.path.join(BASE, f".{name}.new")
    previous = os.path.join(BASE, f".{name}.previous")
    shutil.rmtree(staging, ignore_errors=True)
    os.makedirs(staging)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for member in z.namelist():
            # Refuse paths that would escape the staging directory.
            dest = os.path.realpath(os.path.join(staging, member))
            if not dest.startswith(os.path.realpath(staging) + os.sep) and dest != os.path.realpath(staging):
                print(f"error: unsafe path in zip: {member}")
                return 1
        z.extractall(staging)
    # Release zips contain the integration files at the top level.
    if not os.path.exists(os.path.join(staging, "manifest.json")):
        print("error: no manifest.json at the top of the zip")
        return 1
    with open(os.path.join(staging, ".installed_version"), "w") as f:
        f.write(version + "\n")

    os.makedirs(BASE, exist_ok=True)
    shutil.rmtree(previous, ignore_errors=True)
    if os.path.exists(target):
        os.rename(target, previous)
    os.rename(staging, target)
    print(f"installed {name} {current or 'none'} -> {version}")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    sys.exit(main(*args[:4], check=len(args) > 4 and args[4] == "check"))
