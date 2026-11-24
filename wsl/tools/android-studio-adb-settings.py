#!/usr/bin/python
"""Set only Android Studio's ADB lifecycle preferences, with the IDE closed."""
import argparse
import json
import os
import re
import shutil
import stat
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

KEYS = {"AdbOptionsService.use.user.managed.adb": "true",
        "AdbOptionsService.user.managed.adb.port": "5037"}


def is_studio_process(args, comm, executable):
    return (comm in ("studio", "studio.sh", "android-studio") or
            executable == Path("/opt/android-studio/bin/studio") or
            (args and args[0] in (b"/usr/bin/android-studio", b"/usr/sbin/android-studio",
                                 b"/opt/android-studio/bin/studio")) or
            any(arg.startswith(b"-Didea.paths.selector=AndroidStudio") for arg in args))


def assert_closed():
    for process in Path("/proc").iterdir():
        if not process.name.isdigit():
            continue
        try:
            args = (process / "cmdline").read_bytes().split(b"\0")
            comm = (process / "comm").read_text().strip()
        except (OSError, PermissionError):
            continue
        try:
            executable = (process / "exe").resolve()
        except OSError:
            executable = None
        if is_studio_process(args, comm, executable):
            raise RuntimeError("Android Studio esta aberto; feche a IDE e reaplique o instalador. Nenhuma preferencia foi editada.")


def check_schema(root):
    with zipfile.ZipFile(root / "plugins/android/lib/android.jar") as jar:
        service = jar.read("com/android/tools/idea/adb/AdbOptionsService.class")
        if not all(key.encode() in service for key in KEYS):
            raise RuntimeError("Versao da IDE com preferencias ADB desconhecidas; configure pela interface.")
    with zipfile.ZipFile(root / "lib/intellij.platform.ide.impl.jar") as jar:
        service = jar.read("com/intellij/ide/util/AppPropertyService.class")
        if not all(key in service for key in (b"PropertyService", b"other.xml")):
            raise RuntimeError("Armazenamento de preferencias desconhecido; arquivo preservado.")


def properties(text):
    root = ET.fromstring(text or "<application />")
    components = root.findall("./component[@name='PropertyService']")
    if len(components) > 1 or root.tag != "application":
        raise ValueError("Formato de other.xml inesperado")
    if not components:
        return {"keyToString": {}, "keyToStringList": {}}
    data = json.loads(components[0].text or "{}")
    if not isinstance(data, dict) or not isinstance(data.get("keyToString", {}), dict):
        raise ValueError("PropertyService nao contem um mapa keyToString")
    data.setdefault("keyToString", {})
    return data


def render(text, values):
    data = properties(text)
    strings = data["keyToString"]
    for key in KEYS:
        if key in values:
            strings[key] = values[key]
        else:
            strings.pop(key, None)
    payload = json.dumps(data, ensure_ascii=False, indent=2).replace("]]>", "]]\\u003e")
    component = '<component name="PropertyService"><![CDATA[' + payload + ']]></component>'
    if re.search(r'<component\s+name="PropertyService"\s*>', text):
        result, count = re.subn(r'<component\s+name="PropertyService"\s*>.*?</component>',
                                lambda _: component, text, flags=re.S)
        if count != 1:
            raise ValueError("PropertyService duplicado")
    elif text:
        if "</application>" not in text:
            raise ValueError("Formato XML nao suportado; arquivo preservado")
        result = text.replace("</application>", "  " + component + "\n</application>")
    else:
        result = "<application>\n  " + component + "\n</application>\n"
    ET.fromstring(result)
    return result


def update(path, values):
    assert_closed()
    if path.is_symlink():
        raise RuntimeError("other.xml e um link simbolico; revise-o manualmente")
    before = path.read_text() if path.exists() else ""
    current = properties(before)["keyToString"]
    if all(current.get(key) == values.get(key) for key in KEYS):
        return False
    after = render(before, values)
    path.parent.mkdir(parents=True, exist_ok=True)
    backup = path.with_name(path.name + ".adb-bridge.bak")
    if not backup.exists():
        if path.exists():
            shutil.copy2(path, backup)
        else:
            backup.write_text("")
            backup.chmod(0o600)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".adb-settings-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(after)
        os.chmod(temporary, mode)
        assert_closed()
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-closed", action="store_true")
    parser.add_argument("--restore-from", type=Path, help="Restore only the two ADB keys from this backup")
    args = parser.parse_args()
    assert_closed()
    if args.check_closed:
        return
    root = Path("/opt/android-studio")
    check_schema(root)
    product = json.loads((root / "product-info.json").read_text())
    path = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "Google" / product["dataDirectoryName"] / "options/other.xml"
    values = properties(args.restore_from.read_text())["keyToString"] if args.restore_from else KEYS
    changed = update(path, values)
    print(f"ADB Studio: {'preferencias atualizadas' if changed else 'preferencias ja corretas'}: {path}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError, zipfile.BadZipFile) as exc:
        raise SystemExit(f"ADB Studio: {exc}")
