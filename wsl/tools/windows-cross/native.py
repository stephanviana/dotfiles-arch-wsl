#!/usr/bin/env python3
"""Optional, verified Windows SDKs and packaging tools. No project dependencies."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ARTIFACTS = json.loads((HERE / 'artifacts.json').read_text())
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'dotfiles-windows-cross'
CACHE = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'dotfiles-windows-cross/downloads'
DESTINATIONS = {'sdk': DATA / 'sdks/gstreamer-1.26.11-msvc-x64',
                'runtime': DATA / 'runtimes/gstreamer-1.26.11-msvc-x64',
                'nsis': DATA / 'packaging/nsis-3.11'}


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verified(path, expected):
    if digest(path) != expected:
        raise ValueError(f'SHA-256 incorreto: {path}; arquivo preservado, nao sera utilizado.')


def download(name):
    artifact = ARTIFACTS[name]
    CACHE.mkdir(parents=True, exist_ok=True)
    destination = CACHE / artifact['url'].rsplit('/', 1)[1]
    if destination.exists():
        verified(destination, artifact['sha256'])
        return destination
    with tempfile.TemporaryDirectory(prefix='.download-', dir=CACHE) as temporary:
        partial = Path(temporary) / 'partial'
        subprocess.run(['curl', '-fL', '--proto', '=https', '--tlsv1.2', '--retry', '2',
                        artifact['url'], '-o', str(partial)], check=True)
        verified(partial, artifact['sha256'])
        # Publish only after validation, without overwriting a concurrent download.
        try:
            os.link(partial, destination)
        except FileExistsError:
            verified(destination, artifact['sha256'])
    return destination


def architecture(path, pe=False):
    result = subprocess.check_output(['llvm-readobj', '--file-headers', str(path)], text=True)
    machines = [line.strip() for line in result.splitlines() if 'Machine:' in line]
    if not machines or any('IMAGE_FILE_MACHINE_AMD64' not in line for line in machines) or 'ELF' in result:
        raise ValueError(f'Biblioteca/executavel nao e Windows AMD64: {path}')
    if pe and 'Format: COFF-x86-64' not in result:
        raise ValueError(f'Formato PE x64 esperado: {path}')


def validate(kind, root, inventory=True):
    if inventory:
        manifest = root / 'inventory.json'
        if not manifest.is_file():
            raise ValueError(f'Instalacao ausente/incompleta: {root}; execute {kind} prepare. '
                             'Se a pasta ja existir, escolha outro XDG_DATA_HOME para reparar sem apaga-la.')
        for name, checksum in json.loads(manifest.read_text()).items():
            verified(root / name, checksum)
    if kind == 'sdk':
        for name in ['include/gstreamer-1.0/gst/gst.h', 'include/gstreamer-1.0/ges/ges.h',
                     'lib/pkgconfig/gst-editing-services-1.0.pc', 'lib/pkgconfig/gstreamer-1.0.pc']:
            if not (root / name).is_file():
                raise ValueError(f'SDK incompleto: falta {root / name}')
        for name in ['gstreamer-1.0', 'ges-1.0', 'glib-2.0', 'gobject-2.0']:
            architecture(root / f'lib/{name}.lib')
        subprocess.run([str(HERE / 'pkg-config.py'), '--cflags', '--libs', 'gst-editing-services-1.0'],
                       env={**os.environ, 'WINDOWS_CROSS_SDK': str(root)},
                       stdout=subprocess.DEVNULL, check=True)
    elif kind == 'runtime':
        architecture(root / 'bin/gstreamer-1.0-0.dll', pe=True)
        for plugin in ['gstopengl.dll', 'gstsoundtouch.dll', 'gstwasapi2.dll', 'gstplayback.dll']:
            architecture(root / 'lib/gstreamer-1.0' / plugin, pe=True)
    else:
        for name in ['usr/share/nsis/Stubs/zlib-x86-unicode',
                     'usr/share/nsis/Plugins/x86-unicode/System.dll',
                     'usr/share/nsis/Plugins/x86-unicode/nsDialogs.dll',
                     'usr/share/nsis/Plugins/x86-unicode/NSISdl.dll',
                     'usr/share/nsis/Include/MUI2.nsh']:
            if not (root / name).is_file():
                raise ValueError(f'NSIS incompleto: {name}')
        subprocess.run([str(root / 'usr/bin/makensis'), '-VERSION'], check=True,
                       env={**os.environ, 'NSISDIR': str(root / 'usr/share/nsis')}, stdout=subprocess.DEVNULL)


def prepare(kind):
    destination = DESTINATIONS[kind]
    if destination.exists():
        validate(kind, destination)
        print(f'Existente e verificado: {destination}')
        return
    if kind != 'nsis' and not shutil.which('msiextract'):
        raise ValueError('msiextract ausente: instale com sudo pacman -Syu --needed msitools')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.prepare-', dir=destination.parent) as temporary:
        stage = Path(temporary)
        result = stage / 'result'
        result.mkdir()
        if kind == 'nsis':
            for artifact in ['nsis', 'nsis-common']:
                archive = download(artifact)
                unpack = stage / artifact
                unpack.mkdir()
                subprocess.run(['bsdtar', '-xf', str(archive), '-C', str(unpack)], check=True)
                payload = next(unpack.glob('data.tar.*'))
                subprocess.run(['bsdtar', '-xf', str(payload), '-C', str(result)], check=True)
        else:
            archive = download('gstreamer-' + kind)
            unpack = stage / 'extracted'
            unpack.mkdir()
            subprocess.run(['msiextract', '-C', str(unpack), str(archive)], check=True,
                           stdout=subprocess.DEVNULL)
            sentinel = 'gst.h' if kind == 'sdk' else 'gstreamer-1.0-0.dll'
            matches = list(unpack.rglob(sentinel))
            if len(matches) != 1:
                raise ValueError(f'Estrutura MSI inesperada: {len(matches)} arquivos {sentinel}')
            sdk = matches[0].parents[3] if kind == 'sdk' else matches[0].parents[1]
            for source in sdk.rglob('*'):
                if not source.is_file():
                    continue
                relative = source.relative_to(sdk)
                # Only compile assets; no static archives, debug symbols, tools or DLLs.
                selected = (relative.parts[0] == 'include' or source.suffix in ('.pc', '.lib') or
                            (relative.parts[0] == 'lib' and 'include' in relative.parts)) if kind == 'sdk' else (
                            relative.parts[0] in ('bin', 'libexec') or
                            relative.parts[:2] == ('lib', 'gstreamer-1.0') or
                            relative.parts[:2] == ('share', 'gstreamer-1.0'))
                license_file = any(part.lower() in ('licenses', 'license') for part in relative.parts) or source.name.lower().startswith(('copying', 'license'))
                if (selected and (kind == 'sdk' or source.suffix not in ('.a', '.lib', '.pdb'))) or license_file:
                    target = result / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
        validate(kind, result, inventory=False)
        inventory = {str(path.relative_to(result)): digest(path) for path in sorted(result.rglob('*')) if path.is_file()}
        (result / 'inventory.json').write_text(json.dumps(inventory, indent=2) + '\n')
        # Rename into an absent destination; incomplete existing caches are never deleted.
        result.rename(destination)
    print(destination)


def test_sdk(root):
    validate('sdk', root)
    with tempfile.TemporaryDirectory(prefix='windows-cross-native-') as temporary:
        stage = Path(temporary)
        (stage / 'src').mkdir()
        (stage / 'Cargo.toml').write_text('[package]\nname="windows-native-smoke"\nversion="0.1.0"\nedition="2021"\n')
        (stage / 'build.rs').write_text('fn main() { println!("cargo:rustc-link-search=native={}/lib", std::env::var("WINDOWS_CROSS_SDK").unwrap()); }')
        (stage / 'src/main.rs').write_text('''#[link(name = "gstreamer-1.0")]
extern "C" { fn gst_init(argc: *mut i32, argv: *mut *mut *mut i8); }
#[link(name = "ges-1.0")]
extern "C" { fn ges_init() -> i32; }
fn main() { unsafe { gst_init(std::ptr::null_mut(), std::ptr::null_mut()); ges_init(); } }
''')
        subprocess.run(['bash', str(HERE.parent / 'windows-cross.sh'), 'exec-sdk', str(root),
                        'cargo', 'xwin', 'build', '--target', 'x86_64-pc-windows-msvc'], check=True,
                       cwd=stage, env={**os.environ, 'CARGO_TARGET_DIR': str(stage / 'target')})
        executable = stage / 'target/x86_64-pc-windows-msvc/debug/windows-native-smoke.exe'
        architecture(executable, pe=True)
        subprocess.run(['file', str(executable)], check=True)


def test_nsis(root):
    validate('nsis', root)
    with tempfile.TemporaryDirectory(prefix='windows-cross-nsis-') as temporary:
        stage = Path(temporary)
        script = stage / 'test.nsi'
        script.write_text('''Unicode true
Name "Windows cross test"
OutFile "test.exe"
RequestExecutionLevel user
!include "MUI2.nsh"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
Section
System::Call 'kernel32::GetTickCount() i.r0'
nsDialogs::Create 1018
Pop $0
NSISdl::download "https://example.invalid/test" "$TEMP/test-unused"
SectionEnd
''')
        subprocess.run([str(root / 'usr/bin/makensis'), '-V2', str(script)], check=True,
                       cwd=stage, env={**os.environ, 'NSISDIR': str(root / 'usr/share/nsis')})
        subprocess.run(['file', str(stage / 'test.exe')], check=True)


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in DESTINATIONS or sys.argv[2] not in ('prepare', 'check', 'path', 'test'):
        raise ValueError('Uso: native.py {sdk|runtime|nsis} {prepare|check|path}')
    kind, action = sys.argv[1:]
    if action == 'test':
        if kind == 'nsis':
            test_nsis(DESTINATIONS[kind])
        elif kind == 'sdk':
            test_sdk(DESTINATIONS[kind])
        else:
            raise ValueError('Runtime requer validacao de execucao por aplicativo no Windows.')
    elif action == 'prepare':
        prepare(kind)
    else:
        destination = Path(os.environ.get('WINDOWS_CROSS_SDK', DESTINATIONS[kind])) if kind == 'sdk' else DESTINATIONS[kind]
        validate(kind, destination)
        print(destination)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, StopIteration) as error:
        print(f'windows-cross: {error}', file=sys.stderr)
        sys.exit(1)
