#!/usr/bin/env python3
"""Target-only pkg-config adapter; validates every emitted include/link path."""
import os
from pathlib import Path
import shlex
import subprocess
import sys
from native import architecture

try:
    root = Path(os.environ['WINDOWS_CROSS_SDK']).resolve(strict=True)
    environment = {key: value for key, value in os.environ.items() if not key.startswith('PKG_CONFIG')}
    environment['PKG_CONFIG_LIBDIR'] = f'{root}/lib/pkgconfig:{root}/share/pkgconfig'
    environment['PKG_CONFIG_PATH'] = ''
    environment['PKG_CONFIG_ALLOW_SYSTEM_CFLAGS'] = '1'
    environment['PKG_CONFIG_ALLOW_SYSTEM_LIBS'] = '1'
    output = subprocess.check_output(['pkgconf', *sys.argv[1:]], env=environment, text=True)
    library_dirs = [root / 'lib']
    libraries = []
    for flag in shlex.split(output):
        if flag.startswith(('-I', '-L')):
            path = Path(flag[2:]).resolve(strict=True)
            if not path.is_relative_to(root):
                raise ValueError(f'Caminho fora do SDK Windows: {flag}')
            if flag.startswith('-L'):
                library_dirs.append(path)
        elif flag.startswith('-l'):
            libraries.append(flag[2:])
        elif flag.startswith('-') and not flag.startswith('-D'):
            raise ValueError(f'Flag nao autorizada do SDK: {flag}')
        elif '/' in flag or '\\' in flag:
            path = Path(flag).resolve(strict=True)
            if not path.is_relative_to(root):
                raise ValueError(f'Caminho fora do SDK Windows: {flag}')
    for library in libraries:
        candidates = [directory / f'{library}.lib' for directory in library_dirs]
        path = next((candidate for candidate in candidates if candidate.is_file()), None)
        if path is None:
            raise ValueError(f'Import library Windows ausente: {library}.lib')
        architecture(path)
    print(output, end='')
except (KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
    print(f'windows-cross pkg-config: {error}', file=sys.stderr)
    sys.exit(1)
